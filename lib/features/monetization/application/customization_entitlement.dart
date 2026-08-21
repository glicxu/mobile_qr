import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class CustomizationEntitlement extends ChangeNotifier {
  bool get isUnlocked;
  bool get isStoreAvailable;
  bool get isBusy;
  String? get price;
  String? get message;

  Future<void> purchase();
  Future<void> restore();
}

abstract interface class DebugCustomizationEntitlement {
  Future<void> unlockForTesting();
}

final class StoreCustomizationEntitlement extends ChangeNotifier
    implements CustomizationEntitlement, DebugCustomizationEntitlement {
  StoreCustomizationEntitlement._(this._preferences, this._store);

  static const productId = 'dali_secure_qr_custom_lifetime';
  static const _unlockedPreference = 'customization_lifetime_unlocked';
  static const _testUnlockedPreference = 'customization_test_unlocked';

  final SharedPreferences _preferences;
  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _product;
  bool _isUnlocked = false;
  bool _isStoreAvailable = false;
  bool _isBusy = true;
  String? _message;

  static Future<StoreCustomizationEntitlement> open({
    InAppPurchase? store,
  }) async {
    final controller = StoreCustomizationEntitlement._(
      await SharedPreferences.getInstance(),
      store ?? InAppPurchase.instance,
    );
    await controller._initialize();
    return controller;
  }

  @override
  bool get isUnlocked => _isUnlocked;

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
        (kDebugMode &&
            (_preferences.getBool(_testUnlockedPreference) ?? false));
    _subscription = _store.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) {
        _isBusy = false;
        _message = 'The store could not complete that request.';
        notifyListeners();
      },
    );
    try {
      _isStoreAvailable = await _store.isAvailable();
      if (_isStoreAvailable) {
        final response = await _store.queryProductDetails({productId});
        if (response.productDetails.isNotEmpty) {
          _product = response.productDetails.first;
        } else {
          _message = 'The lifetime unlock is not available in this store.';
        }
        if (response.error != null) {
          _message = 'The store could not load the lifetime unlock.';
        }
      } else {
        _message = 'Purchases are not available on this device.';
      }
    } on Object {
      _isStoreAvailable = false;
      _message = 'Purchases are not available in this build.';
    } finally {
      _isBusy = false;
      notifyListeners();
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
    _isBusy = true;
    _message = null;
    notifyListeners();
    try {
      await _store.restorePurchases();
    } on Object {
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
    _message = 'Lifetime customization unlocked for testing.';
    notifyListeners();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    var unlocked = _isUnlocked;
    String? message;
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;
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
          message = 'Purchase canceled.';
        case PurchaseStatus.pending:
          message = 'Purchase pending.';
      }
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
    _isUnlocked = unlocked;
    _isBusy = false;
    _message =
        message ??
        (purchases.isEmpty ? 'No previous purchase was found.' : _message);
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
