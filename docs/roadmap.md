# Dali QR — Usage Expansion Roadmap

**Status:** Proposed product direction; not a release commitment
**Platforms:** iOS and Android
**Document date:** 2026-10-29
**Source:** User-provided phases from the “Review QR Code Uses” discussion

## 1. Purpose and existing plans

Expand Dali QR from a code reader into an information assistant and, later,
a utility platform. Keep scanning useful offline and require explicit user
action before opening links, contacting services, or handing content to the OS.

This roadmap complements, rather than replaces:

- [README and supported content](../README.md)
- [Version 1.2 Improvements](next_version_improvements.md)
- [Version 1.2 Implementation Plan](1.2_implementation_plan.md)
- [Secure QR design](secure_qr.md)
- [Monetization](monetization.md)

The README already documents QR and common 1D scanning, payload classification,
confirmed OS routing, opt-in local history, and Saved functionality. The 1.2
plans mark core implementation complete with format/device QA pending.
Phase 1 therefore combines validation of that foundation with incremental
expansion; it is not a claim that all listed capabilities are new or shipped.
Product lookup, inventory workflows, and additional 2D formats remain outside
the existing 1.2 scope. No dates, prices, or new entitlements are assigned here.

## 2. What codes provide

Separate the symbol format, decoded payload, interpretation, and external data:

| Layer | What it provides | What it does not establish |
|---|---|---|
| 1D or 2D symbol | A machine-readable value, sometimes with error detection/correction | Authenticity, ownership, or safety |
| Structured payload | Instructions or fields such as a URL, contact, Wi-Fi configuration, or product identifier | Permission to execute an action |
| Identifier | A key that may match a product, book, or record | A product name, current price, or complete record without a data source |
| External lookup or resolver | Additional information from a named provider | Guaranteed correctness, availability, or freshness |
| NFC or digital pass | A separate interaction or credential workflow | Universal compatibility or authorization merely because data can be read |

Keep original decoded values and formats intact. Derived identifiers and
provider results must remain distinguishable from what the symbol contained.

## 3. Priorities and sequencing

P0 means foundation/release gate; P1 means next investment after the foundation;
P2 means a later capability requiring a validated use case and feasibility work.

| Priority | Phase | Recommended order and rationale |
|---|---|---|
| P0 | 1 — Universal scanner | Finish existing QA and safety gates; then validate additional common 2D formats. Reliable offline scanning supports every later feature. |
| P1 | 2 — Information assistant | Pilot UPC/EAN product and ISBN book lookup, extend Saved into collections, then add GS1 Digital Link interpretation/resolution. Validate coverage and provider cost before broad rollout. |
| P2 | 3 — Utility platform | Start with local batch scanning; separately evaluate dynamic QR management, NFC, and digital passes. These introduce different backend, hardware, or issuer dependencies. |

Each phase should ship in small increments. Phase 3 batch scanning can proceed
after Phase 1 without waiting for every lookup integration. Dynamic QR, NFC,
and passes require their own go/no-go decisions and are not one bundled release.

## 4. Phase 1 — Universal scanner

**Outcome:** Read common codes consistently, explain their contents, and let
the user choose the next action.

- Validate the existing QR, UPC-A/UPC-E, EAN-8/EAN-13, Code 128, Code 39,
  Code 93, Codabar, and ITF-14 allowlist across camera, gallery, and shared images.
- Evaluate Data Matrix, PDF417, and Aztec as the first additional 2D candidates.
  Assess GS1 DataBar, Micro QR, and other formats only against demonstrated use.
  Advertise only formats supported by the tested Android/iOS matrix.
- Extend intelligent interpretation through deterministic, on-device parsers:
  distinguish URLs, contact details, Wi-Fi, calendar entries, location,
  identifiers, and unknown text. Show raw content alongside the interpretation;
  uncertain results remain unclassified.
- Build on opt-in local history and Saved. Preserve existing data, format,
  source, settings, and purchase entitlements through migrations; provide
  clear deletion and retention controls.
- Provide safe link review: show the destination and scheme before opening,
  explain suspicious or ambiguous destinations, and require confirmation.
  Local checks are warnings, not a guarantee that a site is safe.

**Dependencies:** Decoding, interpretation, local history, and local link
inspection should work offline after installation. Opening a website requires
connectivity. Any future redirect expansion or reputation service is a separate,
opt-in online operation; merely displaying a result must not contact its URL.

**Exit gate:** Complete the existing 1.2 device/source matrix and release checks,
then extend fixtures for each new format. Verify airplane-mode operation,
malformed inputs, multiple symbols, accessibility, history migration, and no
automatic external action. Preserve the distinction between Secure QR
comparison/domain behavior and barcode checksums; neither proves site safety.

## 5. Phase 2 — Information assistant

**Outcome:** Turn supported identifiers into useful, attributed information
without making an account or network connection necessary for basic scanning.

| Capability | Offline behavior | Online dependency and acceptance condition |
|---|---|---|
| UPC/EAN product lookup | Decode, validate applicable check digits, and display the exact identifier; show explicitly cached results | User-triggered lookup through a selected product provider; measure regional coverage, licensing, cost, rate limits, and missing/ambiguous matches |
| ISBN book lookup | Recognize valid ISBN candidates and retain the original scan; show cached book details | A selected book metadata provider; display source, edition/format where available, and handle no match without inventing metadata |
| GS1 Digital Link | Parse supported identifiers and qualifiers locally and show the original URI | User-confirmed resolution to product/issuer resources; distinguish locally parsed fields from fetched content and review destinations before opening |
| Saved collections | Organize existing Saved items into named collections, with search, tags/notes, and local deletion | No server required for the initial version; sharing or cross-device sync would need a separate consent, conflict, and deletion design |

Document any UPC/EAN normalization used for lookup as a derived value, retaining
the original format and leading zeroes. Do not classify every numeric barcode
as a product or every EAN-13 as an ISBN. Treat provider data as attributed,
potentially incomplete information; show retrieval time and stale-cache state.

Send only the identifier needed for an explicitly requested lookup, not the
camera image or the user's history. Explain which provider receives the request.
Do not upload Wi-Fi credentials, passkey requests, contact data, or arbitrary
decoded payloads to lookup services. Keep API secrets out of the distributed app;
use a backend only where provider credentials or service terms require it.

**Exit gate:** Select providers after a representative coverage/cost trial.
Test invalid identifiers, unknown products/books, conflicting metadata, timeouts,
rate limits, airplane mode, stale cache, and deletion. Scanning and local
collections must remain usable when every provider is unavailable.

## 6. Phase 3 — Utility platform

**Outcome:** Support repeat workflows and adjacent code interactions while
keeping each capability independently useful.

| Capability | Initial scope and priority within phase | Dependencies and boundaries |
|---|---|---|
| Batch scan | First: repeated scans into a local session, explicit duplicate/count rules, review/edit, and user-triggered export | Core capture and export offline; optional enrichment online. Bound session size, support interruption recovery, and escape spreadsheet-formula content in CSV exports. |
| Dynamic QR management | Pilot: create a managed redirect, edit its destination, pause/revoke it, and show change history | Requires an authenticated management service, stable domain, online resolver, ownership checks, abuse handling, and an operating-cost plan. A printed code stays unchanged because its redirect target changes. |
| NFC | Feasibility spike, then supported tag reading; consider writing only after read workflows are proven | Depends on device hardware, OS permissions/APIs, and tag format. Local supported records can work offline; linked resources may require connectivity. Confirm before writing and never lock a tag implicitly. |
| Digital passes | Feasibility spike for saving/displaying supported issuer-provided tickets or membership passes and approved wallet handoff | Depends on pass format, issuer authorization/signing, and platform integration. Cached display may work offline; issuance, updates, redemption, or revocation may require network access. |

Dynamic QR must include destination review, account protection, authorization
for edits, audit history, rate limits, and clear behavior when a link expires or
the service is unavailable. Analytics should be optional and minimized, without
building identifiable scan histories by default. Reassess a destination on each
use: a previously reviewed redirect can change.

NFC payloads are untrusted just like scanned codes. Do not assume arbitrary
payment, access-control, or transit credentials can be read, copied, or issued.

A readable pass barcode is not proof of a valid ticket or identity. Protect
sensitive pass data and make expiry/revocation limitations clear; an offline
display cannot promise current validity. Start with authorized issuer workflows,
not copying credentials or issuing unsupported passes.

**Exit gate:** Demonstrate batch-session integrity and safe export; separately
approve a service operations/security design for dynamic QR and physical-device
compatibility plus issuer/platform requirements for NFC and passes.

## 7. Rules across all phases

- Decode locally and render payloads as inert, untrusted data. Never open, dial,
  connect, pay, write a tag, or invoke another app as a side effect of detection.
- Preserve existing confirmation-first behavior and unknown-scheme restrictions.
  Retain current sensitive-data handling, including no automatic passkey history.
- Keep raw payloads, credentials, images, and sensitive pass data out of logs,
  analytics, and crash reports. Define storage protection and backup policy
  before persisting new sensitive data.
- Make network activity purposeful and visible. Remote previews or reputation
  checks can disclose a URL and trigger tracking; consent must precede them.
- If a backend fetches arbitrary URLs, defend against private-network access,
  unsafe schemes, redirect abuse, and oversized responses.
- Preserve deletion controls, existing purchase entitlements, and local-only use.
  Any new retention, sync, analytics, or monetization policy needs a separate
  product decision and updated disclosures before launch.

## 8. Next planning decisions

1. Finish the outstanding 1.2 physical-device/release checks and choose the
   first additional 2D format based on fixtures and actual demand.
2. Select product/book lookup candidates and define success thresholds for
   coverage, latency, cost, and privacy before implementation.
3. Specify local collections and batch-session behavior using the existing
   history/Saved model, including migration and deletion semantics.
4. Create separate feasibility plans for dynamic QR operations, NFC device
   support, and issuer-authorized passes; assign owners and estimates only
   after those dependencies are understood.

Evaluate progress through fixture pass rates, successful user workflows,
provider match/error rates, offline behavior, and data-preservation checks.
Use synthetic fixtures and opt-in, non-payload diagnostics rather than collecting
users' scan contents to measure success.
