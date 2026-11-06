# Dali QR — Usage Expansion Implementation Plan

**Status:** Implementation in progress; foundation release gate remains open<br>
**Date:** 2026-10-29<br>
**Requirements:** [Usage Expansion Roadmap](roadmap.md)<br>
**Platforms:** iOS and Android<br>
**Release numbering, owners, and dates:** Assign at milestone planning; not committed here

## 1. Review and implementation baseline

The roadmap has a sound sequence: establish reliable offline capture, add
optional information services, then introduce independent utility workflows.
Its main implementation gaps are provider acceptance criteria, collection and
batch data semantics, native format parity, and operational ownership for
network services. The work packages below make those gaps explicit gates.

Repository inspection establishes the following starting point. Existing code
and test files are evidence of implementation, not evidence of device QA or a
successful test run during this planning review.

| Area | Current implementation | Planning consequence |
|---|---|---|
| Capture model | `lib/features/scan/domain/scanned_code.dart` retains value, format, source, and optional in-memory bytes | Extend this model; preserve exact payloads and stable format keys |
| Flutter decoding | `lib/features/scan/data/mobile_scanner_code_adapter.dart` has an explicit ten-format allowlist and deterministic deduplication | Add formats only after compatibility evidence; avoid changing existing selection priority |
| iOS share decoding | `ios/ShareExtension/ShareViewController.swift` separately maps native Vision symbologies | Update and test native mapping as well as Flutter; plugin support alone does not establish share support |
| Interpretation/actions | `qr_payload_classifier.dart`, `qr_payload_router.dart`, and `qr_payload_action.dart` separate classification and confirmed routing | Extend deterministic interpretation and reuse confirmation for every entry point |
| Result presentation | `ScannedCodeResultView` in `qr_scanner_page.dart` is also used by the share extension | Keep local review consistent; avoid requiring lookup services inside the extension |
| Persistence | Drift schema 5 stores format, source, Saved state, title, and note | Add migrations from schema 5; reuse notes rather than creating duplicate metadata |
| History policy | `HistoryController` supports opt-in history, Saved, and seven-day free history access | Preserve existing access and purchase behavior; the access window is not automatic deletion |
| Verification | Existing Secure QR logic is gated to QR results | Checksums and new format support must not imply authenticity or site safety |
| QA | Existing scanner, routing, history, migration, and sensitive-content tests; 1.2 device QA remains documented as pending | Close the existing release gate before claiming expanded support |

Keep [the 1.2 implementation plan](1.2_implementation_plan.md) as the foundation
release checklist. Do not repeat its completed implementation or overwrite its
release status with assumptions from this plan.

## 2. Delivery order and dependencies

Each row is a separately reviewable milestone. M0 / WP0 is **in progress**:
fixture generation, automated regression coverage, and Android native image
decoding have started. The [QA matrix](qa/scanner_matrix.md) tracks evidence and
remaining checks. M1 / WP2 local review code and automated coverage are
implemented; [WP2 validation](qa/link_review.md) tracks outstanding device/release
checks. Its release still depends on M0. WP3's offline identifier code and
read-only panels are implemented; [identifier validation](qa/identifier_checks.md)
tracks their evidence. Product lookup in M2 remains deferred; book lookup keeps
its independent provider gate. Subsequent local-workflow and scanner status is
recorded below; release gates remain open where device evidence is missing.

**Product lookup decision:** No online product-information provider is currently
available. Provider-backed product implementation, live integration testing,
and enablement are **deferred** until a provider is selected, accessible, and
validated through WP4. Product lookup actions must remain unavailable in the
app. Offline decoding and identifier validation can be tested independently;
fixture or fake-provider tests cannot establish working product support.
Book lookup and GS1 resolution retain their own independent service gates.

WP6 collections, WP7a local GS1 parsing, and WP8 local batch sessions are
implemented with host tests; see [local workflow validation](qa/local_workflows.md).
WP8 still needs real spreadsheet/share/capture checks. WP1 now implements all
three additional 2D formats and a bounded local still-image fallback; see the
[Android-first scanner status](qa/universal_scanner.md) and
[candidate evaluation history](qa/optional_formats.md). The user explicitly
requested finishing Android first and keeping iOS validation pending.
[Utility feasibility preparation](decisions/utility_feasibility.md) records the
remaining owner, service, issuer and hardware inputs; M6 is not complete.

| Milestone | Priority | Work packages | Dependency | Deliverable/release gate |
|---|---|---|---|---|
| M0 — Foundation evidence | P0 | WP0 | Existing 1.2 implementation | Complete device/source matrix and upgrade/release evidence |
| M1 — Scanner reliability and review | P0 | WP2 | M0 for release | Hardened local interpretation/link review for existing supported formats |
| M1a — Optional format expansion | P0 evaluation | WP1 | M0 for release; WP2 review applies to new results | Independently release each additional format that passes its matrix |
| M2 — Information pilot | P1 | WP3–WP5 | M1; provider gate before online pilot | Validated identifiers and explicit, attributed lookup with bounded cache |
| M3 — Local collections | P1 | WP6 | M0; independent of provider availability | Migrated Saved collections, search, tags, and existing notes |
| M4 — GS1 Digital Link | P1 | WP7a–WP7b | WP2 for local parsing; independent resolver gate for online resolution | Independently releasable local parser, then optional confirmed resolution |
| M5 — Batch scanning | P2 | WP8 | M1; no dependency on M2–M4 | Recoverable local sessions and safe export |
| M6 — Utility feasibility | P2 | WP9–WP11 feasibility only | M0; assess a candidate use case for each | Three independent go/no-go decisions; each go produces a separately scoped pilot backlog |

Provider research and collection design can begin during device QA. No research
result relaxes M0 release requirements. Batch can be prioritized immediately
after M1 if user demand warrants it. Dynamic QR, NFC, and passes are not a
combined release and are not prerequisites for batch.

M1a is optional and does not block M1, lookup, collections, GS1, or batch. If no additional
format passes evaluation, record the evidence and defer expansion; features
using the existing supported formats can still ship. GS1 remains scheduled
after lookup and collections as the preferred product order, but their provider
selection and release outcomes are not technical gates for GS1.

M6 completes when all three feasibility decisions are recorded, including
justified no-go decisions. Conditional pilots receive their own owners,
estimates, release milestones, and acceptance evidence after a go decision;
pilot implementation is outside M6.

**Protocol expansion update:** The [roadmap protocol priorities](roadmap.md#9-protocol-support-and-structured-creation-expansion)
add an independent local creation workstream after Wi-Fi. QR creation across
13 formats and Android-first Wi-Fi implementation are documented in
[generation QA](qa/barcode_generation.md) and [Wi-Fi QA](qa/wifi_join.md).
WP12 guided forms and WP13 recognition/privacy/handoff code are implemented in
the working tree; [protocol QA](qa/protocol_expansion.md) records evidence and
remaining native-prefill/provider-import checks. WP14–WP15 are explicitly
deferred by user direction on 2026-10-29. These states do not close release gates. Android remains first;
iOS validation and the existing foundation release requirements remain open.

| Milestone | Priority | Work packages | Dependency | Deliverable/release gate |
|---|---|---|---|---|
| M7 — Structured QR creation | P1 next local work | WP12 | Existing QR renderer, WP2 interpretation; M0 for release | Six guided creation types with exact decode/parse round trips and affected Android native handoff checks |
| M8 — Authenticator provisioning recognition | P1 after M7 | WP13 | WP2 and sensitive-data exclusions; no product provider | Validated local recognition and an explicitly supported authenticator handoff matrix; no secret history or implicit enrollment |
| M9 — Protocol feasibility | P2 | WP14–WP15 feasibility only | Specific device/market use cases and available platform/provider integration | Independent Matter and payment go/no-go records; any implementation receives its own pilot plan |

## 3. Foundation and universal scanner

### WP0 — Close the 1.2 release gate

1. Reconcile the outstanding checks in the README and 1.2 plan with actual
   evidence. Create `docs/qa/scanner_matrix.md` and record build, OS, device,
   source, fixture, exact decoded value/format, result, and defect reference.
2. Add independently generated fixtures and a manifest under
   `test/fixtures/barcodes/`; record generator/provenance and exact expected
   values, including leading zeroes and UPC-A/EAN-13 platform differences.
3. Execute all ten existing formats across camera, gallery, and shared images
   on physical Android/iOS devices, including minimum-supported OS coverage.
4. Exercise cold/warm shares, multiple symbols, cancellation, interruption,
   malformed images, temporary-file cleanup, and accessibility.
5. Test upgrades with existing history, Saved, settings, and an active purchase;
   exercise FIDO and OS routes from the README release checklist.
6. Verify first-run decoding in airplane mode and inspect network behavior to
   establish that merely scanning or viewing a result makes no external request.

**Done when:** Required matrix cells pass, regressions are resolved, and the
existing release checks have evidence. If a format cannot pass, explicitly
revise the support commitment before release; do not silently mark it complete.

### WP1 — Add proven 2D formats incrementally

**Depends on:** M0 for release. Evaluation can start earlier. This optional
workstream does not block M1 or features using existing formats.

1. Spike Data Matrix, PDF417, and Aztec with independent fixtures on all six
   platform/source combinations. Record capture latency and failure behavior
   against the existing allowlist on a representative mid-range device.
2. Select the first candidate using demand and measured compatibility. Record
   the supported textual payload subset and behavior for binary-only results.
   Preserve raw bytes in memory; do not silently invent text or persist bytes.
3. Append domain format values, stable keys, labels, and explicit adapter
   mappings. Preserve existing enum order and existing result priority.
4. Update native iOS Share Extension symbology mapping/filtering and transfer
   serialization. Audit native matching so unsupported lookalike symbologies
   cannot be mislabeled as a supported format.
5. Extend result, history, Saved, and fixture tests. Additional 2D formats must
   not receive QR comparison codes or fabricated QR artwork.
6. Complete the release matrix per platform before shipping. Android-first
   implementation is authorized; iOS source is staged with validation pending
   by user direction. Document decoder/source limits and remaining optical and
   real-picker checks alongside the public support list. Defer GS1 DataBar and
   Micro QR until there is a demonstrated use case.

**Done when:** Exact value/source/format round-trip correctly for every enabled
format, old formats retain their behavior, and capture performance meets a
budget recorded before the spike is evaluated.

### WP2 — Strengthen local interpretation and destination review

1. Audit the existing parsers with malformed and ambiguous fixtures. Tighten
   validation without replacing uncertain input with guessed structured data.
2. Introduce a pure local link-inspection result with warning reasons. Cover
   misleading user-info, unusual schemes, Unicode/punycode display ambiguity,
   and malformed destinations; show the full destination and scheme.
3. Reuse review and confirmation across scanner, Saved, history, and share
   results. Keep unknown schemes inert and preserve sensitive-field hiding.
4. Separate checksum validity, local URL warnings, and Secure QR comparison
   in both the domain model and UI language. None is a safety guarantee.
5. Keep previews, redirects, and reputation checks out of local inspection.

**Done when:** Parser and widget regressions cover valid/invalid payloads,
unknown schemes and confirmation cancellation; network spies and device checks
show zero requests on decode, inspection, or result display.

## 4. Information assistant

### WP3 — Typed identifiers and provenance

**Depends on:** WP2. This package works entirely offline.

**Implementation status:** Offline recognition/validation and read-only panels
are implemented. No provider-backed lookup is enabled; release still requires
the foundation and platform checks recorded in [WP3 QA](qa/identifier_checks.md).

1. Add `lib/features/lookup/domain/` for identifier recognition and validation,
   separate from OS routing. Represent identifier kind, original value/format,
   derived lookup value, validation result, and normalization explanation.
2. Implement applicable UPC/EAN and ISBN checks with fixture-driven rules.
   Handle UPC-E expansion explicitly; preserve leading zeroes and distinguish
   ISBN-eligible values from other EAN-13 identifiers. Numeric text alone must
   not become a confirmed product match.
3. Retain the original `ScannedCode` unchanged. A valid check digit only makes
   a value eligible for lookup; it does not establish a real product or book.
4. Add a result-panel entry point that explains the candidate and offers a
   lookup only for supported, validated identifier kinds with an available,
   validated provider. While product lookup is deferred, display the identifier
   locally without an enabled product-lookup action or fabricated metadata.

**Done when:** Valid, invalid, ambiguous, leading-zero, and normalization cases
have deterministic tests; no identifier recognition performs network I/O.

### WP4 — Provider selection and request contract

**Depends on:** WP3 for pilot inputs. Research may start earlier.

**Current product status:** Deferred; no provider is available for a live trial.
The [provider decision preparation](decisions/lookup_providers.md) records the
independent book candidates and missing trial inputs. Candidate research and
offline test preparation can proceed, but do not report
provider coverage, match quality, cost, or live integration success without
actual service access. Revisit product selection when a provider is available.

1. Produce `docs/decisions/lookup_providers.md` with product and book candidates,
   regional/language/edition coverage, attribution, caching/deletion rights,
   licensing, credential requirements, quotas, latency, and projected cost.
   Verify provider documentation and terms at selection time.
2. Before trial execution, record the target regions, representative sample,
   minimum correct-match rate, acceptable ambiguous/no-match rate, p95 latency
   budget, monthly request forecast and cost ceiling, and privacy requirements.
   Product and engineering owners set numeric thresholds; unset thresholds
   block selection. Report results per region/category, not only in aggregate.
3. Trial synthetic or deliberately selected identifiers without user history.
   Select product and book providers independently; either may be deferred.
4. Define a narrow `LookupProvider` interface returning typed success,
   ambiguous, not-found, timeout, rate-limited, and unavailable outcomes, with
   provider ID, attribution, retrieval time, and edition/format where available.
5. Use direct requests only if public-client credentials and terms permit.
   Otherwise design a minimal backend for validated identifiers, credential
   storage, quotas, response bounds, and redacted operational logs. It must not
   accept arbitrary URLs or raw payloads as a generic proxy.

**Done when:** The trial meets predeclared thresholds and terms/privacy/cost
review is recorded. Failure defers online lookup while local scanning ships.

### WP5 — Explicit lookup, bounded cache, and result UI

**Depends on:** WP3 and successful WP4 provider selection.

**Current product status:** Deferred. Do not implement or enable a provider-backed
product feature as part of the current offline work. Future transport/cache/UI
work below requires an accessible, selected provider and a successful live trial;
test doubles alone do not satisfy this prerequisite.

1. Add lookup application/data layers and inject providers into the main app.
   Before each requested lookup, identify the provider and the identifier to be
   sent. Never send images, history, contacts, Wi-Fi data, or passkey requests.
2. Implement idle/loading/result/ambiguous/no-match/offline/error states,
   cancellation, request deduplication, timeouts, and bounded user-triggered
   retries. Late responses must not replace a newer scan's result.
3. Render provider fields as inert data with attribution and retrieval time.
   Do not fetch cover images, thumbnails, or remote previews automatically;
   any media request needs a separately disclosed design. External links reuse
   destination review and confirmation.
4. Add a local cache keyed by identifier kind, derived value, provider, and any
   locale affecting results. Choose TTL, size cap, negative-cache behavior,
   permitted fields, and backup policy from WP4 terms before migration.
5. Show cached/stale state explicitly. Never silently refresh expired data;
   offer a deliberate refresh. Add clear-cache controls and cancellation or
   generation checks so a late response cannot repopulate a deleted cache.
6. Keep cached provider data separate from original scan records. Deleting a
   scan and clearing cache have distinct, clearly labeled behavior.

**Done when:** Fake-provider tests cover every outcome, cache eviction/expiry,
deletion races, and response parsing. With all providers unavailable, scanning,
history, Saved, and collections remain usable. No secrets ship in app assets.

### WP6 — Local Saved collections

**Implementation status:** Implemented: schema 6, multi-collection memberships, tags, search and cleanup. See [QA evidence and remaining checks](qa/local_workflows.md).

**Depends on:** M0; can be implemented independently of WP4–WP5.

Initial semantics:

- A Saved item can belong to multiple named collections; existing items remain
  visible in **All Saved**, and items without memberships appear as unfiled.
- Collections reference existing history-entry IDs, without duplicating payloads.
- Deleting a collection removes memberships only. Removing an item from one
  collection leaves it saved. Removing it from Saved removes memberships and
  preserves a history-only row when current repository semantics require it.
- Clearing history preserves Saved and its memberships. Tags and notes are
  local metadata; reuse the existing `note` field.

Tasks:

1. Add collection/membership and tag/assignment tables, foreign-key cleanup,
   unique membership constraints, and indexes. Use transactions for mutations.
2. Extend the history repository/controller with collection and tag operations;
   retain existing payload-plus-format save identity and entitlement behavior.
3. Add create/rename/delete collection, add/remove Saved item, tag editing,
   and local search over title, note, tags, format, and payload. Mask sensitive
   snippets and keep search terms out of diagnostics.
4. Add an additive Drift migration from the current schema. Choose its version
   at implementation time to avoid collisions with cache or batch migrations;
   regenerate generated code rather than editing it by hand.
5. Add upgrade and deletion tests covering Saved-only, history-only, both,
   older locked history, same value in different formats, and multiple memberships.

**Done when:** All existing fields/settings/entitlements survive upgrade;
collection operations work offline and deletion semantics pass repository/UI
tests. No sync, account, or changed retention policy is introduced.

### WP7a — GS1 Digital Link local parsing

**Implementation status:** Implemented: limited uncompressed GTIN/qualifier parser and offline panels. See [supported subset and validation](qa/local_workflows.md). Online resolution remains deferred.

**Depends on:** WP2; M0 for release. Independent of WP3–WP6 and product/book
provider selection.

1. Record the supported specification version and identifier/qualifier subset
   from authoritative documentation at implementation time. Build known-valid,
   malformed, duplicate-field, escaped, and unsupported fixtures.
2. Add a pure local parser retaining the original URI and distinguishing parsed
   fields from provider data. Treat uncertain input as an ordinary reviewed URL;
   recognition alone must not imply issuer authenticity.
3. Display supported identifiers and qualifiers offline without a resolver,
   product provider, or book provider configured.

**Done when:** Valid, malformed, ambiguous, and unsupported fixtures produce
the expected local interpretation, preserve the original URI, and generate
zero network traffic. This parser can ship while online resolution is deferred.

### WP7b — Optional GS1 Digital Link resolution

**Depends on:** WP7a and an independent resolver decision recorded in
`docs/decisions/gs1_resolution.md`. Before implementation, select the resolver
or issuer-resolution mechanism, verify its supported protocol and terms,
identify disclosed data and credential/backend needs, and set redirect,
timeout, response-size, privacy, and operating-cost limits. A product/book
provider decision in WP4 does not satisfy or block this gate. A no-go decision
defers resolution while WP7a remains usable.

1. Add an explicit resolver action that identifies the contacted service and
   information disclosed. Set redirect-hop, timeout, scheme, and response-size
   limits. Review each changed destination before contacting it; require a
   separate confirmation before final OS/browser handoff.
2. If a backend fetches destinations, block private/reserved networks, validate
   DNS and each redirect target, and defend against rebinding and oversized
   responses. Do not add arbitrary fetching to the identifier-only lookup API.
3. Keep parsed identifiers usable offline and show resolution failures/staleness
   independently. Do not automatically reuse an old redirect safety judgment.

**Done when:** Redirect, cancellation, unsafe-target, resolver-failure, and
offline tests demonstrate the boundaries. WP7a still works when resolution is
unconfigured, disabled, or unavailable.

## 5. Independent utility workstreams

### WP8 — Recoverable batch scanning and export

**Implementation status:** Implemented: protected local sessions, explicit rearm, quantity/recovery flows and confirmed CSV export. Automated checks pass; target spreadsheet imports, real camera/share interruption and iOS protection checks remain pending. See [WP8 QA](qa/local_workflows.md).

**Depends on:** M1. Enrichment and collections integration are optional follow-ups.

1. Add `lib/features/batch/` with session and item models and local persistence
   separate from opt-in automatic history. Starting a batch explicitly starts
   local recording; explain this in the flow. Exclude passkey requests and
   sensitive credential payloads from the initial batch persistence/export scope.
2. Key rows by exact `(format, value)` within a session. Initial mode keeps one
   row per key; optional count mode increments only for an intentional new
   capture after leaving/re-entering view or explicit rearm, never each frame.
   Record quantity, source, and first/last capture times.
3. Specify and test debounce/rearm rules and a finite session/item-size limit
   before implementation. Stop with a clear message at limits; never drop scans
   silently. Keep deterministic selection for simultaneous symbols in the MVP.
4. Persist accepted edits/captures transactionally; support pause, resume after
   process termination, quantity editing, row removal, review, and deletion.
   Define app-private storage, backup exclusion/protection, and temporary export
   cleanup before persisting batch data.
5. Add user-triggered CSV export with format/source/count columns and UTF-8
   quoting for delimiters, quotes, and newlines. Neutralize formula-leading
   content, including leading whitespace/control characters. Explain export
   escaping; retain exact source values in the database. Document spreadsheet
   leading-zero behavior rather than silently promising type preservation.
6. Create export files only on request, invoke the OS share sheet explicitly,
   and clean temporary exports on completion/failure and a startup sweep.

**Done when:** Repeated frames cannot inflate counts, interruption recovery
loses no committed capture, limits are enforced, deletion is durable, and CSV
fixtures remain inert when opened in target spreadsheet applications. Capture,
review, and export work in airplane mode.

### WP9 — Dynamic QR feasibility and conditional pilot

**Gate deliverable:** An architecture/operations decision covering stable domain
ownership, authentication/account recovery, tenant authorization, destination
policy, abuse response, expiration/outage behavior, minimized optional analytics,
data deletion, backup/restore, monitoring, and a funded operating-cost ceiling.

**Feasibility done when (M6):** Record the evidence, unresolved risks, and an
explicit go/no-go decision with a named decision owner. A no-go completes this
feasibility package with its rationale and any reconsideration conditions. A go
creates a separately estimated pilot backlog with an operations owner and the
acceptance criteria below.

After a go decision, implement in separate changes: authenticated managed-link
CRUD; resolver and destination validation; pause/revoke and audit history;
management UI and printed-code creation; then service operations and abuse
controls. Resolve only safe permitted schemes, authorize every edit, rate-limit
management and resolution, and review a mutable destination on each use.

**Conditional pilot accepted when:** Cross-account edits fail, pause/revoke
takes effect as specified,
audit history records changes without unnecessary payload disclosure, outage
and expiry behavior is tested, and an operator can restore and disable service.
The printed URL is stable; online resolution remains an explicit dependency.

### WP10 — NFC feasibility and conditional read-only pilot

**Gate deliverable:** A physical-device matrix of hardware, OS/permissions,
supported tag/record formats, lifecycle behavior, offline reads, and a concrete
user workflow. Select APIs/dependencies only after this spike.

**Feasibility done when (M6):** Record spike results, supported/unsupported
device and tag combinations, and an explicit go/no-go decision with a named
decision owner. A no-go completes feasibility with its rationale and any
reconsideration conditions. A go creates a separately estimated read-only pilot
backlog using the acceptance criteria below.

After a go decision, add a native adapter returning untrusted records to local
interpretation and confirmed actions. Model NFC as its own capture origin rather
than pretending it is a barcode; append any persisted origin values safely.
Test unsupported tags, denied permissions, absent hardware, cancellation, and
malformed records. Writing requires a later plan with explicit confirmation,
read-back verification, and no implicit permanent locking.

**Conditional pilot accepted when:** The declared read-only matrix passes;
no arbitrary payment,
access-control, or transit credential copying is implied or supported.

### WP11 — Issuer-authorized passes feasibility and conditional pilot

**Gate deliverable:** One authorized issuer/use case, supported pass format,
platform/wallet requirements, signature/issuer validation approach, secure
storage and backup/deletion policy, and online/offline validity limitations.

**Feasibility done when (M6):** Record issuer/platform findings and an explicit
go/no-go decision with a named decision owner. Lack of an authorized issuer or
viable integration can justify a no-go and complete feasibility; record the
reason and any reconsideration conditions. A go requires the gate deliverable
above and creates a separately estimated pilot backlog using the criteria below.

After a go decision, implement import validation, protected local storage,
supported display, explicit wallet handoff, and expiry/revocation-state UI.
Test invalid signatures, malformed/oversized input, issuer mismatch, expiry,
offline display, update failure, deletion, and unavailable wallet support.

**Conditional pilot accepted when:** Authorized issuer fixtures pass on physical
devices and the UI
distinguishes cached display from current validity. A readable barcode alone
never authenticates a ticket, membership, or person.

## 6. Validation and release practice

For each implementation change, run targeted tests first, then required checks:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

For schema changes, regenerate with `dart run build_runner build` and verify
upgrade fixtures from schema 5 and supported earlier versions, fresh installs,
transactional failure behavior, and complete field preservation. Do not plan
destructive down-migrations: disable new features while retaining readable data,
and document downgrade compatibility before any rollback release.

For native/capture changes, run Android and iOS native checks and the affected
physical-device/source matrix. Build release candidates in provisioned
environments with `flutter build appbundle --release` and
`flutter build ipa --release`; iOS compilation/signing requires macOS/Xcode.

Every milestone release requires:

- Offline and unavailable-service checks, including first-run behavior.
- Confirmation/cancellation checks and evidence that no external action occurs
  from detection, classification, result rendering, or migration.
- VoiceOver/TalkBack, large-text, and useful loading/error/empty-state checks.
- Sensitive-data logging review; no decoded payloads, credentials, images,
  pass data, or search terms in analytics/crash reports.
- Data deletion, upgrade, Saved behavior, and purchase entitlement regression.
- Documentation/disclosures matching actual support and new network activity.

Measure fixture pass rates and workflow success locally. Provider trial reports
use controlled samples and aggregate outcomes; any production diagnostics must
be opt-in and omit payloads. A new retention, sync, analytics, or monetization
policy requires a separate recorded product decision before implementation.

## 7. Initial execution backlog and decisions

Start with these reviewable changes, keeping schema and broad UI changes apart.
The sequence below is a preferred review order; only the explicit milestone
and work-package dependencies block delivery.

1. WP0 fixture manifest, QA matrix, and baseline evidence; fix discovered defects.
2. WP2 parser/link-review behavior and shared confirmation regression tests.
3. Independently, WP1 compatibility spike and format decision; implement a
   passing format's domain/native mappings, tests, and support documentation,
   or record deferral without blocking subsequent work.
4. WP3 identifier types and pure validators with no networking.
5. WP4 provider research where access permits. Product trials and WP5 product
   transport/cache/UI remain deferred until an online provider is accessible
   and validated; continue independent local work while that gate is unmet.
6. WP6 collection migration/repository, followed by collection/search UI.
7. WP7a local GS1 parser, then WP7b after its independent resolver decision.
8. WP8 batch semantics/storage, capture/recovery UI, then safe export.
9. WP9–WP11 feasibility documents and go/no-go decisions complete M6. Schedule
   each go pilot separately; a no-go needs no pilot implementation.

| Decision | Required before | Accountable role to assign | Evidence required |
|---|---|---|---|
| Existing release readiness | M0 completion | Release/QA owner | Device matrix, upgrade checks, build/test results |
| First new format and performance budget | WP1 enablement | Mobile engineering + product | Demand and six-cell compatibility results |
| Provider success thresholds and budget | WP4 trial | Product + service owner | Written numeric criteria and representative sample |
| Provider choice and credential architecture | WP5 implementation | Engineering + privacy/licensing reviewer | Trial results and verified terms |
| GS1 resolver mechanism and request boundaries | WP7b implementation | Engineering + service/privacy reviewer | Independent protocol/terms, disclosure, redirect, and cost decision |
| Collection semantics and storage limits | WP6 implementation | Product + mobile engineering | Accepted behavior above and migration design |
| Cache/storage/backup policies | New persistence | Mobile engineering + privacy reviewer | Field inventory, retention, deletion, platform behavior |
| Batch limits and duplicate/count rules | WP8 implementation | Product + mobile engineering | Workflow examples and interruption test cases |
| Service/hardware/issuer feasibility | Each utility pilot | Named operations/platform/issuer owner | Independent WP9/WP10/WP11 go/no-go record |

Estimate and assign owners per work package after its blocking decisions or
spike are complete. Release only milestones whose acceptance evidence is
recorded; unresolved providers, hardware, or issuer dependencies defer that
capability without blocking already validated local functionality.

## 8. Protocol expansion execution packages

### WP12 — Guided creation for existing payload protocols

**Status:** Implemented in the working tree; Android-first validation is recorded
in [protocol QA](qa/protocol_expansion.md). Scanning already recognizes
these payload families; the new work is guided creation and interoperability.
No online product-information provider or backend is required.

1. Extend the existing QR content-type dropdown with Contact, Event, Location,
   Email, Phone and SMS. Preserve QR/Text or link defaults, the existing Wi-Fi
   form, barcode-format selection, QR customization and purchase behavior.
   Show structured forms only for QR; keep other formats' current validation.
2. Implement typed, local payload builders using each protocol's escaping and
   encoding rules. Reuse the existing QR render, exact-PNG validation, preview,
   share and explicit Save pipeline. Apply current history/privacy policies.
3. Deliver Contact and Event first, then Location and communication forms.
   Keep each change independently reviewable:

| Type | Initial inputs | Generated behavior and scope |
|---|---|---|
| Contact | Name, phone and email | vCard matching fields consumed by the existing parser; review before adding a native contact |
| Event | Title, start/end, optional location and description | One timed VEVENT in supported local or UTC representation; no recurrence, named timezone or all-day handoff expansion |
| Location | Latitude and longitude | `geo:` coordinates; enforce latitude −90…90 and longitude −180…180; no remote address search |
| Email | Recipient, optional subject and body | `mailto:` with correct component encoding; opening a composer never means sent |
| Phone | Number | `tel:` reviewed dialer handoff; never place a call from detection |
| SMS | Recipient and optional message | `sms:` with platform-tested message encoding; review composer before sending |

4. Verify required fields, malformed inputs, UTF-8, reserved characters,
   multiline text and size limits. Check date ordering and coordinate bounds.
   Avoid silent loss or substitution of characters and fields.
5. Exercise generated PNG → decoded payload → existing classifier → native
   review/handoff on Android. Include cancellation, absent handlers, offline
   generation, explicit Save, large text and existing Create flow regressions.

**Done when:** All six forms pass exact payload and interpreted-field checks,
affected Android native handoffs have evidence, and documentation distinguishes
implemented Android behavior from pending iOS validation. M0 still gates release.

### WP13 — Authenticator provisioning recognition and handoff

**Status:** Recognition, masking, persistence exclusions and confirmed handoff
are implemented. Android capability/cancellation checks pass; actual provider
import remains pending. See [protocol QA](qa/protocol_expansion.md). This is not
a built-in authenticator project.

1. Add a dedicated `otpauth:` parser for TOTP/HOTP using the
   [provisioning format](https://github.com/google/google-authenticator/wiki/Key-Uri-Format).
   Validate the secret encoding, type, issuer/account fields, algorithms,
   digits and applicable period/counter. Reject ambiguous or malformed
   parameters; do not silently turn an unsupported profile into a supported one.
2. Treat valid and malformed provisioning-like content as sensitive. Mask
   secrets and raw payloads by default; exclude them from automatic history,
   Saved, batch persistence/export, logs and telemetry. Review inbound image
   cleanup, share-extension presentation and accessibility labels as well.
3. Show issuer/account details and require a separate confirmation before
   handing off. Allowlist this route without enabling arbitrary custom URI
   schemes. Verify supported authenticator apps and OS versions; when no
   compatible handler exists, retain a local explanation with no automatic launch.
4. Test parsing, secret masking, persistence exclusions, duplicate actions,
   cancellation and provider absence with synthetic credentials. Record actual
   provider/device evidence; successful handoff is not proof of account setup.

**Done when:** Declared profiles pass local validation and privacy checks, and
at least one declared Android provider/device handoff is verified. Other
providers and iOS remain explicitly pending until tested. No OTP generation,
secret-bearing QR export or third-party account enrollment is implied; those
need a separate product/storage design.

### WP14 — Matter setup recognition feasibility

**Status:** Findings documented; pilot deferred by user direction, 2026-10-29.
See [protocol feasibility](decisions/protocol_feasibility.md).

Record supported setup payload versions, a real test device/use case, available
Android/iOS commissioner APIs, permission and provider requirements, and the
handling of sensitive setup credentials. Use the
[Matter commissioning overview](https://csa-iot.org/all-solutions/matter/matter-faq/)
as a starting reference; verify concrete APIs before selecting an implementation.

**Feasibility done when:** An explicit go/no-go record identifies tested hardware,
platform constraints and a scoped recognition/handoff pilot. A go requires
physical-device pairing and cancellation evidence before claiming support.
Do not generate arbitrary replacement setup credentials or claim that parsing
a QR commissioned a device.

### WP15 — Payment QR review and wallet handoff feasibility

**Package planning update, 2026-10-30:** The user requested a separate Payments
management package and independent unlock purchase. See the
[Payments Package proposal](payments_package.md) for scope, entitlements and
delivery stages. PAY1 local workspace is implemented: profiles,
templates, sample exploration, protected storage and exact-link QR/card export
are implemented behind an independent entitlement. Production purchases and
provider integrations remain disabled; pilot/store-validation gates stay open.

**Status:** Findings documented; pilot deferred by user direction, 2026-10-29.
See [protocol feasibility](decisions/protocol_feasibility.md).

Choose one market, payment system and wallet integration before implementing
provider-specific support. The local PAY1 workspace does not enable a provider.
Evaluate the relevant [EMV QR specification](https://www.emvco.com/emv-technologies/qr-codes/),
field validation, supported extensions, wallet routing, provider/network access,
terms and legitimate test fixtures. Decide how recipient, amount, currency and
unverified merchant data appear before any confirmed handoff.

**Feasibility done when:** A go/no-go record and named integration identify a
testable pilot. A go produces separate acceptance checks for malformed codes,
amount/currency differences, absent wallets, cancellation and outcome reporting.
Local decoding must not initiate payment. A checksum, readable merchant label
or opened wallet is not proof of recipient identity or a completed transfer.
No generic payment processing or arbitrary merchant-code issuance is included.
