# Scanner fixtures

These synthetic PNGs cover the ten existing scanner formats. They are generated
independently of Dali's encoders and native decoders using pinned
[bwip-js](https://github.com/metafloor/bwip-js) 4.11.4. No user scan data is used.
`manifest.json` records exact inputs, generator options, hashes, and provisional
native representations. The fixed-length retail formats have two examples each;
QR and variable-length formats include content/length variations.

## Reproduce and verify

Run from the repository root with Node.js 18+ and Python 3.11:

```powershell
npm install --prefix .dart_tool/barcode-fixture-generator --no-package-lock --ignore-scripts bwip-js@4.11.4
node tool/generate_barcode_fixtures.cjs
node tool/generate_barcode_fixtures.cjs --check
python -m pip install --target .dart_tool/barcode-fixture-verifier zxing-cpp==2.3.0 Pillow==12.1.1
python tool/verify_barcode_fixtures.py
```

The generator writes the PNGs, manifest, and
`integration_test/barcode_fixture_data.g.dart`. The generated Dart file embeds
these same PNGs only into integration-test builds; release app assets are
unchanged. Commit all generated outputs together. `--check` verifies the PNGs,
manifest, and Dart file without rewriting them. The independent verifier checks
hashes and exact format/value using ZXing-C++, with Code 93 checksums enabled
in the generator. Independent verification does not establish native support.

## Native-device image decoding

```powershell
flutter test integration_test/scanner_fixture_test.dart -d <device-id> --reporter expanded
```

This runs 21 individual fixture cases plus generated blank-image and
multiple-symbol cases through `MobileScannerController.analyzeImage` and the
production adapter. It uses the app's current default native image-format
detection followed by the adapter's explicit allowlist. It does not start a
camera, interact with a photo picker, invoke a share sheet, record history, or
open any decoded content. Both Android and iOS plugin paths can be tested this
way; the separate native iOS Share Extension needs its own tests.

The expected representation alternatives are explicit:

- `upca_zero.png` encodes `012345678905`; `ean13_upca_pair.png` encodes
  `0012345678905`. The equivalent symbols may be reported as UPC-A or EAN-13.
  Accept only the corresponding exact format/value pair, preserving whatever
  the native decoder actually returned.
- Codabar expectations include start/stop guards. If a native platform differs,
  record the observed result and a decision before adjusting its expectation.
- QR and Code 128 whitespace cases retain leading/trailing spaces and the QR
  newline. Empty strings are filtered; nonempty whitespace remains data.
- Plain Code 39 examples avoid extended-ASCII escape pairs, keeping the intended
  decoded value unambiguous.

See the [device QA matrix](../../../docs/qa/scanner_matrix.md) for observed
results and the release checks still pending.
