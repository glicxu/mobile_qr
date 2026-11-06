import 'package:dali_qr/features/scan/domain/authenticator_payload.dart';
import 'package:dali_qr/features/scan/domain/qr_payload_classifier.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:dali_qr/features/scan/application/qr_payload_router.dart';
import 'package:dali_qr/features/scan/presentation/qr_scanner_page.dart';
import 'package:dali_qr/features/create/domain/qr_creation_payload_policy.dart';
import 'package:dali_qr/features/create/application/barcode_generator.dart';
import 'package:dali_qr/features/batch/domain/batch_session.dart';
import 'package:dali_qr/features/batch/application/batch_export.dart';
import 'package:dali_qr/features/history/application/history_controller.dart';
import 'package:dali_qr/features/history/data/drift_qr_history_repository.dart';
import 'package:dali_qr/features/history/data/history_database.dart';
import 'package:dali_qr/features/history/domain/qr_history.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const _secret =
    'JBSWY3DPEHPK3PXP'; // Public synthetic fixture; never a real account.
const _raw =
    'otpauth://totp/Dali%20QA:qa%2Btag%40example.com?secret=$_secret&issuer=Dali%20QA';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const classifier = QrPayloadClassifier();
  test('TOTP/HOTP defaults, labels and explicit supported options', () {
    final totp = AuthenticatorPayload.tryParse(_raw)!;
    expect(totp.account, 'qa+tag@example.com');
    expect(totp.issuer, 'Dali QA');
    expect(totp.secret, _secret);
    expect(totp.algorithm, 'SHA1');
    expect(totp.digits, 6);
    expect(totp.period, 30);
    final hotp = AuthenticatorPayload.tryParse(
      'otpauth://hotp/QA?secret=$_secret&counter=18446744073709551615&algorithm=SHA512&digits=8',
    )!;
    expect(hotp.counter, BigInt.parse('18446744073709551615'));
    expect(hotp.period, isNull);
    expect(classifier.classify(_raw).action, QrRouteAction.setupAuthenticator);
  });
  final invalid = [
    ' $_raw', 'otpauth-migration://offline?data=private-transfer',
    'otpauth://totp/QA?secret=$_secret&secret=$_secret',
    'otpauth://totp/Issuer:QA?secret=$_secret&issuer=Other',
    'otpauth://totp/QA?secret=BADSECRET!',
    'otpauth://totp/QA?secret=MZ', // Nonzero unused Base32 bits.
    'otpauth://totp/QA?secret=JBSWY3DPEHPK3PXP=',
    'otpauth://totp/QA?secret=$_secret&algorithm=MD5',
    'otpauth://totp/QA?secret=$_secret&digits=7',
    'otpauth://totp/QA?secret=$_secret&period=0',
    'otpauth://totp/QA?secret=$_secret&counter=1',
    'otpauth://hotp/QA?secret=$_secret',
    'otpauth://hotp/QA?secret=$_secret&counter=18446744073709551616',
    'otpauth://totp/QA?secret=$_secret&unsupported=true',
    'otpauth://totp/QA?secret=$_secret#fragment',
    'otpauth://totp/QA%0Asecret?secret=$_secret',
    'OTPAUTH :broken?secret=$_secret',
  ];
  test('malformed and transfer codes remain sensitive and non-actionable', () {
    for (final raw in invalid) {
      final p = classifier.classify(raw);
      expect(p.type, QrContentType.authenticator);
      expect(p.canRoute, isFalse);
      expect(p.isEphemeral, isTrue);
      expect(p.primaryText, isNot(contains(_secret)));
      expect(p.sensitiveValue, raw);
      expect(EphemeralCodePolicy.blocksPersistence(raw), isTrue);
    }
  });
  test(
    'creation, history, Saved and batch cannot persist setup secrets',
    () async {
      final history = HistoryController(
        DriftQrHistoryRepository(
          HistoryDatabase.forTesting(NativeDatabase.memory()),
        ),
        _Settings(),
      );
      await history.initialize();
      await history.enable();
      addTearDown(history.dispose);
      for (final raw in [_raw, ...invalid]) {
        await history.recordCreated(payload: raw);
        await history.recordScanned(payload: raw);
        await expectLater(
          history.savePayload(
            payload: raw,
            activityKind: QrActivityKind.scanned,
            source: QrActivitySource.camera,
          ),
          throwsStateError,
        );
        final code = ScannedCode(
          value: raw,
          format: ScannedCodeFormat.qrCode,
          source: ScanSource.gallery,
        );
        expect(() => BatchPolicy.validateCode(code), throwsArgumentError);
        expect(
          () => const QrCreationPayloadPolicy().validate(raw),
          throwsA(isA<QrCreationPayloadValidationException>()),
        );
        expect(
          () => BarcodeGenerator.validate(raw, ScannedCodeFormat.code128),
          throwsFormatException,
        );
      }
      expect(history.items, isEmpty);
      expect(history.savedItems, isEmpty);
      expect(
        () => BatchCsv.encode([
          BatchItem(
            id: 'legacy',
            sessionId: 'qa',
            value: _raw,
            format: ScannedCodeFormat.qrCode,
            sourceKey: 'gallery',
            quantity: 1,
            firstSeenUtc: DateTime.utc(2026),
            lastSeenUtc: DateTime.utc(2026),
          ),
        ]),
        throwsStateError,
      );
    },
  );
  test('no comparison code or automatic provider launch', () {
    final service = SecureQrService(PublicSuffixList.parse('com'));
    expect(service.calculateForPayload(_raw), isNull);
    for (final raw in invalid) {
      expect(service.calculateForPayload(raw), isNull);
    }
  });
  testWidgets('scan review masks secrets, excludes Save and confirms handoff', (
    tester,
  ) async {
    final previous = UrlLauncherPlatform.instance;
    final launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScannedCodeResultView(
            code: const ScannedCode(
              value: _raw,
              format: ScannedCodeFormat.qrCode,
              source: ScanSource.gallery,
            ),
            secureQrService: SecureQrService(PublicSuffixList.parse('com')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(launcher.launched, isEmpty);
    expect(find.textContaining(_secret), findsNothing);
    expect(find.text('Save to Saved'), findsNothing);
    await tester.tap(find.text('Open authenticator'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_secret), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(launcher.launched, isEmpty);
    await tester.tap(find.text('Open authenticator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(launcher.launched, [_raw]);
    expect(launcher.probed, ['otpauth://totp/DaliQR']);
    await tester.scrollUntilVisible(
      find.text('Details'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_secret), findsNothing);
    await tester.ensureVisible(find.byTooltip('Reveal Secret key'));
    await tester.tap(find.byTooltip('Reveal Secret key'));
    await tester.pumpAndSettle();
    expect(find.text('Secret key: $_secret'), findsOneWidget);
  });
  test(
    'missing authenticator stays local; forged route fields cannot change target',
    () async {
      final previous = UrlLauncherPlatform.instance;
      final launcher = _Launcher()..available = false;
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = previous);
      expect(
        await const QrPayloadRouter().route(classifier.classify(_raw)),
        isFalse,
      );
      expect(launcher.launched, isEmpty);
      for (final raw in invalid) {
        expect(
          await const QrPayloadRouter().route(classifier.classify(raw)),
          isFalse,
        );
      }
      final forged = ClassifiedQrPayload(
        rawPayload: _raw,
        type: QrContentType.authenticator,
        action: QrRouteAction.setupAuthenticator,
        title: 'Forged',
        primaryText: '',
        launchUri: Uri.parse('https://example.com/steal'),
      );
      expect(await const QrPayloadRouter().route(forged), isFalse);
      expect(launcher.launched, isEmpty);
    },
  );
}

final class _Settings implements HistorySettingsStore {
  @override
  Future<bool> historyEnabled() async => true;
  @override
  Future<void> setHistoryEnabled(bool enabled) async {}
}

final class _Launcher extends UrlLauncherPlatform {
  @override
  LinkDelegate? get linkDelegate => null;
  bool available = true;
  final launched = <String>[];
  final probed = <String>[];
  @override
  Future<bool> canLaunch(String url) async {
    probed.add(url);
    return available;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}
