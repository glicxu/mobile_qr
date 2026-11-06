import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const testFlightUnlockEnabled = bool.fromEnvironment(
  'ENABLE_TESTFLIGHT_UNLOCK',
);

abstract class CustomizationEntitlement extends ChangeNotifier {
  bool get isUnlocked;
  bool get isStoreAvailable;
  bool get isBusy;
  String? get price;
  String? get message;

  Future<void> refresh();
  Future<void> purchase();
  Future<void> restore();
}

abstract interface class DebugCustomizationEntitlement {
  Future<void> unlockForTesting();
}

abstract interface class HiddenCustomizationEntitlement {
  Future<void> unlockFromAbout();
}

abstract interface class TrialCustomizationEntitlement {
  bool get hasLifetimeAccess;
  bool get canStartTrial;
  Duration? get trialRemaining;
  Future<void> startTrial();
}

/// A locally persisted calendar-month trial, started only once per installation.
final class CustomizationTrial {
  CustomizationTrial._(this.end, this._now);

  static const preferenceKey = 'customization_trial_end_utc';
  final DateTime end;
  final DateTime Function() _now;

  static Future<CustomizationTrial> open(
    SharedPreferences preferences, {
    DateTime Function()? now,
  }) async {
    final clock = now ?? DateTime.now;
    final saved = preferences.getInt(preferenceKey);
    if (saved != null) {
      return CustomizationTrial._(
        DateTime.fromMillisecondsSinceEpoch(saved, isUtc: true),
        clock,
      );
    }
    final start = clock().toUtc();
    final firstOfNextMonth = DateTime.utc(start.year, start.month + 1);
    final lastDay = DateTime.utc(start.year, start.month + 2, 0).day;
    final end = DateTime.utc(
      firstOfNextMonth.year,
      firstOfNextMonth.month,
      start.day > lastDay ? lastDay : start.day,
      start.hour,
      start.minute,
      start.second,
      start.millisecond,
      start.microsecond,
    );
    if (!await preferences.setInt(preferenceKey, end.millisecondsSinceEpoch)) {
      throw StateError('Could not save the trial expiration.');
    }
    return CustomizationTrial._(end, clock);
  }

  Duration get remaining {
    final value = end.difference(_now().toUtc());
    return value.isNegative ? Duration.zero : value;
  }
}

String trialCountdown(Duration remaining) {
  final minutes = (remaining.inSeconds + 59) ~/ 60;
  final days = minutes ~/ (24 * 60);
  final hours = (minutes ~/ 60) % 24;
  final mins = minutes % 60;
  return '${days}d ${hours}h ${mins}m remaining';
}

final class StoreCustomizationEntitlement extends ChangeNotifier
    with WidgetsBindingObserver
    implements
        CustomizationEntitlement,
        TrialCustomizationEntitlement,
        DebugCustomizationEntitlement,
        HiddenCustomizationEntitlement {
  StoreCustomizationEntitlement._(this._preferences, this._store, this._now);

  static const productId = 'dali_secure_qr_lifetime';
  static const legacyAppleProductId = 'dali_secure_qr_custom_lifetime';
  static const googlePlayProductId = 'dali_qr_lifetime_unlock';
  static const productIds = {productId, googlePlayProductId};
  static const recognizedProductIds = {...productIds, legacyAppleProductId};
  static const _unlockedPreference = 'customization_lifetime_unlocked';
  static const _hiddenUnlockedPreference = 'customization_hidden_unlocked';
  static const _testUnlockedPreference = 'customization_test_unlocked';

  final SharedPreferences _preferences;
  final InAppPurchase _store;
  final DateTime Function()? _now;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  CustomizationTrial? _trial;
  Timer? _trialTimer;
  Timer? _trialExpiryTimer;
  ProductDetails? _product;
  bool _isUnlocked = false;
  bool _isStoreAvailable = false;
  bool _isBusy = true;
  String? _message;

  static Future<StoreCustomizationEntitlement> open({
    InAppPurchase? store,
    DateTime Function()? now,
  }) async {
    final controller = StoreCustomizationEntitlement._(
      await SharedPreferences.getInstance(),
      store ?? InAppPurchase.instance,
      now,
    );
    await controller._initialize();
    return controller;
  }

  @override
  bool get isUnlocked => _isUnlocked || (trialRemaining != null);

  @override
  bool get hasLifetimeAccess => _isUnlocked;

  @override
  bool get canStartTrial => !_isUnlocked && _trial == null;

  @override
  Duration? get trialRemaining {
    if (_isUnlocked) return null;
    final remaining = _trial?.remaining;
    return remaining == null || remaining == Duration.zero ? null : remaining;
  }

  @override
  bool get isStoreAvailable => _isStoreAvailable;

  @override
  bool get isBusy => _isBusy;

  @override
  String? get price => _product?.price;

  @override
  String? get message => _message;

  Future<void> _initialize() async {
    _isUnlocked =
        (_preferences.getBool(_unlockedPreference) ?? false) ||
        (testFlightUnlockEnabled &&
            (_preferences.getBool(_hiddenUnlockedPreference) ?? false)) ||
        (kDebugMode &&
            (_preferences.getBool(_testUnlockedPreference) ?? false));
    if (!_isUnlocked &&
        _preferences.containsKey(CustomizationTrial.preferenceKey)) {
      _trial = await CustomizationTrial.open(_preferences, now: _now);
      _scheduleTrialUpdates();
    }
    if (kDebugMode) {
      debugPrint('Customization unlock status: unlocked=$_isUnlocked');
    }
    _subscription = _store.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) {
        _isBusy = false;
        _message = 'The store could not complete that request.';
        notifyListeners();
      },
    );
    await _loadProductDetails(notify: false);
    _isBusy = false;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {
    if (_isBusy) return;
    _isBusy = true;
    _message = null;
    notifyListeners();
    await _loadProductDetails(notify: false);
    _isBusy = false;
    notifyListeners();
  }

  @override
  Future<void> startTrial() async {
    if (!canStartTrial) return;
    _trial = await CustomizationTrial.open(_preferences, now: _now);
    _scheduleTrialUpdates();
    notifyListeners();
  }

  void _scheduleTrialUpdates() {
    final remaining = trialRemaining;
    if (remaining == null) return;
    _trialTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      notifyListeners();
      if (trialRemaining == null) _trialTimer?.cancel();
    });
    _trialExpiryTimer = Timer(remaining, () {
      _trialTimer?.cancel();
      notifyListeners();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _loadProductDetails({required bool notify}) async {
    try {
      _isStoreAvailable = await _store.isAvailable();
      _product = null;
      if (!_isStoreAvailable) {
        _message = 'Purchases are not available on this device.';
        return;
      }
      final response = await _store.queryProductDetails(productIds);
      if (kDebugMode) {
        debugPrint(
          'StoreKit product query: found=${response.productDetails.map((product) => product.id).toList()} '
          'notFound=${response.notFoundIDs} error=${response.error}',
        );
      }
      if (response.productDetails.isNotEmpty) {
        _product = response.productDetails.first;
        _message = 'Lifetime unlock is available.';
      } else if (response.error != null) {
        _message = 'The store could not load the lifetime unlock.';
      } else {
        _message = 'The lifetime unlock is not available in this store.';
      }
    } on Object {
      _isStoreAvailable = false;
      _product = null;
      _message = 'Purchases are not available in this build.';
    } finally {
      if (notify) notifyListeners();
    }
  }

  @override
  Future<void> purchase() async {
    final product = _product;
    if (product == null || _isBusy) return;
    _isBusy = true;
    _message = null;
    notifyListeners();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _isBusy = false;
        _message = 'The purchase could not be started.';
        notifyListeners();
      }
    } on Object {
      _isBusy = false;
      _message = 'The purchase could not be started.';
      notifyListeners();
    }
  }

  @override
  Future<void> restore() async {
    if (!_isStoreAvailable || _isBusy) return;
    if (kDebugMode) {
      debugPrint('StoreKit restore requested');
    }
    _isBusy = true;
    _message = null;
    notifyListeners();
    try {
      await _store.restorePurchases();
      if (kDebugMode) {
        debugPrint('StoreKit restore request completed');
      }
    } on Object {
      if (kDebugMode) {
        debugPrint('StoreKit restore request failed');
      }
      _isBusy = false;
      _message = 'Previous purchases could not be restored.';
      notifyListeners();
    }
  }

  @override
  Future<void> unlockForTesting() async {
    if (!kDebugMode) {
      throw StateError('Test unlock is disabled in release builds.');
    }
    await _preferences.setBool(_testUnlockedPreference, true);
    _isUnlocked = true;
    _stopTrialTimers();
    _message = 'Lifetime customization unlocked for testing.';
    notifyListeners();
  }

  @override
  Future<void> unlockFromAbout() async {
    if (!testFlightUnlockEnabled) {
      throw StateError('The TestFlight unlock is disabled in this build.');
    }
    await _preferences.setBool(_hiddenUnlockedPreference, true);
    _isUnlocked = true;
    _stopTrialTimers();
    _message = 'Lifetime customization unlocked.';
    notifyListeners();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    if (kDebugMode) {
      debugPrint(
        'StoreKit purchase stream: ${purchases.map((purchase) => '${purchase.productID}:${purchase.status.name}').toList()}',
      );
    }
    var unlocked = _isUnlocked;
    String? message;
    for (final purchase in purchases) {
      if (!recognizedProductIds.contains(purchase.productID)) continue;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          unlocked = true;
          await _preferences.setBool(_unlockedPreference, true);
          message = purchase.status == PurchaseStatus.restored
              ? 'Lifetime customization restored.'
              : 'Lifetime customization unlocked.';
        case PurchaseStatus.error:
          message = 'The store could not complete the purchase.';
        case PurchaseStatus.canceled:
          message = null;
        case PurchaseStatus.pending:
          message = 'Purchase pending.';
      }
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
    _isUnlocked = unlocked;
    if (unlocked) _stopTrialTimers();
    _isBusy = false;
    _message =
        message ??
        (purchases.isEmpty ? 'No previous purchase was found.' : _message);
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTrialTimers();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _stopTrialTimers() {
    _trialTimer?.cancel();
    _trialExpiryTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _trial != null && !_isUnlocked) {
      notifyListeners();
    }
  }
}
