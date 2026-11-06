# Scanner foundation QA

**Date:** 2026-10-29<br>
**Milestone:** M0 / WP0 — in progress; release gate open<br>
**Plan:** [Usage expansion implementation plan](../roadmap_implementation_plan.md)<br>
**Build under test:** `1.2.0+2026102803`, debug test target, working tree based on
`0487c2a`; `mobile_scanner` 7.4.0

## Automated evidence

The [Android-first universal scanner report](universal_scanner.md) supersedes
the implementation status below with 13 supported formats, production fallback
tests, UI/persistence flows, and real Android SEND evidence. The original
observations are retained as historical build-specific evidence. iOS validation
is explicitly pending by user direction. The full physical capture matrix below
remains open: injected image paths do not establish optical or real-picker QA.

- Initial baseline: 124 Flutter tests passed; static analysis passed.
- After adding exact-value/source and migration assertions: 126 Flutter tests
  passed. Migration checks compare UTC instants because Drift can deserialize
  stored timestamps as local `DateTime` objects.
- All 21 committed PNGs passed independent format/value decoding with
  ZXing-C++ 2.3.0. Regeneration checks the committed image and manifest hashes.
- Samsung SM-G975U, Android 12 / API 31: all 23 native image-decoding integration
  tests passed (21 PNGs, blank image, multiple symbols with duplicate collapse).
  [Recorded observations and input hashes](evidence/android-phone-image-decode.json).
- Samsung SM-T290, Android 11 / API 30: all 23 native image-decoding integration
  tests passed. [Recorded observations and input hashes](evidence/android-tablet-image-decode.json).
- Final static analysis and Dart formatting checks passed. An existing crop
  test needed formatting normalization; its behavior is unchanged.
- Subsequent [local review work](link_review.md) expands the full Flutter suite
  to 145 passing tests; original native image-decoder evidence below is retained
  as a record of its specific build inputs.
- [Offline identifier work](identifier_checks.md) brings the suite to 167
  passing tests, with eight additional Android UI cases passing. These use
  synthetic decoded models and do not complete the capture/source matrix.

Both devices reported `ean13_upca_pair` as UPC-A `012345678905`; the generated
symbol's EAN-13 input was `0012345678905`. Other fixtures matched their manifest
format/value directly. These are observed native representations, not app-side
normalization. No iOS representation has been validated yet.

The native integration harness exercises image analysis and domain extraction,
including source assignment. It does not exercise the gallery UI, camera,
Android intent delivery, iOS Share Extension, persistence, or confirmed routing.
Its results are supporting evidence, not a completed format/source release cell.
The fixture README documents commands and representation alternatives.

## Required end-to-end format/source matrix

**Pending** means the full source workflow has not been validated. Complete a
cell only after exact native value/format, source, history/Saved behavior,
result labeling, copy, and confirmation behavior are checked on a recorded
physical device/build. Capture observed UPC-A/EAN-13 representation differences
without modifying decoded values. Repeat on minimum-supported OS versions;
the two Android devices above do not establish minimum-version coverage.

| Format | Android camera | Android gallery | Android share | iOS camera | iOS gallery | iOS share |
|---|---|---|---|---|---|---|
| QR Code | Tablet detection passed; workflow pending | Pending | SEND passed; chooser pending | Pending | Pending | Pending |
| UPC-A | Tablet detection passed; workflow pending | Pending | SEND passed; chooser pending | Pending | Pending | Pending |
| UPC-E | Tablet detection passed; workflow pending | Pending | SEND passed; chooser pending | Pending | Pending | Pending |
| EAN-8 | Tablet detection passed; workflow pending | Pending | SEND passed; chooser pending | Pending | Pending | Pending |
| EAN-13 | Tablet detection passed; workflow pending | Pending | SEND passed; chooser pending | Pending | Pending | Pending |
| Code 128 | Tablet detection passed; workflow pending | Pending | SEND passed; chooser pending | Pending | Pending | Pending |
| Code 39 | Tablet detection passed; workflow pending | Pending | SEND passed; chooser pending | Pending | Pending | Pending |
| Code 93 | Tablet detection passed; workflow pending | Pending | SEND passed; chooser pending | Pending | Pending | Pending |
| Codabar | Tablet detection passed; workflow pending | Pending | SEND passed; chooser pending | Pending | Pending | Pending |
| ITF-14 | Tablet detection passed; workflow pending | Pending | SEND passed; chooser pending | Pending | Pending | Pending |
| Data Matrix | Tablet detection passed; workflow pending | Pending | SEND passed; chooser pending | Pending | Pending | Pending |
| PDF417 | Tablet detection passed; workflow pending | Pending | SEND passed; chooser pending | Pending | Pending | Pending |
| Aztec | Tablet detection passed; workflow pending | Pending | SEND passed; chooser pending | Pending | Pending | Pending |

The Android SEND observations above cover both physical devices and all 13 formats
with real offline cold/warm MediaStore URI delivery. Third-party chooser UI is
still pending, so these are partial source cells; see the [detailed evidence](universal_scanner.md).

## Defects identified during foundation work

| ID | Finding | Change / validation status |
|---|---|---|
| QA-001 | iOS share decoding trimmed whitespace, changing the payload | Removed trimming; native regression tests added, pending macOS/Xcode execution |
| QA-002 | iOS share used substring matching, admitted unknown formats, and labeled generic Interleaved 2 of 5 as ITF-14 | Explicit typed Vision allowlist and mappings; unsupported variants rejected; native regression tests pending macOS/Xcode |
| QA-003 | iOS share result ordering depended on Vision observation order | Stable format/value ordering and exact UTF-16 deduplication; native tests include canonically equivalent but distinct strings; pending macOS/Xcode |

`SharedCodePolicy.swift` is compiled into both the extension and RunnerTests.
On macOS, use an available simulator destination to run its tests:

```sh
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=<available simulator>' \
  -only-testing:RunnerTests test
```

Build the app and extension in the provisioned release environment as well.
Native iOS compilation, native tests, and physical iOS checks are pending;
this Windows workspace cannot supply their evidence.

## Remaining release checks

| Check | Evidence required | Status |
|---|---|---|
| Full format/source workflows | Required matrix above, native result values, copy/save/history and confirmation | Pending |
| Cold/warm sharing | Photos/Gallery, Files image providers, browser, messaging; exactly-once consumption | Pending |
| Import failures and cleanup | Cancellation, malformed/oversized input, no result, interrupted share, stale temporary files | Pending |
| Data upgrade | Existing app data, Saved-only/history-only rows, settings, entitlement; physical upgrade | Pending; schema-4-to-5 automated regression passes |
| First-run offline operation | Clean install with airplane-mode decoding; no scan-triggered network activity | Pending; device decoder runs did not change connectivity settings |
| Routing and FIDO | Confirmation, cancellation, unavailable providers, expired requests, platform contacts/calendar/Wi-Fi routes | Pending physical checks; existing automated regressions pass |
| Accessibility | Large text, TalkBack/VoiceOver order and controls | Pending |
| Release candidates | Provisioned signed Android/iOS builds and device smoke tests | Pending |

## Record each manual observation

For each run, record date, app version/build and source revision, device/OS,
fixture ID/hash, capture source, native value/format, displayed result, copy and
persistence checks, explicit action/cancellation, network state, outcome, and
defect ID. Use synthetic fixtures; retain no personal scan payloads or credentials
in QA evidence. Refer to the fixture manifest for expected inputs.
