# Universal scanner: Android implementation

Date: 2026-10-29. Working tree based on `0487c2a`, version
`1.2.0+2026102803`. Android first; the user explicitly deferred iOS validation.
This is implementation/QA evidence, not a signed store-release approval.

The subsequent [barcode creation report](barcode_generation.md) records the
new format dropdown and the latest full-suite/build evidence. Scanner reports
below retain their original tested APK snapshots.

## Supported scope

QR Code, UPC-A, UPC-E, EAN-8, EAN-13, Code 128, Code 39, Code 93,
Codabar, ITF-14, Data Matrix, PDF417, and Aztec have explicit native mappings,
stable storage keys, and result labels. Existing enum positions are preserved;
the three new formats are appended after the existing `unknown` value.
Generic Interleaved 2 of 5 is accepted as ITF-14 only with exactly 14 numeric
characters. This length filter does not establish checksum validity.

The supported subset is decoded text. Values are never trimmed or normalized.
Deduplication uses exact format/value pairs; native raw bytes remain in memory.
Binary-only native results produce a notice rather than fabricated text or a
history entry. Additional 2D formats receive neither QR comparison codes nor
fabricated QR artwork. Product-information lookup remains unavailable.

Live camera scanning uses `mobile_scanner` 7.4.0. Gallery and shared images
combine native image analysis with pinned `zxing_lib` 1.1.4 for
Data Matrix, PDF417, and Aztec. This local fallback fixes a small Aztec fixture
that the native decoder misses. It runs in a killable isolate with a six-second
deadline, a 25 MiB input limit, a 16-megapixel/16384-side metadata limit, and
a 1600-pixel working image. Native analysis has an eight-second wait limit;
the fallback pixel bound applies to the fallback, not the native decoder.
Centering the code helps difficult optical captures; Choose image scans an
existing image. Photo capture has been removed at the user's request.
No online service is used for decoding.

## Result and lifecycle behavior

- Copy retains the original text. Scanned results use automatic history when
  enabled; passkey requests are not recorded.
- Selecting the Scan tab again rearms the live camera. Incoming shared-image
  copies are cleaned after analysis; gallery originals are retained.
- A newer share supersedes an older pending analysis. Failed imports show a
  persistent error and allow retry; image-only startup does not require camera
  permission. Start camera is an explicit action in image-only mode.
- Android processes cold and warm image SEND intents through the native share
  bridge. Initial launch arguments suppress premature camera startup; Flutter
  URL routing is disabled because image URI data belongs to that bridge.
- The iOS Share Extension mappings and bounded thumbnail fallback are staged
  in source. They have not been compiled or validated on macOS/iPhone here.

## Evidence and limits

| Check | Result |
|---|---|
| Current host suite | 236 passed after removing photo capture; analysis clean |
| Independent fixture decoding | All 27 exact format/value checks passed; all fixture/chart regeneration checks passed |
| SM-G975U / Android 12 / API 31 baseline | 42 image-path/UI/persistence flows, 6 production 2D images, 26 real offline cold/warm SEND cases passed before photo-capture removal |
| SM-T290 / Android 11 / API 30 baseline | 42 image-path/UI/persistence flows, 6 production 2D images, 26 real offline cold/warm SEND cases passed before photo-capture removal |
| Android compilation | Current debug build passed; release compilation passed on the baseline before photo-capture removal |
| User-assisted live camera / SM-T290 | All 13 formats detected with the expected format, value, and Camera source; one fixture per format |
| iOS | Source staged; build/device validation pending by user direction |

The [validation summary and artifact/source hashes](evidence/universal-validation.json)
link this snapshot to the ordinary debug APK. Detailed observations are recorded
for the [phone flows](evidence/universal-android-phone-flows.json),
[tablet flows](evidence/universal-android-tablet-flows.json),
[phone 2D images](evidence/universal-android-phone-2d.json),
[tablet 2D images](evidence/universal-android-tablet-2d.json),
[phone native shares](evidence/universal-android-phone-shares.json), and
[tablet native shares](evidence/universal-android-tablet-shares.json).
Release compilation was local only and preceded photo-capture removal; no release
APK was installed or published. The current scanner keeps live scanning and
Choose image; it never launches a camera app to take a photo.

The [foundation matrix](scanner_matrix.md) retains the physical capture and
minimum-OS release gates. Automated path injection is not optical-camera or
real image-picker validation. See [2D evaluation history](optional_formats.md)
for the native-only failure that motivated the fallback.

Host coverage includes exact format/value/source persistence, Save with history
off, clipboard calls, passkey exclusion, stale shares, cancellation, failed
camera pause, binary-only notices, large fonts, and shared-image startup without
camera permission. Offline decoder tests include rotated JPEGs, mixed formats
with identical text, malformed inputs, input bounds, and timeouts.

Android integration tests use the production native-plus-fallback analyzer,
result UI, and SQLite repository. Their gallery/shared-image paths are injected;
OS clipboard and external launching are mocked. The historical 42-case reports
also include the camera-photo path, which has since been removed. Current
integration suites cover 26 gallery/share cases plus two supplemental EAN-13
cases per device. The supplemental
EAN-13 test uses a nonzero-leading book value because a zero-leading EAN-13
fixture is natively reported as UPC-A on these devices.

Real SEND testing uses a disposable `com.dalifin.qr.scannerqa` debug app,
temporary synthetic MediaStore images, and explicit URI read grants. It checks
cold/warm result text, Copy completion, Save completion, share-cache cleanup,
and absence of camera permission with no active default network. It does not
operate third-party Photos/Files/messaging chooser UI or read global clipboard
contents. The tool removes its images/app and restores prior connectivity.
Real-share elapsed times include UI automation, Copy, and Save; they are not
decoder latency measurements or a performance benchmark.

Current run results and source/artifact hashes are recorded under
[`evidence/`](evidence/). Historical reports retain their original tested scope.

## Reproduce

```text
flutter analyze
flutter test
flutter test integration_test/universal_scanner_flow_test.dart -d <device-id>
flutter test integration_test/ean13_scanner_flow_test.dart -d <device-id>
flutter test integration_test/optional_formats_test.dart -d <device-id>
node tool/generate_scanner_fixture_viewer.cjs --check
```

For isolated native SEND QA, build and copy the disposable artifact, then rebuild
the ordinary debug artifact so normal tooling continues to use `.test`:

```powershell
flutter build apk --debug --dart-define=DALI_SCANNER_QA_BUILD=true
Copy-Item build/app/outputs/flutter-apk/app-debug.apk build/app/outputs/flutter-apk/scanner-qa.apk
flutter build apk --debug
python tool/qa_android_shared_images.py --serial <device-id> --offline --output <report.json>
```

The tool refuses to overwrite an existing QA installation. Normal debug and
production app data are not cleared. Release package identity is unchanged.

## Remaining release validation

User-assisted tablet optical validation detected all 13 supported formats
through the rear camera, with the correct format, Camera source, and original
values observed in the result UI. This covers one fixture per format.
[Session evidence](evidence/universal-android-tablet-optical.json) records
incremental checks. These observations do not establish Copy/Save or complete
the format/source release cells. Broader capture coverage remains pending.

Use the offline [27-fixture camera chart](scanner_fixture_viewer.html) to check
live optical capture and the real image picker on physical Android devices.
Also check permission denial/recovery, third-party share choosers, and Android
API 24 (minimum) / API 36 (target) coverage. The tested devices are API 30/31.
These require manual/device coverage beyond the
automated evidence. iOS build, camera/gallery/share validation and minimum-OS
checks remain pending by user direction. Store signing/release checks remain
separate. No provider-backed product support is enabled.
