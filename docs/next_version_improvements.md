# Dali QR — Version 1.2 Improvements

**Status:** Core implementation complete; format/device QA pending
**Target release:** 1.2
**Audience:** Product, design, mobile engineering, QA, and security
**Target platforms:** iOS and Android
**Document date:** 2026-09-13

---

## 1. Summary

The next version should expand Dali QR from a QR-only scanner into a general
barcode reader while preserving its privacy-first and confirmation-first
behavior.

The release has three related goals:

1. Scan common one-dimensional barcodes with the camera or from an image.
2. Accept barcode and QR-code images shared from other applications, open a
   result screen inside Dali, and display the decoded contents without
   automatically opening or otherwise executing them.
3. Rename the user-facing application from **Dali Secure QR** to **Dali QR**.

All decoding remains on-device. A decoded value is untrusted data, regardless
of whether it came from the camera, photo picker, or another application.

## 2. Current behavior

The scanner currently configures `mobile_scanner` for `BarcodeFormat.qrCode`
only. The image-analysis path also discards every result whose format is not a
QR code.

Inbound image sharing already exists:

- Android registers Dali as an `image/*` share target.
- iOS provides a Share Extension for a single image.
- A received image is copied to private temporary storage, sent to the Scan
  screen, analyzed locally, and deleted after analysis.

The next version should retain this platform integration and broaden the
decoder and result model from QR-only to supported barcode formats. The
current app name is inconsistent across surfaces: some already say “Dali QR,”
while the Flutter application title and iOS metadata still say “Dali Secure
QR.”

## 3. Product rename

The product's user-facing name should be **Dali QR**. Remove “Secure” from the
application name because the app supports ordinary QR codes and barcodes in
addition to its optional verification feature.

Update every user-visible naming surface, including:

- the iOS home-screen display name and bundle display metadata;
- the Android application label;
- the Flutter application title and in-app About/settings fallback name;
- App Store and Google Play names and descriptions;
- permission-purpose descriptions, share-extension labels, screenshots, and
  review instructions;
- marketing copy, support content, and user-facing documentation; and
- accessibility labels or notifications that include the old product name.

The rename must not change the Android application ID, iOS bundle IDs, App
Group, database name, purchase product ID, signing configuration, or existing
installation identity. Existing users should receive a normal update rather
than a separate application.

“Secure QR” may remain as the name of Dali's verification feature where it
describes that feature specifically. It should not be used as the name of the
whole application. Existing code namespaces and internal filenames do not
need cosmetic renaming unless they appear to users.

## 4. Terminology and available barcode types

“Barcode” is an umbrella term. QR is one kind of two-dimensional barcode.
Other formats fall into two broad groups:

- **1D (linear) barcodes:** vertical bars carrying a relatively short value.
- **2D barcodes:** symbols carrying more data in two dimensions.

The current `mobile_scanner` dependency exposes these relevant families:

| Family | Formats | Typical use |
|---|---|---|
| Retail 1D | UPC-A, UPC-E, EAN-8, EAN-13 | Consumer product identifiers |
| General-purpose 1D | Code 128, Code 39, Code 93, Codabar | Shipping, inventory, assets, libraries, and healthcare |
| Packaging 1D | ITF / ITF-14 | Cartons and logistics |
| GS1 1D | DataBar, DataBar Expanded, DataBar Limited | Retail, coupons, produce, and healthcare |
| Matrix 2D | Data Matrix, Aztec, Micro QR | Components, tickets, labels, and compact marking |
| Stacked 2D | PDF417 | IDs, transport, and structured records |
| Other 2D | MaxiCode | Parcel sorting and logistics |

Not every format has identical support or recognition quality on every OS and
device. The product should advertise only formats that pass the cross-platform
test matrix; it should not enable `BarcodeFormat.all` without that validation.

## 5. Recommended scope

### 5.1 Required for this release

Continue supporting QR Code and add these common 1D formats:

- UPC-A and UPC-E
- EAN-8 and EAN-13
- Code 128
- Code 39
- Code 93
- Codabar
- ITF-14, using the non-deprecated format identifier supported by the scanner
  dependency

Support each required format through:

- live camera scanning;
- image selection from the photo library; and
- an image shared into Dali from another application.

### 5.2 Candidate follow-up formats

Evaluate GS1 DataBar, Data Matrix, PDF417, Aztec, Micro QR, and MaxiCode after
the required set is reliable. These formats are useful, but some need more
specialized fixtures, larger payload presentation, or stronger
platform-specific validation.

The release may include any candidate format that passes the same acceptance
criteria, but support must be explicit rather than implied by the underlying
library.

### 5.3 Out of scope

- Looking up a product, price, owner, shipment, or identity from a barcode
  number.
- Claiming that a checksum proves the contents are trustworthy.
- Automatically opening a URL, dialing a number, joining Wi-Fi, starting a
  payment, or invoking another application.
- Treating an unrecognized numeric value as a known product identifier.
- Generating 1D barcodes. This proposal changes scanning only.

## 6. Unified scan-result model

Replace QR-specific scan output with a format-aware result containing at least:

- decoded value;
- detected format;
- raw bytes when the scanner provides them;
- source: camera, photo library, or shared image;
- scan time for optional local history;
- classification, when Dali can classify the payload confidently; and
- verification state, which defaults to unverified unless an existing,
  format-appropriate Dali verification model applies.

The decoder must not discard a valid result solely because it is not QR. Empty
or unreadable results should still be rejected.

Retail codes require careful normalization. In particular, native scanners may
report an EAN-13 representation for a UPC-A value by prefixing a zero. Dali
should retain the scanner-reported format and raw value for diagnostics, then
apply one documented canonicalization policy consistently across iOS and
Android. Check digits should be validated where the symbology defines them,
but a valid check digit means only that the number was read consistently.

## 7. Result experience

Every successful scan or image import should open a result view inside Dali.
The view should show:

- a human-readable format label, such as **EAN-13** or **QR Code**;
- the complete decoded contents, with wrapping and scrolling for long values;
- a clear **Copy contents** action;
- source information when useful; and
- an **Open** or other contextual action only when Dali recognizes the content
  and the user explicitly chooses that action.

The primary behavior is to reveal the contents, not visit the destination. A
URL must be displayed before an external browser can be opened. The same rule
applies to phone numbers, email, messages, Wi-Fi configuration, app links, and
payment-like payloads.

For common retail barcodes, display the encoded identifier as data. Labels
such as “product,” product names, prices, or safety claims require a separate
lookup feature and data source and are not part of this release.

### 7.1 Multiple symbols in one image

If an image contains more than one supported symbol, do not silently choose an
arbitrary value. Show a list of detected results with format and a shortened
preview, then let the user select one to inspect. Duplicate detections of the
same format and value should be collapsed.

For the live camera, the first stable detection may continue to pause scanning
and open its result. A future multi-scan mode can support inventory workflows.

## 8. Share-into-Dali flow

The intended flow is:

1. In another application, the user shares one image to Dali.
2. Dali opens to the Scan area and shows a brief analyzing state.
3. Dali decodes all supported QR and barcode symbols locally.
4. One result opens directly, or multiple results open in a selection list.
5. Dali displays the selected symbol's format and contents.
6. Dali does not open, send, dial, connect, pay, or navigate automatically.
7. The temporary shared image is deleted after analysis, including failure and
   cancellation paths.

If no supported symbol can be read, show: “No readable QR code or supported
barcode was found in that image.” The message should offer a return to the
scanner rather than leaving an empty result screen.

The first release should continue accepting one image per share operation.
Multiple images, PDFs, live text, and screenshots supplied as non-image file
types can be considered separately.

## 9. Privacy and security requirements

- Decode on-device and do not upload the shared image or decoded contents.
- Treat every decoded value as untrusted input.
- Never execute decoded contents as a side effect of scanning or sharing.
- Require a separate, labeled user action before handing recognized content to
  the operating system.
- Render decoded text as inert text; do not interpret markup or executable
  content.
- Limit accepted input to one image of a reasonable size and handle malformed
  or inaccessible shares without crashing.
- Delete private temporary copies on success, no-result, error, and abandoned
  processing paths.
- Do not describe ordinary barcode checksums as identity, authenticity, or
  security verification.

## 10. Implementation outline

1. Rename QR-specific decoding helpers and state to format-neutral barcode
   equivalents.
2. Configure the controller with the explicit required format allowlist.
3. Make image analysis return all non-empty supported results rather than the
   first QR result.
4. Add a domain model for format, value, source, and optional raw bytes.
5. Update the result screen to show format and inert decoded contents first.
6. Route camera, photo-library, and shared-image detections through the same
   result pipeline.
7. Generalize history labels and storage from “QR” to “code” where necessary,
   while preserving existing records and database compatibility.
8. Keep the current Android and iOS inbound-share adapters, adding lifecycle
   and cleanup tests where coverage is missing.
9. Update user-facing scanner, permission, empty-state, and error copy to say
   “QR code or barcode” where appropriate.
10. Replace the old product name across user-facing surfaces without changing
    stable application, storage, signing, or purchase identifiers.

## 11. Test plan

Maintain real, independently generated fixtures for every supported format.
Test at least:

- camera recognition on representative iOS and Android devices;
- photo-library analysis and share-into-Dali analysis;
- portrait and landscape images;
- rotation, perspective, moderate blur, glare, low contrast, and small symbols;
- valid and invalid check digits where applicable;
- UPC-A/EAN-13 normalization behavior;
- long Code 128 values and non-URL text;
- multiple different symbols and duplicate symbols in one image;
- no symbol, unsupported symbol, corrupt image, oversized image, and revoked
  access;
- cold-start and warm-app shares on both platforms;
- temporary-file deletion after success, failure, and cancellation;
- confirmation that URL-like contents never launch automatically; and
- upgrade testing that confirms the renamed app retains existing history,
  saved codes, settings, and purchase entitlement.

## 12. Acceptance criteria

The improvement is complete when:

- every required 1D format is detected from camera, selected image, and shared
  image on supported iOS and Android versions;
- QR behavior remains compatible with the current release;
- the result view always identifies the format and displays the full decoded
  contents inside Dali;
- shared content never launches a destination automatically;
- multiple results are presented deterministically without silent loss;
- shared temporary files are cleaned up on all terminal paths;
- format and source are represented correctly in optional local history;
- accessibility labels and screen-reader order cover the format, contents, and
  user actions; and
- automated tests confirm non-QR formats are accepted instead of filtered out;
- all user-facing surfaces use **Dali QR** as the application name; and
- existing installations, local data, and purchase entitlement survive the
  renamed-app update.

## 13. Product decision

For the next version, “barcode support” means QR plus the explicit common 1D
allowlist in section 5.1. Other barcode formats do exist, especially 2D formats
such as Data Matrix, PDF417, and Aztec, but Dali should add them only after
cross-platform fixture testing demonstrates dependable behavior.

The governing interaction rule is:

> Scan or share, then show the contents in Dali. Never execute the contents
> automatically.
