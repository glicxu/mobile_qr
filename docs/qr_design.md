# Dali QR

## Implementation-Oriented Product and Technical Design

**Status:** Proposed  
**Audience:** Product, design, mobile engineering, QA, and security  
**Target platforms:** iOS and Android  
**Recommended implementation:** Flutter application with small Swift and Kotlin adapters where platform-native behavior is required  
**Document date:** 2026-08-18

---

## 1. Executive summary

Dali QR is a standalone, privacy-first mobile utility that performs two jobs:

1. Turns text or a recognized standard payload supplied by the user into a standards-compliant QR code that can be displayed, saved, or shared.
2. Scans a QR code, classifies the decoded payload, presents it safely, and asks the operating system to open it in the most appropriate installed app.

The app should work without an account, backend, or network connection. QR generation and decoding happen entirely on the device. A network connection is needed only after the user elects to open an Internet URL or another destination whose target app requires connectivity.

Flutter is recommended because the product has a small, highly shared UI and domain model, while the required camera and operating-system integrations are already exposed through mature plugins. Flutter also permits focused Swift/Kotlin adapters through platform channels when iOS or Android policy cannot be expressed cleanly in Dart. Native SwiftUI and Jetpack Compose remain valid alternatives if the team already maintains two mobile codebases or requires platform-specific scanning experiences that diverge significantly.

Production QR correctness must come from battle-tested libraries, not an in-house implementation of Reed-Solomon error correction, block interleaving, mask scoring, or format/version information. Dali QR owns input validation, payload classification, rendering constraints, export quality, and cross-library conformance tests; it does not own the QR standard's low-level encoder or decoder.

---

## 2. Product definition

### 2.1 Product goals

- Generate a scannable QR code from a pasted or typed `http` or `https` hyperlink in two deliberate actions or fewer.
- Scan QR codes quickly in ordinary indoor lighting and route recognized content to an appropriate app only after user confirmation.
- Keep generation, decoding, classification, and optional history fully on-device.
- Make the app useful offline and usable without registration, analytics consent, or cloud storage.
- Produce exports that remain reliable when displayed on another phone, printed, or sent through a messaging app.
- Treat scanned QR content as untrusted input and make the destination visible before any external action.
- Provide accessible controls, clear permission recovery, and predictable behavior across iOS and Android.

### 2.2 Non-goals for the MVP

- Dynamic or redirectable QR codes hosted by Dali QR.
- Accounts, cross-device synchronization, team workspaces, or a web dashboard.
- URL shortening, link analytics, click tracking, or remote reputation scoring.
- Decorative QR styling, gradients, embedded logos, rounded modules, or animated codes.
- Bulk creation, inventory barcodes, payment authorization, identity verification, or digital signatures.
- Executing arbitrary commands or silently opening scanned content.
- A hand-written QR encoder or decoder in production.

### 2.3 Success criteria

- A valid supported hyperlink can be converted to a visible QR code in under 300 ms on supported mid-range devices, excluding cold app start.
- A well-formed QR occupying at least roughly 20% of the camera frame is typically recognized in under one second in normal lighting.
- Generated codes pass round-trip tests on both Dali QR and at least two independent decoders.
- No QR payload, clipboard value, image, or scan event leaves the device in the default configuration.
- The app never opens a scanned destination without an explicit user action.
- Denied camera permission, malformed payloads, unsupported schemes, and missing target apps all have recoverable UX.

---

## 3. User experience

### 3.1 Information architecture

Use three bottom-level destinations:

- **Create:** enter or paste QR content, generate a code, and export it.
- **Scan:** use the camera or import an image containing a QR code.
- **History:** optional local records of generated and scanned items.

Settings can be reached from the top app bar. Keep Create as the default launch destination because it does not require a permission prompt.

### 3.2 Create flow

1. The Create screen shows a labeled content field, a system-supported paste affordance, and a disabled **Create QR code** button.
2. The user pastes or types text.
3. Dali QR preserves general payload text exactly and validates its UTF-8 byte length. A valid HTTP/HTTPS URL may trim outer whitespace under the URL policy.
4. Any non-empty payload within the product byte limit can be encoded. Only absolute HTTP/HTTPS URLs with a valid registrable domain receive the domain-based verification code; all other payloads remain unverified unless a separate verification scheme is defined.
5. The user taps **Create QR code**.
6. The app encodes the exact accepted payload, displays the QR code with its full-value preview and any applicable verification code, and optionally writes a local history record.
7. The user can copy the QR image or payload and edit the content.

Important UX rule: show the exact encoded value in a selectable detail view. The QR image must never be the only representation of the data.

### 3.3 Scan flow

1. The user opens Scan.
2. If camera permission has not been decided, show a short pre-permission explanation and request access only after **Continue**.
3. The live scanner starts with rear camera, QR-only detection, a centered guide, torch control, and an **Import image** alternative.
4. When a code is decoded, pause frame analysis immediately and deduplicate repeated callbacks.
5. Show a result sheet containing:
   - classified content type;
   - decoded text, with the scheme and host visually prominent for URLs;
   - the proposed action and target category;
   - **Open**, **Copy**, **Share**, and **Cancel/Scan again** actions.
6. Only an explicit **Open** tap invokes the operating system.
7. On success, optionally persist a history entry. On failure, keep the content visible and offer Copy/Share.

Do not automatically follow redirects, fetch page metadata, resolve a hostname, or render a remote preview before confirmation. Those behaviors leak the scanned destination and can trigger tracking or malicious endpoints.

### 3.4 Import-from-image flow

- Open the system photo picker rather than requesting broad photo-library access when platform support permits.
- Decode locally.
- If multiple QR codes are found, show each candidate with a crop thumbnail or numbered overlay and require selection.
- If none is found, explain likely causes and offer a camera scan; do not upload the image.

### 3.5 Result and routing behavior

The result screen is a trust boundary. It must display the decoded content before launching it, including Unicode hostnames in both user-friendly and ASCII/Punycode form when they differ. Long values should wrap and be selectable. For dangerous or unsupported types, the primary action becomes **Copy** rather than **Open**.

### 3.6 History flow

- History is local and off by default. On first use of history, explain what will be stored and let the user enable it.
- Group records by date and mark them as **Created** or **Scanned**.
- Search locally by host or text.
- Swipe/delete individual records and provide **Clear all history** with confirmation.
- Free users can access one week of history. Older entries remain stored locally
  and become accessible after the lifetime customization unlock.
- Saved QRs remain accessible regardless of age until the user deletes them.
- Do not save imported source photos or camera frames.

---

## 4. Platform and framework decision

### 4.1 Recommendation: Flutter with native escape hatches

Use Flutter for presentation, state management, URL validation, QR generation, result classification, local storage, and most platform integrations. Keep Swift/Kotlin modules small and narrowly defined for behaviors such as a native iOS paste control or policy-sensitive URI dispatch.

Why Flutter fits Dali QR:

- Approximately 85-90% of the product behavior is identical across platforms.
- The UI is compact and custom rather than dependent on a large catalog of platform-specific screens.
- QR rendering is naturally handled by Flutter's vector-style canvas pipeline.
- The recommended scanner plugin delegates to the native scanning stacks rather than implementing vision processing in Dart.
- Flutter supports asynchronous platform channels and generated, type-safe bindings when a native adapter is needed.
- A single shared conformance suite can verify generation, parsing, routing decisions, and persistence.

### 4.2 Native comparison

| Criterion | Flutter | SwiftUI + Kotlin/Compose |
|---|---|---|
| Shared product logic | One Dart implementation | Must be duplicated or moved into a shared multiplatform module |
| Camera/decoder | Plugin backed by CameraX/ML Kit and AVFoundation/Vision | Direct platform APIs; maximum control |
| Clipboard policy | Plugin or small native adapter | Direct access to `UIPasteControl` and Android clipboard APIs |
| OS routing | Shared wrapper plus platform behavior | Direct `UIApplication.open` and Android intents |
| UI consistency | High by default | Requires coordination across two implementations |
| Platform-native nuance | Good, with adapters | Best |
| Team and release cost | Lower for a small team | Higher unless both platform teams already exist |
| Long-term dependency risk | Requires plugin maintenance review | More code owned by the team, fewer cross-platform plugins |

Choose separate native apps instead if the organization already has dedicated iOS and Android teams, mandates zero third-party runtime plugins, needs deeply different platform UX, or plans to make scanning a platform extension with native-only constraints. Otherwise, native development adds material duplication without a corresponding product advantage for this scope.

### 4.3 Supported platform baseline

Select final deployment targets during project bootstrap based on the current Flutter and plugin requirements. The spike baseline is iOS 15+ and Android API 24+, matching Flutter 3.44's supported Android range, subject to release-time verification. Do not let this document's package versions substitute for a locked build: use a dependency lockfile, automated update checks, and a quarterly plugin health review.

---

## 5. Technical stack

### 5.1 Recommended components

| Concern | Recommendation | Notes |
|---|---|---|
| App framework | Flutter stable / Dart stable | Pin via CI toolchain configuration |
| Architecture | Feature-first clean layers | Presentation, application, domain, data, platform |
| State management | Riverpod | Testable dependency injection; avoid global mutable singletons |
| Navigation | `go_router` | Typed route wrappers; simple three-tab shell |
| QR generation | `qr` 4.x for the encoded matrix; Dali-owned matrix painters for screen and export | Use explicit UTF-8 ECI; do not depend on `qr_flutter` 4.1.0 because it constrains `qr` to 3.x |
| QR camera decoding | `mobile_scanner` | QR-only configuration; native backends on iOS/Android |
| External routing | `url_launcher`, wrapped by a Dali-owned policy service | Never call it directly from widgets |
| Sharing | `share_plus` | Native share sheet for image/text |
| Local database | Drift over SQLite | Typed schema, migrations, reactive history queries |
| Settings | `shared_preferences` for non-sensitive preferences | Do not store payload history here |
| IDs | UUID v4 | Local identifiers only |
| Image/file paths | `path_provider` and temporary/app-document directories | Clean temporary exports |
| Image import | System photo picker via an actively maintained Flutter plugin | Prefer limited/system picker access |
| Logging | `dart:developer` or structured local logger with redaction | Never log raw payloads in release builds |
| Testing | `flutter_test`, integration tests, Mockito/fakes only where useful | Add independent decode fixtures |
| CI | GitHub Actions or equivalent plus macOS signing runner | Analyze, test, build, dependency/license scan |

Package versions should be selected and locked when implementation begins. The generation spike pins `qr` 4.0.0 and `image` 4.9.1. As of this document's date, the package pages identify `mobile_scanner` 7.4.0, `url_launcher` 6.3.2, `share_plus` 13.3.0, and Drift 2.34.3. Treat these as a dated reference, not a command to accept future major upgrades without review.

### 5.2 Suggested source layout

```text
lib/
  app/
    dali_qr_app.dart
    router.dart
    theme.dart
  core/
    errors/
    logging/
    security/
  features/
    create/
      application/
      domain/
      presentation/
    scan/
      application/
      domain/
      presentation/
    routing/
      application/
      domain/
      platform/
    history/
      application/
      data/
      domain/
      presentation/
    settings/
  infrastructure/
    database/
    export/
    clipboard/
    scanner/
ios/Runner/PlatformAdapters/
android/app/src/main/kotlin/.../platformadapters/
test/
integration_test/
```

### 5.3 Layer responsibilities

- **Presentation:** widgets, accessibility semantics, screen state rendering, and user events.
- **Application:** use cases such as `GenerateQr`, `ProcessScan`, `OpenPayload`, `ShareQr`, and `DeleteHistory`.
- **Domain:** immutable payload types, validation rules, classifications, routing decisions, and repository interfaces.
- **Data:** Drift tables/DAOs, preference implementations, migrations, and export files.
- **Platform:** scanner, clipboard, photo picker, share sheet, OS URI launcher, permissions, and Settings navigation.

Widgets must not parse URLs, access the database, or launch external applications directly.

---

## 6. QR generation design

### 6.1 Generation pipeline

```text
User text
  -> trim outer whitespace
  -> reject controls / enforce length ceiling
  -> parse and validate absolute HTTPS/HTTP URI
  -> optional explicit HTTPS repair offered to user
  -> serialize canonical payload string
  -> QR library chooses version and constructs codewords/ECC/mask
  -> obtain immutable module matrix
  -> render with 4-module quiet zone and integer module scale
  -> display / PNG export / SVG export
  -> independent decode verification in tests
```

### 6.2 Input policy

- Accept absolute `https` and `http` URLs for creation in MVP.
- Prefer HTTPS but do not rewrite a valid HTTP URL silently.
- Require a non-empty host.
- Preserve path, query, fragment, percent escapes, case-sensitive components, and meaningful trailing slash semantics.
- Remove only leading and trailing Unicode whitespace after telling the user if the value changed materially.
- Reject NUL and other control characters.
- Reject user-info credentials (`https://user:pass@example.com`) by default because they are easy to misread and may leak secrets.
- Apply a configurable UTF-8 byte ceiling below the QR library's maximum and return a useful **Link is too long** error. Start with 2,000 UTF-8 bytes for product predictability, then adjust from device and export tests.
- Never shorten a URL through a remote service without a separate, explicit feature and privacy review.

### 6.3 Encoding parameters

- Encode the final string as UTF-8 byte-mode data with ECI assignment 26 so decoders do not need to guess the character set.
- Let the library select the smallest QR version that fits the payload and selected error-correction level.
- Default to error correction **M**. It balances density and resilience for clean black-and-white URLs.
- Offer **Q** as a future advanced export option for harsher print/display conditions. Do not expose L/M/Q/H in the MVP UI.
- Let the library evaluate and choose the mask pattern. Do not force a mask in production.
- Render dark modules as near-black and background as white, meeting at least 4.5:1 contrast; pure black/white is the default.
- Enforce the QR-required four-module quiet zone on every side.
- Use square modules, no rounding, no logo, and no decorative finder-pattern changes in MVP.

### 6.4 What the library does

The selected QR encoder is responsible for:

1. Selecting numeric/alphanumeric/byte segments as supported.
2. Writing mode and character-count indicators.
3. Adding terminator and pad bits/codewords.
4. Splitting data into the version/error-level block structure.
5. Generating Reed-Solomon error-correction codewords in GF(256).
6. Interleaving data and error-correction blocks.
7. Placing finder, timing, alignment, dark-module, format, and version patterns.
8. Placing the data bitstream in the matrix.
9. Applying candidate masks and calculating standard penalty scores.
10. Selecting a valid mask and writing format/version information.

Dali QR should treat the output module matrix as the boundary. It may render that matrix, but it must not replace these steps with application-owned code.

### 6.5 Rendering and export

**On-screen:** use a Dali painter over the `qr` matrix. Render at an integer logical module scale where possible and avoid interpolation. The same immutable matrix is the source for screen and export rendering.

**PNG:** render directly from the matrix at a target of 1024 x 1024 pixels, choosing a module size that is an integer number of pixels and centering the result within the canvas. Set image filtering to nearest-neighbor/no smoothing. Include quiet zone in the exported bitmap.

**SVG:** build simple `<rect>` or merged path geometry from the library-produced Boolean module matrix. This is custom rendering, not custom encoding. Include a white background, `viewBox`, crisp edges, and the quiet zone. Sanitize metadata and do not embed the source URL as executable markup.

**Share:** write exports to a random file in the cache directory, invoke the system share sheet, and delete expired cache files on next launch. Share the PNG by default because it is broadly compatible. Offer SVG under an advanced action later.

**Save:** use the platform's document/photo save flow. Do not request broad storage permission merely to save one file.

### 6.6 Why production must use libraries

A hand-written implementation is valuable as an educational exercise but is an avoidable production risk. QR correctness depends on numerous version- and error-level-specific tables, finite-field arithmetic, block grouping, interleaving order, reserved-module placement, mask predicates, penalty scoring, and BCH-encoded format/version fields. Common implementations appear correct for short ASCII strings but fail at version transitions, multi-block payloads, non-ASCII data, or certain masks.

Battle-tested libraries provide:

- broad input and version coverage accumulated over many users;
- conformance fixes for uncommon edge cases;
- stable interoperability with platform scanners;
- security and maintenance review concentrated in a smaller dependency surface;
- less custom code for the Dali team to audit and support.

The team still owns dependency review. Pin versions, record licenses, review changelogs, run software-composition analysis, and maintain conformance fixtures. If the chosen library becomes unmaintained, replace it behind the `QrEncoder` interface rather than editing the application's feature code.

### 6.7 Generation spike evidence

The initial Flutter spike validates the URL without reserializing it, encodes through `qr` 4.0.0 with an explicit UTF-8 ECI segment, obtains an immutable module matrix, and renders both a Flutter canvas view and a deterministic 1024 x 1024 PNG with integer pixel modules and a four-module quiet zone.

The checked-in automated corpus covers HTTP/HTTPS URLs, ports, repeated query parameters, fragments, percent-escape spelling, Unicode host/path/query content, outer-whitespace trimming, invalid inputs, QR version growth, and the 2,000-byte product ceiling. Generated PNGs are independently located and decoded by the Dart ZXing port. That port has a signed-byte defect in its UTF-8 text conversion, so its Unicode test verifies the independently recovered byte segment after converting signed bytes back to unsigned values. A separate reproducible check using official ZXing Java 3.5.3 decodes both ASCII and Unicode PNG fixtures to the exact source strings.

On the development workstation, generation plus 1024 x 1024 PNG rendering measured 58.1 ms p95 for a short URL, 62.2 ms p95 for the Unicode fixture, and 67.6 ms p95 at the 2,000-byte ceiling. These figures are diagnostic rather than device acceptance results. Static analysis and 25 automated tests pass, and the Android debug APK builds successfully.

The spike is a go for matrix generation and PNG rendering. Final device sign-off still requires `mobile_scanner` verification on physical iOS and Android devices, degraded-image fixtures, and on-device performance measurements.

---

## 7. QR decoding design

### 7.1 Camera implementation

Use `mobile_scanner` with:

- `formats: [BarcodeFormat.qrCode]` to reduce detection work and false positives;
- the rear camera by default;
- normal detection speed with a short deduplication window;
- torch and camera-switch controls, with front camera treated as secondary;
- an analysis resolution appropriate for mid-range devices;
- lifecycle-aware start/stop behavior; and
- no captured-frame persistence.

On Android, the plugin uses CameraX/ML Kit. Select the **bundled** ML Kit barcode model for MVP so scanning works immediately and offline on first launch. The unbundled option saves application size but can require a Google Play Services download before the first successful scan. Reliability and offline behavior are more important than a few megabytes for Dali QR.

On iOS, the plugin uses Apple's camera/vision stack. If the plugin cannot meet a verified platform requirement, keep the `QrScanner` interface and replace only the iOS adapter with AVFoundation metadata output configured for QR codes.

### 7.2 Detection state machine

```text
idle
  -> requestingPermission
  -> startingCamera
  -> scanning
  -> candidateDetected
  -> pausedForConfirmation
  -> routing | copying | sharing | resuming
  -> scanning
```

Rules:

- Ignore callbacks when not in `scanning` state.
- Hash the raw payload and suppress identical results for at least 1.5 seconds.
- Pause the controller after accepting the first candidate.
- Do not open from the scanner callback.
- Normalize decoder output only for classification; retain the exact raw string for display, copy, and history.
- If bytes cannot be decoded safely as text, classify as binary/unsupported and do not launch.

### 7.3 Image decoding

Use the scanner plugin's file/image analysis API if stable on both platforms. Otherwise, implement platform-specific image decoding behind the same repository. Process a downsampled orientation-corrected image while retaining adequate pixels per module. Run this off the UI path, cancel when the screen closes, and never persist the imported image.

### 7.4 Decoder output contract

```dart
sealed class DecodeResult {}

final class DecodedPayload extends DecodeResult {
  final String rawText;
  final Uint8List? rawBytes;
  final QrSource source; // camera or image
  final DateTime detectedAt;
}

final class NoQrFound extends DecodeResult {}
final class UnsupportedBinaryPayload extends DecodeResult {}
final class DecodeFailure extends DecodeResult {
  final DecodeFailureReason reason;
}
```

Never assume `rawValue` is non-null. Put size ceilings on decoded text and bytes before classification or persistence.

---

## 8. Payload classification and app routing

### 8.1 Principle

Dali QR does not decide that a particular vendor app must open. It classifies the payload, applies a safety policy, and delegates a valid URI to the operating system. Universal Links/App Links and registered URI handlers then select the installed app or browser. This is more reliable and maintainable than maintaining a list of third-party application schemes.

### 8.2 Supported actions

| Payload | Classification | Primary action | Safety behavior |
|---|---|---|---|
| `https://` | Web link | Open link | Show host; delegate to OS |
| `http://` | Insecure web link | Open link | Show warning that transport is not encrypted |
| `mailto:` | Email | Compose email | Display recipient/subject; OS confirmation follows |
| `tel:` | Phone | Call number | Show normalized number and explicit confirmation |
| `sms:` / `smsto:` | Message | Compose message | Display recipient and prefilled body |
| `geo:` | Location | Open map | Show coordinates/query before launch |
| `WIFI:` | Wi-Fi configuration | Show network details | Do not auto-join in MVP; hide password until tapped |

| vCard / `MECARD:` | Contact | Preview contact | Add-to-contacts is a later phase and requires explicit confirmation |
| Plain text | Text | Copy/share | Never reinterpret as a URL silently |
| Unknown/custom scheme | Unsupported link | Copy | Do not launch by default |
| `javascript:`, `data:`, `file:`, `content:`, `intent:` | Blocked | Copy only or reject | Never pass to launcher |

### Verification scope

Generate a domain-based verification code only for an absolute HTTP or HTTPS
URL with a valid registrable domain. For example,
`https://example.com/path` is eligible and derives its domain portion from
`example.com`.

Every non-web payload receives a default content-comparison code in `DDD-LLL`
format: three UTF-8 length digits modulo 1,000 followed by three letters from a
SHA-256 bucket over the complete payload. This code compares content only; it
does not verify the identity or legitimacy of Wi-Fi networks, phone numbers,
email addresses, `geo:` locations, payment recipients, or custom applications.
HTTP/HTTPS URLs without a registrable domain remain unverified web URLs and do
not fall back to the generic content profile.

Creation accepts general QR payload content. Ship non-web launch actions only after dedicated parsing, preview, confirmation, and platform tests.

### 8.3 URL parser and policy

Implement a `PayloadClassifier` and `LaunchPolicy` in Dart. Use `Uri` parsing for syntax, plus application rules:

- Scheme comparison is case-insensitive.
- Allow only an explicit scheme allowlist.
- Reject embedded control characters, invalid percent encoding, oversized values, and unexpected authority forms.
- For web links, display a normalized host and its ASCII/Punycode representation if applicable.
- Detect suspicious Unicode direction controls and mixed-script hostnames; warn or block rather than trying to determine maliciousness conclusively.
- Do not strip query parameters, because that changes the encoded destination. Offer **Copy sanitized link** only as a separate future feature.
- Do not perform DNS, HEAD, Safe Browsing, or redirect resolution in the offline MVP.

### 8.4 Platform launch adapters

`ExternalLauncher.open(LaunchRequest)` is the only interface available to the application layer.

**iOS:** use `UIApplication.open(_:options:)` through `url_launcher` for approved common schemes. Prefer universal links. Avoid probing large lists of installed applications; `canOpenURL` requires declared queried schemes and has platform limits. A failed open returns a recoverable error.

**Android:** use an implicit `ACTION_VIEW` intent for the validated URI and resolve it before launch. Do not build `intent:` URLs from scan data. Catch `ActivityNotFoundException` even after a prior resolution check because device state can change.

**Fallback:** if no handler exists, keep the content visible and offer Copy/Share. For `http`/`https`, platform default behavior normally falls back to the browser.

### 8.5 Dali QR inbound links

Dali QR does not need to register as a general web-link handler for the MVP. If a later share extension or URL scheme is added, use a Dali-owned universal/app link such as `https://qr.dali.example/create?url=...`, validate length and origin, and always place the value in the Create field rather than generating or opening automatically.

---

## 9. Clipboard handling

### 9.1 Policy

- Never read the clipboard on launch, resume, screen change, or in the background.
- Read only after a clear user action: system paste menu, keyboard paste, or a visible **Paste** control.
- Never send clipboard contents to telemetry or logs.
- Do not add clipboard content to history until the user generates a QR code.
- Provide manual entry so clipboard access is never mandatory.

### 9.2 iOS

Programmatic reads can produce privacy prompts. The preferred MVP is a normal editable text field using the system paste menu. If product design requires a dedicated one-tap paste button, implement a small Swift adapter using `UIPasteControl` and bridge its resulting text into Flutter. Do not simulate continuous clipboard detection.

### 9.3 Android

Use `ClipboardManager` only in the direct paste handler. Check that the primary clip can coerce to text, enforce size limits, and discard the temporary value if the Create screen is closed. When Dali QR copies content, rely on Android 13+'s system clipboard confirmation rather than showing a duplicate toast; show app feedback on older versions only.

---

## 10. Permissions and lifecycle

### 10.1 Camera

**iOS configuration:** add `NSCameraUsageDescription`, for example: “Dali QR uses the camera only to scan QR codes.” Request access when Scan is first used, not at launch.

**Android configuration:** declare `android.permission.CAMERA` and request it at runtime. Do not request microphone, location, contacts, or storage for live scanning.

Handle four states:

- not determined: show rationale, then request;
- granted: start scanning;
- denied: explain and offer **Try again** where allowed;
- permanently denied/restricted: offer **Open Settings** and retain **Import image**.

### 10.2 App lifecycle

- Stop camera analysis when the app is inactive, backgrounded, covered by a route, or showing a confirmation result.
- Re-check permission and recreate the camera controller after returning from Settings.
- Release torch state when leaving Scan.
- Treat interruptions such as calls and multi-window changes as recoverable.
- Do not perform camera work in a background isolate after the view disappears.

### 10.3 Photo access

Use system photo pickers that return a user-selected asset. Avoid broad photo-library permission. If a platform/version requires a permission, request the smallest scope and explain why at the moment of import.

---

## 11. Security and privacy

### 11.1 Threat model

Primary threats include phishing links, misleading Unicode domains, dangerous URI schemes, QR codes containing very large or malformed data, repeated scanner callbacks, denial-of-service through expensive parsing, sensitive clipboard/history retention, accidental network requests, and dependency compromise.

### 11.2 Required controls

- Treat every scanned value as untrusted.
- Require confirmation before external launch.
- Use an explicit scheme allowlist and hard-block executable/local schemes.
- Display the destination host prominently and warn on suspicious Unicode presentation.
- Cap input and decoded payload size before parsing, rendering, logging, or storing.
- Do not render scanned HTML, JavaScript, or remote previews.
- Do not fetch favicons, page titles, redirects, or reputation data by default.
- Do not log raw QR contents, clipboard text, query strings, Wi-Fi passwords, phone numbers, or email bodies.
- Strip sensitive values from crash breadcrumbs; log event type and error code only.
- Keep history local, opt-in, and deletable. Never save source frames/images.
- Protect the local database with operating-system sandboxing. If future requirements include long-lived secrets or payment/login payloads, add database encryption and key storage in Keychain/Keystore after a formal threat review.
- Exclude the database from cloud backup if the stated privacy promise is strictly device-local; otherwise disclose backup behavior accurately.
- Use dependency lockfiles, license inventory, automated vulnerability scanning, and reviewed update PRs.
- Disable screenshots on Android only if a future high-security mode warrants the usability tradeoff; it is unnecessary for ordinary links.

### 11.3 Privacy posture

The MVP has no backend, account, advertising SDK, or third-party analytics SDK. If product analytics are later added, use coarse events such as `generation_succeeded` and `permission_denied`, never payload contents or hosts, and gate collection behind a clear privacy decision.

### 11.4 QR authenticity limitation

A valid QR code proves only that the matrix can be decoded; it does not prove the destination is trustworthy. State this in onboarding/help and in the result screen's visual hierarchy. Error correction repairs damaged modules but is not a cryptographic signature.

---

## 12. Offline behavior

The following must work in airplane mode after installation:

- paste/manual entry;
- URL validation;
- QR generation and display;
- PNG/SVG rendering;
- live camera decoding;
- image decoding;
- classification, copying, sharing to locally available targets; and
- local history and settings.

Opening a web URL may fail or show the target app's offline state. Dali QR should report that the handoff was attempted, not claim the remote resource loaded. Bundling the Android ML Kit model is required for guaranteed first-use scanning without a model download.

---

## 13. Data model and history

### 13.1 Domain model

```dart
enum QrActivityKind { generated, scanned }
enum PayloadKind { httpsUrl, httpUrl, email, phone, sms, geo, wifi, contact, text, unsupported }
enum QrSource { manual, clipboard, camera, image }

class QrActivity {
  final String id;
  final QrActivityKind activityKind;
  final PayloadKind payloadKind;
  final String rawPayload;
  final String? displayHost;
  final QrSource source;
  final DateTime createdAtUtc;
  final DateTime? lastOpenedAtUtc;
  final bool favorite;
}
```

Do not store a bitmap for each generated code. Re-render deterministically from `rawPayload` and generation settings. Add an encoder-profile field if styling or error-correction settings become user-selectable.

### 13.2 Drift schema

```sql
CREATE TABLE qr_activities (
  id TEXT PRIMARY KEY NOT NULL,
  activity_kind INTEGER NOT NULL,
  payload_kind INTEGER NOT NULL,
  raw_payload TEXT NOT NULL,
  display_host TEXT NULL,
  source INTEGER NOT NULL,
  created_at_utc INTEGER NOT NULL,
  last_opened_at_utc INTEGER NULL,
  favorite INTEGER NOT NULL DEFAULT 0,
  encoder_profile INTEGER NULL
);

CREATE INDEX idx_qr_activities_created
  ON qr_activities(created_at_utc DESC);
```

Settings include `historyEnabled`, `defaultTab`, `hapticsEnabled`, and `hasSeenSafetyIntro`. Store settings separately from history.

### 13.3 History access and deletion

- Never delete history automatically when the free access window ends.
- Free users can access the most recent week; older entries remain stored and
  are shown as locked without exposing their contents.
- The lifetime customization unlock restores access to the full retained
  history immediately.
- **Clear all** deletes database rows and cached export files.
- If history is disabled, immediately offer to delete existing records; do not assume the user intended deletion without confirmation.
- Saved QRs remain accessible regardless of age until explicitly removed.

---

## 14. Export and share

### 14.1 Export contract

`QrExportService.export(payload, format, profile)` returns a temporary or user-selected file and validates the output before success.

MVP profile:

- PNG, 1024 x 1024;
- black foreground, white opaque background;
- four-module quiet zone;
- no logo or caption inside the QR bounds;
- lossless encoding;
- deterministic filename such as `dali-qr-example-com-20260818-172301.png`, with illegal characters removed and collisions handled.

Put human-readable captions outside the QR image or in a separate share message. Captions must never reduce the quiet zone.

### 14.2 Export verification

Before release, decode exported fixtures after:

- PNG save/load;
- common share-sheet handoff;
- downscaling to representative messaging-app sizes;
- light print/scan simulation;
- display on a second device at low and high brightness.

Runtime self-decoding of every export is optional and may be too expensive; build-time and integration-test verification is mandatory.

---

## 15. Error handling and edge cases

| Condition | Expected behavior |
|---|---|
| Empty or whitespace input | Keep Create disabled; explain required input after interaction |
| Missing scheme | Offer explicit HTTPS repair |
| Relative URL | Reject for generation |
| Very long URL | Show byte count/limit and suggest a shorter source link; never silently shorten |
| Unicode/emoji path | Encode UTF-8 and round-trip test exact value |
| Internationalized hostname | Display Unicode and ASCII/Punycode forms when different |
| Credentials in URL | Reject by default and explain the risk |
| Camera denied | Show recovery and image import |
| Camera unavailable/in use | Show retry and import option |
| Low light | Offer torch and guidance |
| Blurry/tiny/damaged QR | Keep scanning; provide distance/focus guidance |
| Inverted QR | Support if decoder backend does; include test fixture |
| Multiple QRs | Pause and let user select; never open all |
| Same QR detected repeatedly | Deduplicate and pause after first accepted result |
| Empty decode result | Ignore or show unsupported result; never crash |
| Binary payload | Show unsupported and allow safe metadata/copy only if representable |
| Plain text that resembles a domain | Treat as text; offer a separate **Open as HTTPS** action only after confirmation |
| Blocked URI scheme | Explain that Dali QR will not open it; allow copy with warning |
| No installed handler | Keep result visible and offer copy/share |
| OS launch returns false | Show non-destructive error; do not loop |
| App backgrounded during scan | Stop camera and resume safely on return |
| Database migration failure | Preserve database, enter read-only recovery, and provide export/clear options |
| Disk full during export | Keep QR on screen and offer copy/share text |
| Right-to-left/control characters | Escape or visibly mark controls; prevent display spoofing |

---

## 16. Testing strategy

### 16.1 Unit tests

- URL trimming, parsing, validation, and explicit HTTPS repair.
- Scheme allowlist/blocklist and routing decision table.
- Unicode, Punycode, bidirectional controls, percent encoding, and credentials.
- Payload byte ceilings and malformed URI inputs.
- QR settings selection and matrix dimensions.
- Scanner deduplication/state transitions.
- Free-history access gating, saved QRs, and database migrations.
- Redacted logging: assert payloads never appear in logs.

### 16.2 QR conformance tests

Create a checked-in corpus covering:

- empty/minimum values where supported;
- ASCII and UTF-8 URLs;
- lengths immediately below and above version transitions;
- multiple QR versions and M/Q error correction;
- query strings, fragments, percent escapes, and international domains;
- high-density matrices;
- all masks as produced by reference fixtures, when available;
- rotated, perspective-distorted, blurred, low-contrast, inverted, and partially damaged images.

For every generated fixture:

1. Decode with Dali QR's scanner backend.
2. Decode with at least one independent implementation, such as ZXing.
3. Assert byte-for-byte or documented Unicode-equivalent payload equality.
4. Render, save, reload, and decode the exported PNG.

Do not test only by comparing images: different valid encoders may select different segmentations or masks.

### 16.3 Widget and golden tests

- Create states: empty, invalid, valid, generating, result, export failure.
- Scan permission states and paused confirmation sheet.
- Long host and payload wrapping at small text widths.
- Dynamic Type/text scaling, RTL layout, dark mode, and high contrast.
- QR geometry: quiet zone remains intact at every supported screen size.

Golden tests verify UI appearance but never replace decode tests.

### 16.4 Integration tests

- Paste -> generate -> export -> import -> decode exact payload.
- Camera permission grant, denial, permanent denial, and Settings return.
- Scan -> confirm -> OS launch mock for every allowed payload type.
- Share PNG and cleanup temporary file.
- Enable history -> create/scan -> restart -> one-week access gate -> unlock -> search -> delete.
- Offline cold start and first scan on Android.

### 16.5 Real-device matrix

Use at least:

- current and oldest-supported iPhone;
- current iOS release and oldest-supported iOS release;
- a Pixel-class device;
- a Samsung mid-range device;
- oldest-supported Android API/device class; and
- one low-memory Android device.

Camera scanning cannot be signed off solely on simulators/emulators.

### 16.6 Security testing

- Fuzz classifier and URI policy with arbitrary Unicode and malformed encodings.
- Verify blocked schemes never reach the platform launcher mock.
- Verify no network socket is opened during generation, scan, classification, or history use.
- Inspect release logs, crash reports, backups, and temporary directories for payload leakage.
- Run dependency and license scans in CI.
- Test maliciously large images and decompression-bomb defenses in image import.

---

## 17. Accessibility and localization

- Give every action a semantic label and state; do not use color alone for validity or warnings.
- Announce successful scan once, then pause scanning to avoid repeated screen-reader output.
- Provide haptic feedback with a setting to disable it.
- Support large text without covering the QR image; allow the result page to scroll.
- Maintain high contrast around the scanner guide and controls.
- Respect Reduce Motion and platform theme preferences.
- Keep decoded text selectable and navigable with assistive technology.
- Localize UI strings, but never localize or modify the encoded/decoded payload.
- Test right-to-left UI separately from right-to-left characters inside untrusted payloads.

---

## 18. Observability and operations

The app should be supportable without collecting payloads.

Safe diagnostics may include:

- application version, OS version, device class;
- event name such as scanner startup failure;
- permission state category;
- payload type category, not value or host;
- QR version and byte-length bucket, not content;
- library error code and redacted stack trace.

Provide an in-app **Copy diagnostics** action that shows exactly what will be copied. No remote kill switch or backend is required for MVP. Maintain a release checklist covering dependency pins, privacy manifests/declarations, permission text, offline scan test, and exported-code conformance.

---

## 19. Phased roadmap

### Phase 0 - Technical spike (1 week)

- Bootstrap Flutter iOS/Android project and CI.
- Prove `qr`/`qr_flutter` generation and `mobile_scanner` decoding on real devices.
- Validate bundled Android scanner behavior offline.
- Prove exact round trip for ASCII, UTF-8, long URLs, and exported PNG.
- Prototype OS routing behind a strict allowlist.
- Decide final minimum OS versions from plugin/toolchain constraints.

**Exit:** a non-production harness generates, exports, scans, and independently verifies the test corpus.

### Phase 1 - MVP create and scan (3-4 weeks)

- Create and Scan screens.
- Explicit paste/manual entry and URL validation.
- QR generation with fixed M profile and safe rendering.
- Live QR-only scanner, permission states, torch, and lifecycle.
- Confirmation result screen.
- `http`/`https` routing only.
- PNG share/save and copy text.
- No history, backend, analytics, or decorative QR features.

**Exit:** store-ready internal build passes accessibility smoke tests and real-device conformance.

### Phase 2 - Local utility completion (2-3 weeks)

- Opt-in Drift history with one-week free access, lifetime unlock, and explicit deletion.
- Import QR from a system-selected image.
- Plain text, email, phone, SMS, and geo classification with per-type confirmation.
- SVG export.
- Improved suspicious-host presentation and diagnostics.

**Exit:** public v1 candidate with privacy review, threat-model review, and migration tests.

### Phase 3 - Quality and advanced payloads (2-4 weeks)

- Wi-Fi and contact previews.
- Multiple-code image selection.
- Favorites and advanced error-correction export setting.
- Expanded low-light, damaged-code, and device compatibility work.
- Optional native scanner replacement only if measured plugin gaps justify it.

### Deferred/conditional

- Share extension into Dali QR.
- Encrypted history or biometric lock.
- Dynamic QR service, synchronization, or link analytics; each requires a backend, account model, abuse prevention, privacy policy changes, and a new security design.
- Styled/logo QR codes; require automated scannability validation and strict design constraints.

---

## 20. Engineering acceptance checklist

### Generation

- [ ] Exact accepted input is visible before and after generation.
- [ ] Library chooses QR version and mask; app does not implement QR math.
- [ ] M error correction and four-module quiet zone are enforced.
- [ ] PNG has integer module geometry and no interpolation.
- [ ] Export corpus decodes with Dali QR and an independent decoder.

### Scanning

- [ ] QR-only detection is configured.
- [ ] Android model is bundled for offline first use.
- [ ] Camera stops outside active scan state.
- [ ] Duplicate callbacks cannot trigger multiple sheets or launches.
- [ ] Frames and imported images are not persisted.

### Routing and security

- [ ] Every launch follows a visible confirmation.
- [ ] Only allowlisted schemes can reach the platform launcher.
- [ ] `javascript`, `data`, `file`, `content`, and `intent` are blocked.
- [ ] URL host is prominent; suspicious Unicode is surfaced.
- [ ] No preview, redirect, favicon, or reputation network request occurs.

### Privacy

- [ ] Clipboard is read only after explicit user intent.
- [ ] History is opt-in, local, expiring, and deletable.
- [ ] Logs and crash reports contain no raw payloads.
- [ ] Temporary exports are cleaned up.
- [ ] Permission declarations match actual use.

### Quality

- [ ] Unit, widget, conformance, integration, and real-device tests pass.
- [ ] Dependency versions and licenses are recorded.
- [ ] Offline cold-start generation and scanning pass.
- [ ] Large text, screen reader, RTL, dark mode, and low-memory checks pass.

---

## 21. Key implementation interfaces

```dart
abstract interface class QrEncoder {
  QrMatrix encode({
    required String payload,
    required QrErrorCorrection correction,
  });
}

abstract interface class QrScanner {
  Stream<DecodedPayload> get detections;
  Future<void> start();
  Future<void> pause();
  Future<void> stop();
  Future<DecodeResult> analyzeImage(String selectedFilePath);
}

abstract interface class PayloadClassifier {
  ClassifiedPayload classify(String rawPayload);
}

abstract interface class LaunchPolicy {
  LaunchDecision evaluate(ClassifiedPayload payload);
}

abstract interface class ExternalLauncher {
  Future<LaunchOutcome> open(ApprovedLaunchRequest request);
}

abstract interface class QrHistoryRepository {
  Stream<List<QrActivity>> watchRecent();
  Future<void> save(QrActivity activity);
  Future<void> delete(String id);
  Future<void> deleteExpired(DateTime cutoffUtc);
  Future<void> clear();
}
```

Enforce the security boundary in types: `ExternalLauncher` accepts only an `ApprovedLaunchRequest` that can be constructed by `LaunchPolicy`, not an arbitrary string from a widget or scanner callback.

---

## 22. Reference implementation notes

The following primary documentation should be rechecked when dependencies are locked or upgraded:

- [Flutter architectural overview and native interoperability](https://docs.flutter.dev/resources/architectural-overview)
- [Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels)
- [`mobile_scanner` package](https://pub.dev/packages/mobile_scanner)
- [`qr_flutter` package documentation](https://pub.dev/documentation/qr_flutter/latest/)
- [`url_launcher` package](https://pub.dev/packages/url_launcher)
- [`share_plus` API](https://pub.dev/documentation/share_plus/latest/share_plus/)
- [Drift native SQLite backend](https://pub.dev/documentation/drift/latest/native/)
- [Apple machine-readable QR metadata types](https://developer.apple.com/documentation/avfoundation/machine-readable-object-types)
- [Apple `UIPasteboard`](https://developer.apple.com/documentation/uikit/uipasteboard)
- [Apple `UIPasteControl`](https://developer.apple.com/documentation/uikit/uipastecontrol)
- [Apple opening URL resources](https://developer.apple.com/documentation/uikit/uiapplication/open(_:options:completionhandler:))
- [Android ML Kit barcode scanning](https://developers.google.com/ml-kit/vision/barcode-scanning/android)
- [Android common intents](https://developer.android.com/guide/components/intents-common.html)
- [Android copy and paste](https://developer.android.com/develop/ui/views/touch-and-input/copy-paste)

---

## 23. Final recommendation

Build Dali QR as a small Flutter app with a deliberately narrow native boundary. Creation accepts general QR payload content, while verification remains limited to web URLs with registrable domains. Keep QR-only live scanning, explicit result confirmation, OS-mediated routing, local history, and PNG clipboard export behind clearly separated classification, verification, and action policies.

The defining engineering principle is separation of concerns: proven libraries own QR encoding and visual decoding; Dali QR owns user intent, safe presentation, routing policy, privacy, exports, and verification. That division minimizes standards risk while keeping the parts that define user trust under direct product control.
