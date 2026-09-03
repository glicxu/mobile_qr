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

  Future<void> refresh();
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
  static const googlePlayProductId = 'dali_qr_lifetime_unlock';
  static const productIds = {productId, googlePlayProductId};
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
    _message = 'Lifetime customization unlocked for testing.';
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
      if (!productIds.contains(purchase.productID)) continue;
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
