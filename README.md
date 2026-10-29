# Dali QR

Dali QR creates and scans general QR payloads while keeping classification,
content comparison, domain verification, and OS routing separate.

## Supported content

- HTTP/HTTPS URLs with domain-based verification when a registrable domain is
  available
- Email, telephone, SMS, location, Wi-Fi, vCard, and calendar payloads with a
  content-comparison code
- Unknown text and custom URI schemes as display-only content
- FIDO passkey QR requests with explicit confirmation and native OS handoff
  on Android and iOS; requires an available passkey provider. The provider
  handles Bluetooth proximity, credentials, and biometric/PIN approval.
  Opening the provider does not report successful authentication to Dali QR.
  Passkey scans do not receive comparison codes or enter automatic history.
- Opt-in local history with one week of free access; older entries stay on the
  device and unlock with lifetime customization
- Free previews for custom center images, with export enabled by a lifetime
  customization purchase

External actions always require user confirmation. Unknown URI schemes never
launch automatically. Wi-Fi passwords are hidden until explicitly revealed.

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
dali_secure_qr_custom_lifetime
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
- Keep decoded QR payloads and Wi-Fi credentials out of telemetry and crash
  reports.
