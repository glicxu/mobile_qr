# Wi-Fi code → network approval

Date: 2026-10-29. Android-first implementation. iOS compilation, provisioning
and device validation remain pending by user direction.

## Behavior

Create defaults to QR and Text or link. Select QR content type → Wi-Fi network
to enter the exact SSID, password, security (WPA/WPA2 Personal, WPA3 Personal,
or open) and hidden-network flag. Fields are escaped into a standard `WIFI:`
payload locally. The password starts masked, and the generated result requires
an explicit reveal to show the raw credentials. Existing image sharing and
explicit Save work for these QR codes. Open profiles omit any stale password.
Private hotspot credentials and their QR images are excluded from QA evidence.

Scanning a supported `WIFI:` code offers Join network. The review shows the
exact SSID, security type and hidden-network flag. Passwords remain hidden until
Reveal is selected. A QR content-comparison code is shown when available; it
does not authenticate a network or establish internet safety.

Joining is an explicit action after review. Android 11/API 30 and newer use
`Settings.ACTION_WIFI_ADD_NETWORKS`, supplying a `WifiNetworkSuggestion` with
the scanned credentials. The OS handles approval, saved configuration and
connection attempts. This is the public [saved-network API](https://developer.android.com/develop/connectivity/wifi/wifi-save-network-passpoint-config),
not an app-local `requestNetwork` connection or a background suggestion.
The app does not force Wi-Fi on, bind app traffic to a network, enumerate saved
credentials, scan nearby SSIDs, or probe internet endpoints.

The native result distinguishes saved, already saved, cancelled, unsupported,
busy and failure. A successful save is reported as a save and connection attempt,
not as a verified connection or working internet. For an already saved network,
the app opens system Wi-Fi settings immediately so the user can select that
network. The review replaces the repeated Join action with Select network in
Wi-Fi settings; it does not claim to have switched networks. Android can keep
the existing home connection when the save API returns already-exists. If
settings cannot open, explicit manual instructions remain visible. Device/OEM support is checked before offering
the join button. Older Android versions and unsupported configurations retain
Open Wi-Fi settings and the readable credential details.

## Supported profiles and validation

| Profile | Android 11+ | iOS source |
|---|---|---|
| Open (`nopass`, or absent type without a password) | System approval | Hotspot Configuration; pending validation |
| WPA/WPA2 Personal (`WPA`, `WPA2`, PSK aliases) | System approval; 8–63 printable ASCII passphrase | Hotspot Configuration; pending validation |
| WPA3 Personal (`SAE`, `WPA3`, `WPA3-SAE`) | Offered only when the OS reports SAE support; 1–63 printable ASCII passphrase | Not enabled |
| WEP / enterprise / unknown security | Manual settings | Manual instructions |
| Raw 64-digit PSKs, non-ASCII passphrases, malformed fields | Manual configuration or non-actionable review | Same conservative validation |

SSID is 1–32 UTF-8 bytes with no control characters. SSID/password whitespace,
escaped separators and percent characters remain literal. No trimming, URI
decoding, or password normalization occurs. Unsupported types, enterprise
fields and contradictory open/password data never fall back to an open join.
The router reparses the original code and rejects substituted field maps.
Native code validates the sanitized arguments again.

Android requests only the normal `ACCESS_WIFI_STATE` permission for capability
inspection. It adds package-visibility queries for the two Settings actions;
there are no new runtime location or nearby-device permission prompts.
Both Settings handoffs resolve exported system-app components and use explicit
intents; credentials are never delivered to a third-party intent handler or
chooser. Resolution uses Android's [system-only query flag](https://developer.android.com/reference/android/content/pm/PackageManager#MATCH_SYSTEM_ONLY).
Only one native join can be pending. Requests are completed on cancellation or
activity destruction; unrelated activity results continue to Flutter plugins.

Malformed Wi-Fi codes remain recognized as sensitive, non-actionable Wi-Fi
content. Expanding Details no longer reveals raw Wi-Fi credentials implicitly.
Raw Wi-Fi codes in scanner, History and Saved require an explicit reveal.
Existing opt-in history and explicit Save policies remain unchanged; this
feature adds no credential logging or additional app-side password store.

## iOS staging

Runner uses `NEHotspotConfigurationManager.apply` for open and WPA/WPA2 networks,
with the hidden flag and persistent user-approved configuration. Cancellation,
pending requests and already-associated outcomes are handled separately.
Accepted configuration is not labeled as verified internet access.

The [Hotspot Configuration capability](https://developer.apple.com/documentation/networkextension/nehotspotconfigurationmanager)
and `com.apple.developer.networking.HotspotConfiguration` entitlement are added
to Runner only. The App ID/provisioning profile must include this capability
before signing. No private `App-Prefs` Wi-Fi URL is used. Share Extension
results remain read-only and do not receive this capability. macOS/Xcode and
physical iPhone validation have not been performed here.

## Evidence

Host checks cover exact parsing, Unicode SSID byte bounds, hidden flags,
unsupported security and invalid passwords, forged fields, typed native
outcomes, password masking, manual fallback, duplicate taps, cancellation,
and explicit reveal of malformed raw Wi-Fi content.
The full host suite passes 282 tests; static analysis reports no issues.
Creation tests cover the actual Create-to-QR flow, exact PNG decoding,
escaped credential round trips, password masking, and omission of stale
passwords when choosing an open network.

Isolated native integration runs use disposable `com.dalifin.qr.scannerqa`
installations, not the normal test or production app. The tests exercise the
production review/router/Android handler, inspect the real system screen for
an exact synthetic SSID, then press Back. Native invalid arguments are rejected
before handoff; a second in-flight request returns busy. No network is approved.
The tool removes its QA app and restores the previous Wi-Fi radio setting.

QA safety correction: a later protocol run exposed Flutter's stale cached APK
identity during automatic integration cleanup. The normal tablet test package
was removed despite a separate QA ID. Both runners now prebuild/verify the QA
identity, use `--no-uninstall`, clean up only the QA package and check protected
package presence. Earlier functional reports do not establish data preservation;
see the [cleanup incident](qa_cleanup_incident.md).

Both SM-T290/API 30 and SM-G975U/API 31 passed these checks for open and
WPA/WPA2. During both runs the OS did not report WPA3 capability, so the WPA3
case was recorded as unsupported rather than counted as an approved join.
See [current validation](evidence/wifi-join-validation.json) and detailed
[tablet](evidence/wifi-join-tablet.json) / [phone](evidence/wifi-join-phone.json)
observations.
Final release and ordinary debug APK builds pass. The ordinary debug update
is installed on both devices, and each installed base APK hash matches the
local debug artifact. Release remains local and unpublished.

```text
flutter analyze
flutter test
python tool/qa_wifi_join.py --serial <device-id> --output <report.json>
flutter pub get
flutter build apk --release
flutter build apk --debug
```

Run Flutter build/analysis commands sequentially: concurrent release and debug
plugin-registry generation can leave the development-only integration plugin
in a release registry. The isolated native test also builds a `.scannerqa` APK;
the final ordinary debug rebuild restores `com.dalifin.qr.test`.

## Remaining live validation

The first private hotspot test exposed a fixture mismatch: the QR supplied
for testing used an ASCII apostrophe (U+0027), whereas the actual hotspot name
visible in Android Settings used a curly apostrophe (U+2019). Both devices
reported the encoded network as already saved; neither was associated with
that encoded name. The private QR has been corrected and independently decoded.
A synthetic SSID regression verifies exact curly-apostrophe preservation through
QR PNG decoding, classification and native arguments (all four creation tests
pass). SSIDs must remain literal; the app must not normalize punctuation into
a different network name. The corrected QR was observed in the app with the
exact curly-apostrophe SSID. Android returned already-saved and stayed on the
home connection. The user then forgot only the hotspot profile for a clean
first-time join test. Scanning the corrected QR and approving Android's prompt
switched the tablet to the hotspot. A UTF-8-decoded `cmd wifi status` check
confirmed the exact target SSID and completed supplicant state; Android's
connectivity service reported validated Wi-Fi. No app or QA internet probe was
sent. See [redacted live tablet evidence](evidence/wifi-join-live-tablet.json).

The first-time saved-network approval and actual association are now verified
on the tablet with a private iPhone hotspot QR. Connectivity is OS-reported;
no independent internet request was made. Wrong password, absent AP and
captive-portal behavior still need live coverage. Phone first-time association
and the updated already-saved settings handoff need separate live coverage.
Additional Android OS/OEM coverage and iOS signing/device checks remain open.
No release artifact has been published.
