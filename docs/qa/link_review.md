# Local interpretation and destination review

**Date:** 2026-10-29<br>
**Work package:** M1 / WP2 — implemented locally; release gate remains open<br>
**Foundation checks:** [M0 scanner matrix](scanner_matrix.md)

**Update (2026-11-06):** The Open button on a reviewed result now launches a
valid web destination directly. The result screen retains its destination and
warnings, and the router still validates the destination before launch. The
earlier recorded device evidence below predates this change.

## Implemented behavior

- `LinkInspector` performs local syntax and host interpretation only. Results
  retain the exact decoded value and separately expose the parsed URI, scheme,
  ASCII host spelling, warnings, and any blocking interpretation problem.
- HTTP, URL user information before `@`, internationalized/Punycode hosts,
  unusual ports, and numeric addresses receive explanatory warnings. No local
  result claims that a site is safe or that its issuer is authentic.
- Missing/invalid hosts and ports, bad percent escapes, literal whitespace,
  hidden direction controls, and backslashes make a web candidate inert.
- Camera/gallery result presentation, history, and Saved use the same review
  widget. Opening the reviewed result requests one OS handoff.
- The iOS share result view displays the same review but retains its existing
  read-only behavior. Its service can be supplied in tests without loading
  platform assets; production still uses the bundled local suffix list.
- The router revalidates web destinations and rejects a substituted launch URI
  or an arbitrary custom-scheme action. Existing passkey confirmation remains
  separate from link review and comparison codes.
- Result metadata wraps at narrow widths/large text. Revealed Wi-Fi passwords
  become masked again when the payload changes.

No database schema, verification-code calculation, purchase entitlement, or
history-retention policy changes are included. No redirects, reputation checks,
remote previews, lookup clients, or product-provider integration are added.
Online product lookup is deferred until a provider is available and validated.

## Deterministic parser boundaries

- Duplicate Wi-Fi fields, unfinished/unsupported escapes, and malformed field
  fragments remain display-only. Literal percent signs in credentials remain
  data, not URI escape syntax.
- Contact/event components must be complete and unambiguous. Multiple cards or
  events, nested components, duplicate singleton fields, and unsupported event
  semantics do not receive an action. Valid folded/escaped text remains intact.
- Event dates/times must round-trip without normalization, and a provided end
  must be valid, not precede the start, and use the same representation type.
  Single local/UTC timed events can be handed off. Named timezones, recurrence,
  and duration-only events remain display-only. All-day dates are interpreted
  for viewing with an explicit unsupported-handoff message, avoiding conversion
  into unintended timed events.
- Location coordinates must be finite and within latitude/longitude bounds.

## Automated evidence

The recorded WP2 Flutter run passed **145 tests**, including:

- Local warning/host fixtures, malformed links, unknown schemes, and a check
  that inspection/classification never creates an HTTP client.
- Shared UI tests for camera/gallery result configurations, history, Saved,
  read-only share presentation, and a 360 × 740 logical-pixel viewport at 2.5×
  text scale. The unit version rejects HTTP clients and spies on launch requests.
- Confirmation, cancellation, barrier dismissal, substituted-URI rejection,
  sensitive-field remasking, parser ambiguity, and original verification,
  persistence, entitlement, and passkey regressions.

Later offline identifier additions are tracked in [WP3 validation](identifier_checks.md).

Commands:

```sh
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed lib test integration_test
flutter test integration_test/link_review_flow_test.dart -d <device-id> --reporter expanded
```

All **six** on-device UI cases passed on Samsung SM-G975U, Android 12 / API 31.
[Recorded cases, scope, and input hashes](evidence/android-phone-link-review.json).
Static analysis and formatting checks also pass.

External launches use a recording fake at the URL-launcher platform interface,
and inputs are synthetic result models; these
tests do not validate native capture, real browser handoff, iOS extension
delivery, or a live product service. The device runner needs its normal debug
network transport; HTTP rejection is exercised separately in the unit version.

## Remaining release evidence

- Complete M0, including the physical format/source matrix and upgrades.
- Exercise real browser/OS handoff and cancellation on Android and iOS.
- Verify first-run airplane-mode behavior and inspect release-app traffic;
  test doubles are not evidence of a physical-device network audit.
- Check TalkBack/VoiceOver navigation, long destinations, and large text on
  physical devices, including iOS Share Extension rendering/lifecycle.
- Compile/run native iOS regression tests and build provisioned release
  candidates on macOS/Xcode. No physical iOS validation is claimed here.
