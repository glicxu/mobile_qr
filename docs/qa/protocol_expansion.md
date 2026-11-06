# Structured QR creation and authenticator recognition

Date: 2026-10-29. WP12 and WP13 working-tree implementation; Android-first
validation. iOS compilation, signing and physical-device checks remain pending.
Matter and payments are explicitly deferred by the user; their
[feasibility findings](../decisions/protocol_feasibility.md) are retained for later.

## Create forms — WP12

Code format still defaults to QR and QR content type still defaults to Text or
link. The existing dropdown now also offers Contact, Event, Location, Email,
Phone and SMS alongside Wi-Fi. Other barcode formats retain their existing
content input, validation and export behavior. Generated structured QR codes
reuse the existing decorated/plain rendering, validated preview, PNG copy/share,
explicit Save and opt-in History flow. Existing customization entitlements apply.

| Type | Implemented inputs and encoding | Limits |
|---|---|---|
| Contact | Name, optional phone/email; vCard 3.0 with FN/N, escaped text and UTF-8 line folding | One phone/email; no contact authenticity or subscriber verification |
| Event | Title, start/end pickers, optional location/description, local/UTC selector; VCALENDAR/VEVENT with UID and DTSTAMP | One timed event; end must be after start; no recurrence, named timezone or all-day expansion. Floating local times use the scanning device's zone. |
| Location | Decimal latitude/longitude in `geo:` | Latitude −90…90, longitude −180…180; leading +/zeros and omitted integer/fraction digits use valid URI decimal syntax without rounding fractional precision; no remote address lookup |
| Email | One recipient, optional subject/body; percent-encoded `mailto:` | ASCII local part, IDNA domain; no display names or SMTPUTF8 local parts; CRLF body line breaks |
| Phone | One number in `tel:`; visual separators removed | Optional leading +; no service codes, extensions or URI parameters; international country code recommended |
| SMS | One recipient, optional body in percent-encoded `sms:` | Composer handoff only; body compatibility needs platform evidence |

Names, messages and Unicode punctuation remain literal apart from each
protocol's required escaping/representation. vCard/iCalendar lines fold at
75 UTF-8 bytes without splitting characters. Invalid controls, injection-like
single-line fields, impossible coordinate ranges and missing event times fail
before generation. Existing QR payload size limits apply. Email review decodes
recipient percent escapes for display while retaining the encoded launch URI.

Creation does not invoke contacts, calendar, maps, dialer or messaging apps.
Scanning still requires explicit confirmation before a native action. Opening
a composer/editor/dialer does not send, save or call, and no outcome claims
those actions completed.

## Authenticator setup — WP13

`otpauth:` TOTP/HOTP codes receive dedicated local recognition and a confirmed
Open authenticator action. The router reparses the original payload, checks
the target, checks for a compatible handler, and uses an external-app handoff.
The handler probe uses a fixed account-free, secret-free URI because the Android
launch plugin can log capability queries in debug builds. Only the confirmed
launch receives the real provisioning URI.
Unknown custom URI schemes remain inert. Android package queries and the iOS
query-scheme declaration are limited to `otpauth` for this feature.

Supported local validation:

- Unpadded Base32 secrets with valid remaining bits; case-insensitive alphabet.
- TOTP/HOTP, SHA1/SHA256/SHA512, 6/8 digits. TOTP period 1–86400 seconds
  (default 30); HOTP requires an unsigned 64-bit counter.
- One account label, consistent optional issuer prefix/query, no duplicate or
  unknown parameters, credentials-in-authority, fragment or control characters.
- Maximum 4096 UTF-8 bytes. Unsupported profiles are recognized as sensitive
  but stay non-actionable. `otpauth-migration:` imports are not implemented.

Secrets and raw provisioning content remain hidden until explicitly revealed.
Confirmation shows account/issuer and a trusted-authenticator reminder, never
the secret. Detection does not launch a provider. There is no content comparison
code, automatic History, Saved, batch capture/export, or QR generation/export
for provisioning codes, including malformed recognizable inputs. Legacy stored
codes are masked and their QR image reconstruction is suppressed; data is not
silently deleted. Explicit text copying remains a user action.

No built-in OTP generator, random third-party enrollment seed, account sync,
provider-account access or completed-enrollment claim is introduced. A handler
is a compatible installed application, not a verified provider identity. Missing
handlers retain a local explanation; actual authenticator import still needs
provider/device validation without adding an account automatically.

## Verification and remaining evidence

Host tests cover each Create form through its generated QR, exact PNG decoding,
interpreted fields, UTC/local events, Unicode folding, URI delimiters and
validation failures. Authenticator tests cover supported/invalid profiles,
masked review, confirmation/cancellation, provider absence, forged targets,
History/Saved exclusions and batch/creation/export rejection.

`tool/verify_structured_qr.py` independently decodes the six synthetic PNGs with
ZXing-C++. `tool/qa_structured_qr.py` uses an isolated disposable QA package for
Android native decoding, authenticator cancellation/availability and confirmed
ordinary action handoffs. The watcher observes external activities, then
returns to the QA app without pressing Send, Save, Call or provider-account
buttons. A resolver/permission screen is recorded as such and does not prove
composer/editor prefill or completion. Earlier runs exposed a Flutter cleanup
identity error that removed the tablet's normal test installation. See the
[cleanup incident and safeguards](qa_cleanup_incident.md); historical functional
results do not establish preservation of the prior test-app data.

The host suite passes 304 tests and static analysis reports no issues. All six
synthetic payloads pass independent ZXing-C++ decoding and exact native decoding
on SM-T290/API 30 and SM-G975U/API 31. Confirmed handoffs reach native editors,
composers, maps or app choosers; SMS has no compatible handler on the tablet,
and its fallback is recorded. The phone reaches a messaging handler.

Authenticator cancellation/availability checks and credential-free probe
rechecks pass on both devices. The tablet reports no handler; the phone reports
available handlers. No provider was launched or authenticator account added.
See detailed [tablet](evidence/protocol-native-tablet.json),
[phone](evidence/protocol-native-phone.json),
[tablet authenticator](evidence/authenticator-native-tablet.json) and
[phone authenticator](evidence/authenticator-native-phone.json) evidence.

Artifact hashes and remaining checks are recorded in the
[validation report](evidence/protocol-expansion-validation.json). Authenticator
provider import, full native prefill verification, additional Android versions
and iOS remain separate checks. No release has been published.
The final ordinary debug APK is installed on both Android devices, with
installed base-APK hashes matching the local artifact. The tablet's Create
dropdown was checked directly for all eight options. The corrected QA safety
runner also passed on both devices with protected installations preserved;
this does not establish recovery of data from the earlier cleanup incident.

References: [vCard 3.0](https://www.rfc-editor.org/rfc/rfc2426),
[iCalendar](https://www.rfc-editor.org/rfc/rfc5545),
[mailto](https://www.rfc-editor.org/rfc/rfc6068),
[SMS URI](https://www.rfc-editor.org/rfc/rfc5724),
[geo URI](https://www.rfc-editor.org/rfc/rfc5870),
[authenticator provisioning](https://github.com/google/google-authenticator/wiki/Key-Uri-Format).
