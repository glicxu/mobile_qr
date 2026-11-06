# Optional 2D format evaluation (WP1)

Date: 2026-10-29. Historical native-only evaluation, followed by Android-first
implementation. Production now includes all three formats with a bounded local
still-image fallback; see [current scanner status](universal_scanner.md).

Six pinned bwip-js 4.11.4 PNG fixtures cover Data Matrix, PDF417 and Aztec with
short whitespace-bearing and longer ASCII values. Independent ZXing-C++ 2.3.0
decoding recovered all six exact values. Generator hashes and embedded test
data are reproducible. No images are added to production assets.

The native `mobile_scanner` 7.4.0 image-analysis probe explicitly selects each
candidate symbology and compares exact format/value. It intentionally bypasses
the production domain allowlist. Both available Android devices produced:

| Fixture | SM-G975U / Android 12 | SM-T290 / Android 11 |
|---|---|---|
| Data Matrix short | Exact match | Exact match |
| Data Matrix long | Exact match | Exact match |
| PDF417 short | Exact match | Exact match |
| PDF417 long | Exact match | Exact match |
| Aztec short | No result — failed | No result — failed |
| Aztec long | Exact match | Exact match |

Each qualification run therefore finished with **5 passing / 1 failing** tests.
The failed short Aztec fixture is retained. The independent decoder's success
rules out an unreadable fixture as the sole explanation; the precise native
decoder cause remains unproven. [Phone observations](evidence/android-phone-optional-formats.json)
and [tablet observations](evidence/android-tablet-optional-formats.json) include
individual elapsed times, exact results and fixture hashes. These are cold/warm
single-image observations, not performance benchmarks.

Original disposition (superseded): defer Aztec enablement because it fails this probe. Data Matrix
and PDF417 remain candidates, with no enablement decision until real demand,
iOS parity and the full camera/gallery/share matrix are available. Still-image
success alone does not qualify either format for release. No production model,
native iOS mapping, scanner selection priority or format allowlist was changed.

Reproduce using the existing development fixture-tool setup in
[the base fixture README](../../test/fixtures/barcodes/README.md):

```text
node tool/generate_optional_format_fixtures.cjs --check
python tool/verify_barcode_fixtures.py --optional
flutter test integration_test/optional_formats_test.dart -d <device-id>
```

The integration test now exercises the production native-plus-fallback pipeline,
not the original native-only probe. The short Aztec fixture and its exact value
are unchanged. The pinned local ZXing fallback recovers it; current runs and
remaining capture/platform gates are recorded in the universal scanner report.
The earlier native-only 5/6 observations remain useful evidence of why the
fallback is needed. They are not current production-pipeline failures.

Subsequent user-assisted live-camera capture on the SM-T290 also decoded
`aztec_short` correctly, with Camera source and its original whitespace-bearing
value observed. Live capture uses the native decoder; this does not change the
earlier static-PNG native-only failure. [Optical session evidence](evidence/universal-android-tablet-optical.json)
keeps those input paths distinct.
