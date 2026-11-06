# Offline identifier checks

**Date:** 2026-10-29<br>
**Work package:** WP3 — offline implementation; no provider-backed lookup enabled<br>
**Plan:** [Usage expansion implementation plan](../roadmap_implementation_plan.md)

## Recognition contract

`IdentifierRecognizer` separates original value/format, identifier kind,
check-digit/structure status, normalized text, and any derived value. It neither
modifies `ScannedCode` nor changes payload routing, saved values, or database
identity. Candidate recognition does not verify registration, ownership,
authenticity, a product, an edition, or a catalog match.

| Input | Local behavior |
|---|---|
| Native UPC-A, EAN-8, EAN-13 | Require their exact ASCII digit lengths and check the GS1 modulo-10 digit. Do not trim, strip zeroes, or infer a different reported symbol format. |
| Native UPC-E | Require eight digits, number system 0, and canonical zero-suppression structure. Check the expanded UPC-A value; expose a matching expansion separately. Missing digits and other number systems are not guessed. |
| ISBN-13 candidates | Recognize book-prefix candidates from EAN-13 or standalone ISBN text. Accept 978/979 candidates, excluding the 979-0 music range; check the digit without asserting registry allocation. |
| ISBN-10 candidates | Require an explicit `ISBN`, `ISBN-10`, or compatible ISBN label. Check modulo 11, including terminal X. A matching value can have a separately derived ISBN-13 value. |
| ISBN presentation | Support ASCII space/hyphen separators and lowercase terminal x. Explain each normalization separately while retaining the full original label/value. Declared ISBN-10/13 lengths must match the input. |
| Ambiguous or unsupported input | Leave bare ten-digit identifiers and other arbitrary numeric text unclassified. ITF-14 recognition and GS1 element-string/Digital Link interpretation remain outside WP3. |

UPC-A `012345678905` and zero-prefixed EAN-13 `0012345678905` retain different
original formats and derived identifier strings. No equivalence is silently
applied to history or Saved identity. UPC-E expansion and ISBN-10 conversion
are additional in-memory representations, not replacements for scanned data.
Bad check digits do not generate a repaired value or a lookup value.

## Presentation and provider boundary

Scan results, history/Saved detail sheets, and the read-only share result view
show the candidate, original value, validation outcome, and supported derived
representation. They distinguish check digits from existing QR comparison codes.
Copying contents still copies the original scan, including ISBN labels, spaces,
hyphens, leading zeroes, and lowercase check characters.

No product/book lookup action, catalog metadata, provider transport, credentials,
remote imagery, cache, persistence migration, or new entitlement is introduced.
The panels explain that online details are unavailable. Product lookup remains
deferred until an accessible provider passes the separate selection/live-trial
gate. Local checksum tests are not evidence of working online product support.

## Validation

- Thirteen domain tests cover published UPC-E examples, other expansion
  selectors, valid/invalid checks, normalization, unsupported/malformed values,
  ISBN prefix boundaries, ambiguous numeric text, and single-digit corruption.
- Existing independently generated retail barcode fixture values pass local
  identifier validation. This reuses their known decoded values; it does not
  replace physical decoding/source validation.
- Nine widget tests cover scan/gallery/share presentation, history and Saved
  data preservation, invalid values, ambiguous text, large text on a narrow
  viewport, and exact raw-value clipboard behavior. Unit tests count and reject
  unexpected HTTP clients/external launches, including caught errors.
- The WP3 implementation run passed **167 tests**. Static analysis and formatting
  checks passed. See [latest local-workflow validation](local_workflows.md) for subsequent runs.
- All **eight** Android UI cases pass on Samsung SM-G975U, Android 12 / API 31.
  [Recorded cases, scope, and source hashes](evidence/android-phone-identifier-checks.json).

```sh
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed lib test integration_test
flutter test integration_test/identifier_details_test.dart -d <device-id> --reporter expanded
```

The device harness uses synthetic decoded result models, a recording/denying
launcher implementation, and normal debug network transport for test reporting.
HTTP-client rejection is tested in the unit version. The clipboard test runs
only with a mocked platform clipboard on the host. No online provider is used.

M0 remains open: physical capture/source coverage, first-run airplane-mode and
traffic checks, upgrades/entitlements, accessibility, real OS handoff, native
iOS compilation, and physical iOS validation are still required before release.

## Rule references

- Retail check digits follow [GS1's calculation procedure](https://www.gs1uk.org/sites/default/files/how_to_calculate_your_check_digit.pdf).
- UPC-E scope, zero suppression, and example vectors follow sections 5.2.2.4.1–2
  of [GS1 General Specifications 24.0](https://ref.gs1.org/standards/genspecs/24.0.0/).
  This is a pinned implementation reference, not a claim of full specification conformance.
- ISBN prefix/format context comes from the [International ISBN Agency](https://www.isbn-international.org/content/what-isbn/10);
  historical X/modulo-11 behavior is described by [the US ISBN Agency](https://www.isbn.org/faqs_general_questions).
- The ISBN/ISMN prefix boundary is documented by the [National Parliamentary Library of Georgia](https://www.nplg.gov.ge/ecger/isn/index.htm).

Publisher/group allocation and hyphenation-range verification require additional
registry information and are intentionally not inferred by this implementation.
