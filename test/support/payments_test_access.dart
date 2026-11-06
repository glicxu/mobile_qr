import 'package:dali_qr/features/payments/application/payments_entitlement.dart';

/// Synthetic verified-ownership source for tests only. Never imported by main.
final class TestPaymentsAccess extends PaymentsEntitlement {
  TestPaymentsAccess([this.value = PaymentsAccessState.owned]);
  PaymentsAccessState value;
  int purchases = 0, restores = 0;
  void change(PaymentsAccessState next) {
    value = next;
    notifyListeners();
  }

  @override
  PaymentsAccessState get state => value;
  @override
  String? get localizedPrice => 'TEST PRICE';
  @override
  String get message =>
      isOwned ? 'Test Payments ownership' : 'Test locked Payments';
  @override
  bool get canPurchase => value == PaymentsAccessState.locked;
  @override
  bool get canRestore => value == PaymentsAccessState.locked;
  @override
  Future<void> purchase() async {
    purchases++;
  }

  @override
  Future<void> restore() async {
    restores++;
  }
}
