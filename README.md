# Dali QR

Dali QR creates and scans general QR payloads while keeping classification,
content comparison, domain verification, and OS routing separate.

## Supported content

- HTTP/HTTPS URLs with domain-based verification when a registrable domain is
  available
- Email, telephone, SMS, location, Wi-Fi, vCard, and calendar payloads with a
  content-comparison code
- Unknown text and custom URI schemes as display-only content
- Opt-in local history with copyable comparison codes and QR images

External actions always require user confirmation. Unknown URI schemes never
launch automatically. Wi-Fi passwords are hidden until explicitly revealed.

## Development

```text
flutter run
flutter analyze
flutter test
flutter build apk --debug
```

## Android release signing

Copy `android/key.properties.example` to `android/key.properties`, point
`storeFile` at the production upload keystore, and replace every placeholder.
The real property file and keystores are ignored by source control. Without
that file, release artifacts are intentionally produced without production
signing.

```text
flutter build appbundle --release
```

## Remaining release checks

- Compile and exercise the iOS contacts and calendar routes on macOS/Xcode.
- Test email, telephone, SMS, maps, Wi-Fi, contacts, and calendar routing on
  the intended physical Android and iOS devices.
- Supply store descriptions, screenshots, privacy disclosures, and production
  signing credentials through the relevant store accounts.
- Keep decoded QR payloads and Wi-Fi credentials out of telemetry and crash
  reports.
