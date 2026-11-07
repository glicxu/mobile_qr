import 'dart:async';

import 'package:dali_qr/features/monetization/application/customization_entitlement.dart';
import 'package:dali_qr/features/create/domain/structured_qr_payload.dart';
import 'package:dali_qr/features/create/presentation/generated_qr_page.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:dali_qr/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'trial lasts a calendar month and does not restart after expiry',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime.utc(2028, 1, 31, 10, 45);
      final trial = await CustomizationTrial.open(prefs, now: () => now);
      expect(trial.end, DateTime.utc(2028, 2, 29, 10, 45));
      expect(trial.remaining, const Duration(days: 29));
      now = DateTime.utc(2028, 2, 29, 10, 44);
      expect(trialCountdown(trial.remaining), '0d 0h 1m remaining');
      now = DateTime.utc(2028, 2, 29, 10, 45);
      expect(trial.remaining, Duration.zero);
      final reopened = await CustomizationTrial.open(prefs, now: () => now);
      expect(reopened.end, trial.end);
      expect(reopened.remaining, Duration.zero);
    },
  );

  testWidgets('trial starts only when a creation benefit is used', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = _UnavailableStore();
    final now = DateTime.utc(2028, 1, 15, 12);
    final access = await StoreCustomizationEntitlement.open(
      store: store,
      now: () => now,
    );
    expect(access.canStartTrial, isTrue);
    expect(access.isUnlocked, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(CustomizationTrial.preferenceKey), isFalse);
    await access.startTrial();
    expect(access.isUnlocked, isTrue);
    expect(access.canStartTrial, isFalse);
    expect(access.trialRemaining, const Duration(days: 31));
    expect(prefs.containsKey(CustomizationTrial.preferenceKey), isTrue);
    access.dispose();
    await store.events.close();
  });

  testWidgets('expiry removes trial access and notifies listeners', (
    tester,
  ) async {
    var now = DateTime.utc(2028, 2, 29, 10, 44);
    SharedPreferences.setMockInitialValues({
      CustomizationTrial.preferenceKey: now
          .add(const Duration(seconds: 30))
          .millisecondsSinceEpoch,
    });
    final store = _UnavailableStore();
    final access = await StoreCustomizationEntitlement.open(
      store: store,
      now: () => now,
    );
    var notifications = 0;
    access.addListener(() => notifications++);
    expect(access.isUnlocked, isTrue);
    expect(access.hasLifetimeAccess, isFalse);
    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    expect(access.isUnlocked, isFalse);
    expect(access.trialRemaining, isNull);
    expect(notifications, greaterThan(0));
    access.dispose();
    await store.events.close();
  });

  testWidgets('lifetime ownership remains active after trial expiry', (
    tester,
  ) async {
    var now = DateTime.utc(2028, 2, 29, 10, 44);
    SharedPreferences.setMockInitialValues({
      CustomizationTrial.preferenceKey: now
          .add(const Duration(seconds: 30))
          .millisecondsSinceEpoch,
    });
    final store = _UnavailableStore();
    final access = await StoreCustomizationEntitlement.open(
      store: store,
      now: () => now,
    );
    await access.unlockForTesting();
    now = now.add(const Duration(days: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(access.hasLifetimeAccess, isTrue);
    expect(access.isUnlocked, isTrue);
    expect(access.trialRemaining, isNull);
    access.dispose();
    await store.events.close();
  });

  testWidgets(
    'opening the app does not interrupt free scanning with a trial screen',
    (tester) async {
      final access = _TrialAccess();
      await tester.pumpWidget(
        DaliQrApp(
          secureQrService: SecureQrService(PublicSuffixList.parse('com')),
          customizationEntitlement: access,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your free trial'), findsNothing);
      expect(find.text('Scan QR code or barcode'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      access.dispose();
    },
  );

  testWidgets('free QR generation does not prompt; trial creation does', (
    tester,
  ) async {
    final access = _TrialAccess();
    await tester.pumpWidget(
      MaterialApp(
        home: QrGenerationSpikePage(
          secureQrService: SecureQrService(PublicSuffixList.parse('com')),
          customizationEntitlement: access,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate QR code'));
    await tester.pumpAndSettle();
    expect(find.byType(GeneratedQrPage), findsOneWidget);
    expect(find.text('Your free trial'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<QrCreationType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contact').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Generate QR code'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Generate QR code'));
    await tester.pumpAndSettle();
    expect(find.text('Your free trial'), findsOneWidget);
    expect(find.text('Free trial: 29d 23h 0m remaining'), findsOneWidget);
    await tester.tap(find.text('Continue trial'));
    await tester.pumpAndSettle();
    expect(find.text('Your free trial'), findsNothing);
    expect(find.byType(GeneratedQrPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    access.dispose();
  });

  testWidgets('settings distinguishes trial access from lifetime purchase', (
    tester,
  ) async {
    final access = _TrialAccess();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          customizationEntitlement: access,
          packageInfo: Future.value(
            PackageInfo(
              appName: 'Dali QR',
              packageName: 'com.dalifin.qr',
              version: '1',
              buildNumber: '1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trial'), findsOneWidget);
    expect(find.textContaining('29d 23h 0m remaining'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(r'Unlock for $3.99'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(r'Unlock for $3.99'));
    await tester.pumpAndSettle();
    expect(access.purchases, 1);
    expect(find.text('Lifetime customization unlocked'), findsOneWidget);
    expect(find.text('Trial'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    access.dispose();
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('check for updates opens the correct store on $platform', (
      tester,
    ) async {
      final previous = UrlLauncherPlatform.instance;
      final launcher = _StoreLauncher();
      UrlLauncherPlatform.instance = launcher;
      debugDefaultTargetPlatformOverride = platform;
      final access = _TrialAccess();
      addTearDown(() {
        UrlLauncherPlatform.instance = previous;
        debugDefaultTargetPlatformOverride = null;
        access.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            customizationEntitlement: access,
            packageInfo: Future.value(
              PackageInfo(
                appName: 'Dali QR',
                packageName: 'com.dalifin.qr',
                version: '1',
                buildNumber: '1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Check for updates'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(
        launcher.url,
        platform == TargetPlatform.iOS
            ? 'https://apps.apple.com/app/id6803730362'
            : 'https://play.google.com/store/apps/details?id=com.dalifin.qr',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    });
  }
}

final class _StoreLauncher extends UrlLauncherPlatform {
  String? url;
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    this.url = url;
    return true;
  }
}

final class _UnavailableStore implements InAppPurchase {
  final events = StreamController<List<PurchaseDetails>>.broadcast();
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => events.stream;
  @override
  Future<bool> isAvailable() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _TrialAccess extends CustomizationEntitlement
    implements TrialCustomizationEntitlement {
  bool owned = false;
  int purchases = 0;
  @override
  bool get hasLifetimeAccess => owned;
  @override
  bool get canStartTrial => false;
  @override
  Future<void> startTrial() async {}
  @override
  Duration? get trialRemaining =>
      owned ? null : const Duration(days: 29, hours: 23);
  @override
  bool get isUnlocked => owned || trialRemaining != null;
  @override
  bool get isStoreAvailable => true;
  @override
  bool get isBusy => false;
  @override
  String? get price => r'$3.99';
  @override
  String? get message => null;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> purchase() async {
    purchases++;
    owned = true;
    notifyListeners();
  }

  @override
  Future<void> restore() async {}
}
