# Barcode creation

Date: 2026-10-29. Android-first implementation; iOS build/device validation
remains pending by user direction. No online information provider is needed.

## User flow

Create opens with QR Code selected. The Code format dropdown offers the same
13 formats as the scanner. Changing formats retains the editor content and
shows the selected format's input rules. Invalid content stays in the editor
with a specific error; additional-format values are never silently trimmed, uppercased, padded,
or assigned a replacement check digit.

QR keeps its existing generator, comparison codes, decorations and custom-image
entitlement behavior. Other formats use the already-pinned `zxing_lib` 1.1.4
writers on a worker isolate, with an opaque black/white PNG, integer module
scaling, quiet zones, and bearer bars for ITF-14. They do not get QR decorations
or comparison codes. Copy contents, Copy image, Share image and Save to Saved
are available. Share exports use distinct filenames to prevent later exports
from overwriting a file being handed to another app.

Automatic history follows the existing opt-in setting. Explicit Save works
with history off. Created barcodes retain their format, original value and
manual source in the existing schema; they do not store fabricated QR artwork.
View barcode in History/Saved recreates the original symbology for viewing or
export. Existing QR records keep their behavior. Passkey requests are excluded
from new barcode history/Saved callbacks.

## Input rules

| Format | Accepted input |
|---|---|
| QR Code | Existing QR payload policy and capacity/decorations rules |
| UPC-A | 12 ASCII digits, including a valid check digit |
| UPC-E | 8 ASCII digits; number system 0 or 1; canonical zero suppression; valid expanded UPC-A check digit |
| EAN-8 | 8 ASCII digits, including a valid check digit |
| EAN-13 | 13 ASCII digits, including a valid check digit |
| ITF-14 | 14 ASCII digits, including a valid GTIN check digit |
| Code 128 | Up to 80 ASCII characters |
| Code 39 / Code 93 | Up to 80 characters from uppercase A–Z, digits, space and `- . $ / + %` |
| Codabar | A–D start/end guards; digits and `- $ : / . +` inside; at most 80 characters |
| Data Matrix | Latin-1 text, at most 1,200 characters; actual symbol capacity still applies |
| PDF417 / Aztec | Text up to 1,200 UTF-8 bytes; actual symbol capacity still applies |

Numeric identifiers must already include their check digits. Generating a valid
symbol does not assign an official product identifier or establish product
existence. Product lookup remains disabled. This feature produces screen/export
images; it does not certify physical label printing dimensions.

Data Matrix intentionally uses its standard default Latin-1 encoding. During
qualification, Android ML Kit exposed the UTF-8 ECI assignment as an unwanted
U+001A prefix, while the independent decoder returned the intended text.
[Preliminary observations](evidence/barcode-generation-datamatrix-eci.json)
document that compatibility issue. Unsupported Data Matrix text receives an
explicit validation error directing the user to QR, PDF417 or Aztec. No native
scan values were normalized to conceal the issue.

## Verification

Final results: **267 host tests passed**, static analysis is clean, and debug
and release APK compilation passed. All **28 generated PNGs** passed independent
exact decoding and production on-device generate/scan checks on both SM-G975U
(Android 12/API 31) and SM-T290 (Android 11/API 30). The final debug APK is
installed on both devices with installed hashes verified against the artifact.
The tablet's actual Create UI shows QR selected and all 13 dropdown options;
system Back closes the dropdown while keeping the creation screen visible.
Release compilation was local only; nothing was published.

The host suite checks all existing QR behavior plus generation bounds, exact
content preservation, identifier validation, the default dropdown, format
switching, inline invalid-input errors, actual image/content clipboard calls,
Save with history off, and reopening a Saved barcode in its original format.
System Back closes the format dropdown and returns generated previews to the
creation form through the nested navigator, rather than leaving the app.

28 generated PNGs cover all 12 additional formats, multiple values, leading
zeros, whitespace, Latin-1 Data Matrix, and Unicode/emoji PDF417 and Aztec.
Independent ZXing-C++ decoding verifies their exact format and value.
Android integration generates the PNGs on-device and feeds them through the
production native-plus-fallback image analyzer. Every returned result must
match an allowed representation; a correct fallback cannot hide an incorrect
native result. The existing zero-leading EAN-13/UPC-A native alias is retained.

```text
flutter test
python tool/verify_generated_barcodes.py
flutter test integration_test/barcode_generation_test.dart -d <device-id> --no-uninstall
flutter analyze
flutter build apk --debug
```

The PNG inputs for the independent verifier are produced under
`.dart_tool/generated-barcode-qa` by the host generation tests. They are not
production assets. Native observations and current artifact/source hashes are
recorded in [generation evidence](evidence/barcode-generation-validation.json).
These checks do not establish iOS behavior, store release approval, or calibrated
physical printing/optical capture for every generated layout.
