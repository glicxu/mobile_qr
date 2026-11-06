# Dali QR

Dali QR creates and scans 13 common barcode formats offline while
keeping classification, content comparison, domain verification, and OS
routing separate.

New and existing users without lifetime access receive one free calendar month
of lifetime benefits, starting when they first use a paid creation option. The unlock
screen when using a trial benefit and Settings show the remaining time. The trial is stored on the device;
it does not start a subscription or automatically charge the user.

The lifetime unlock includes barcode creation and the Wi-Fi, contact, event,
location, email, phone, and SMS QR creation forms, alongside custom logo exports
and extended history. Basic text/link QR creation, scanning, and security checks
remain free.

Payments is hidden from navigation and Settings for all users while further
work and planning continue. Its separate workspace implementation is retained;
production purchases and provider integrations remain disabled.
See the [Payments package](docs/payments_package.md).

## Supported content

- Creation defaults to QR Code. A Code format dropdown also selects UPC-A,
  UPC-E, EAN-8, EAN-13, Code 128, Code 39, Code 93, Codabar, ITF-14,
  Data Matrix, PDF417, or Aztec. Generated codes support PNG copy/share and
  Save to Saved with their original format. QR decorations remain QR-only.
  See [generation rules and validation](docs/qa/barcode_generation.md).

- HTTP/HTTPS URLs with domain-based verification when a registrable domain is
  available
- Email, telephone, SMS, location, Wi-Fi, vCard, and calendar payloads with a
  content-comparison code
- Guided QR creation forms for Contact, Event, Location, Email, Phone and SMS,
  alongside Wi-Fi and Text or link. See [protocol scope and validation](docs/qa/protocol_expansion.md).
- Authenticator TOTP/HOTP setup-code recognition with masked secrets and a
  confirmed handoff to a compatible installed authenticator. Setup codes are
  excluded from History, Saved, batch export and QR generation. Provider import
  and iOS validation remain pending; opening an app does not confirm enrollment.
- Unknown text and custom URI schemes as display-only content
- Wi-Fi code review with hidden passwords and user-approved network handoff:
  Create → QR content type → Wi-Fi network generates a standard Wi-Fi QR from
  an SSID, password, security type and optional hidden-network flag.
  Android 11+ can pass open and WPA/WPA2 credentials to system approval;
  WPA3 is offered when the OS reports support. Older/unsupported devices keep
  manual settings. Already-saved Android networks open Wi-Fi settings for
  explicit selection, since saving again does not force a network switch.
  iOS joining is staged and awaits signing/device validation.
  See [Wi-Fi join scope and checks](docs/qa/wifi_join.md).
- FIDO passkey QR requests with explicit confirmation and native OS handoff
  on Android and iOS; requires an available passkey provider. The provider
  handles Bluetooth proximity, credentials, and biometric/PIN approval.
  Opening the provider does not report successful authentication to Dali QR.
  Passkey scans do not receive comparison codes or enter automatic history.
- Camera, photo-library, and share-sheet scanning for QR Code, UPC-A, UPC-E,
  EAN-8, EAN-13, Code 128, Code 39, Code 93, Codabar, ITF-14, Data Matrix,
  PDF417, and Aztec. Live scanning uses the native decoder; imported images
  also use a bounded local fallback for the three additional
  2D formats. Supported results require a decoded text value.
- Explicit Save to Saved, exact-value copying, and Scan again from results;
  see [Android implementation and validation](docs/qa/universal_scanner.md).
  Android validation is in progress; iOS changes await Mac/device validation.
- Offline UPC/EAN and ISBN candidate checks, with original values retained and
  derived UPC-A/ISBN-13 values shown separately. A matching check digit does not
  establish that a product or book exists. See [recognition scope](docs/qa/identifier_checks.md).
- Offline GS1 Digital Link field review for a documented GTIN/qualifier subset; online resolution is unavailable
- Local Saved collections, tags and search
- Local batch sessions with explicit capture/count modes and confirmed CSV export;
  see [scope and validation](docs/qa/local_workflows.md)
- Opt-in local history with one week of free access; older entries stay on the
  device and unlock with lifetime customization
- Free previews for custom center images, with export enabled by a lifetime
  customization purchase

External actions always require user confirmation. Unknown URI schemes never
launch automatically. Wi-Fi passwords are hidden until explicitly revealed.

Website results show the full destination, scheme, host, and local warnings;
the Open button launches the reviewed link directly. Local review makes no request to the scanned destination
and does not establish site safety. Malformed or ambiguous links stay inert.
Calendar handoff supports single timed events using local or UTC time; all-day
dates can be viewed, while named timezones, recurrence, and duration-only events
remain display-only. Product information lookup is unavailable until an online
provider is selected and validated; numeric barcodes display their identifiers.

## Development

```text
flutter run
flutter analyze
flutter test
flutter build apk --debug
```

Android debug builds install separately as `com.dalifin.qr.test`, labeled
`Dali QR Test`, with a red TEST ribbon on the launcher icon. They use their
own app data. Release builds retain the production name, ID, and icon.

## Android release signing

Copy `android/key.properties.example` to `android/key.properties`, point
`storeFile` at the production upload keystore, and replace every placeholder.
The real property file and keystores are ignored by source control. Without
that file, release artifacts are intentionally produced without production
signing.

```text
flutter build appbundle --release
```

## Lifetime customization product

Create a non-consumable product in both Google Play Console and App Store
Connect using this exact identifier:

```text
dali_secure_qr_lifetime
```

The store purchase sheet supplies the current localized price; the app does not
display a price. Custom QR previews remain available without purchase; copy,
share, and history persistence of the customized image require the entitlement.
Plain QR codes, Dali icon/code decorations, scanning, routing, and verification
remain free. Test purchases using store sandbox or license-test accounts because
an APK installed directly with ADB cannot load a normal Play product unless the
app and account satisfy Play testing rules.

## Remaining release checks

- Test FIDO sign-in with fresh website QR codes on physical Android and iOS
  devices, including approval, cancellation, expired codes, Bluetooth disabled,
  and missing passkey/provider. iOS native compilation requires macOS/Xcode.
- Compile and exercise the iOS contacts and calendar routes on macOS/Xcode.
- Test email, telephone, SMS, maps, Wi-Fi, contacts, and calendar routing on
  the intended physical Android and iOS devices.
- Supply store descriptions, screenshots, privacy disclosures, and production
  signing credentials through the relevant store accounts.
- Keep decoded code payloads and Wi-Fi credentials out of telemetry and crash
  reports.
