import 'package:flutter/foundation.dart';

enum PaymentsAccessState {
  unconfigured,
  locked,
  pending,
  owned,
  restoring,
  error,
}

/// Independent of Customization and its preferences, product IDs and overrides.
abstract class PaymentsEntitlement extends ChangeNotifier {
  PaymentsAccessState get state;
  String? get localizedPrice;
  String get message;
  bool get canPurchase;
  bool get canRestore;
  bool get isOwned => state == PaymentsAccessState.owned;
  Future<void> purchase();
  Future<void> restore();
}

final class UnconfiguredPaymentsEntitlement extends PaymentsEntitlement {
  @override
  PaymentsAccessState get state => PaymentsAccessState.unconfigured;
  @override
  String? get localizedPrice => null;
  @override
  String get message =>
      'Payments purchases are not configured yet. Explore the sample workspace; no purchase is available.';
  @override
  bool get canPurchase => false;
  @override
  bool get canRestore => false;
  @override
  Future<void> purchase() async =>
      throw StateError('Payments purchases are not configured.');
  @override
  Future<void> restore() async =>
      throw StateError('Payments restoration is not configured.');
}
