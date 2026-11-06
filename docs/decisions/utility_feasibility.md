# Dynamic QR, NFC and pass feasibility

Prepared 2026-10-29. These are three independent gates. None has a named
decision owner or an approved pilot. M6 remains incomplete; no utility feature
has been enabled by this document.

## Dynamic QR (WP9)

Proposed pilot: an authenticated owner creates a managed HTTPS redirect whose
printed URL remains stable when its destination changes. Use a dedicated
owned domain, opaque nonsequential link identifiers, HTTPS-only destinations,
and a management service separated from the public resolver. A local QR alone
cannot provide mutable destinations without an online service.

Proposed implementation sequence after a go decision:

1. Select domain, hosting, identity/account recovery, service operator, support
   contact, and monthly spending ceiling. Record renewal and outage ownership.
2. Build tenant-authorized link CRUD with server-side authorization on every
   request, optimistic concurrency, rate limits, and minimal change auditing.
3. Implement resolver pause/revoke/expiry states and short bounded caching.
   Reject unsafe schemes, credentials and malformed targets. Do not fetch
   destination content or generate previews. Define abuse reporting/takedown.
4. Add management UI and QR creation only after cross-account, expiry, outage,
   revocation and quota tests pass. Display the current destination for review
   on each use; an earlier judgment cannot authenticate a mutable destination.
5. Exercise restore from backup, secret rotation, service disablement, domain
   renewal, monitoring, deletion and an operator response drill.

Suggested pilot acceptance targets for owner review: no analytics by default;
no full scanned payloads in logs; revocation visible within 60 seconds; no
fallback to an expired destination; managed-link writes fail closed during
authorization outages. These are proposed targets, not existing guarantees.

Unresolved inputs: domain/ownership, user/account model, operating owner,
budget/quota, retention/deletion rules, acceptable outage and abuse policy.
Decision: pending. No hosted resources or paid services have been created.

## NFC (WP10)

Hardware-only evidence collected with
`adb -s <device> shell pm has-feature android.hardware.nfc`:

| Device | OS | Feature reported | Physical read |
|---|---|---|---|
| Samsung SM-G975U | Android 12 / API 31 | true | Pending: no test tag/workflow supplied |
| Samsung SM-T290 | Android 11 / API 30 | false | Unsupported hardware |
| iPhone | Not available here | Unverified | Pending |

This proves reported hardware capability only, not enabled radio state,
permission handling, tag compatibility or successful reading. No device/tag
identifiers were collected.

Candidate read-only pilot: user starts a foreground NDEF session and reads a
text or HTTP/S URI record. Use the existing local interpretation and explicit
destination confirmation. Bound record/message sizes, retain original bytes
only in memory, reject malformed encodings, present unsupported records
without action, and require a new explicit session for another read. Initial
scope excludes tag writing, emulation, access/payment credentials and claiming
that a readable tag proves authenticity.

Select the actual native/plugin API only after an approved use case and tags
exist. [Android NFC basics](https://developer.android.com/develop/connectivity/nfc/nfc)
describes NDEF and tag dispatch; [Apple Core NFC](https://developer.apple.com/documentation/corenfc)
is the iOS evaluation starting point. Platform feature checks and lifecycle
behavior must be tested on supported physical devices.

Spike matrix to complete: supported phone plus NDEF text/URI, malformed and
oversized records, multiple records, non-NDEF tags, disabled NFC, unsupported
hardware, cancel/background/resume, repeated presentation, airplane mode,
and iOS session errors. Record exact hardware, OS, tag technology, outcome and
no-network behavior. Decision owner, use case, physical tags and iPhone remain
missing; no-go/go decision is pending.

## Issuer-authorized passes (WP11)

Candidate pilot: accept one issuer-authorized pass format, show issuer and
expiry context, then explicitly hand off to the supported system Wallet flow.
Scanning an arbitrary QR must not manufacture issuer status, copy rotating
credentials or imply that a recreated barcode will be accepted.

Apple Wallet issuance requires a pass type identifier and associated signing
certificate; the account owner manages those through
[Apple's Wallet identifier/certificate flow](https://developer.apple.com/help/account/capabilities/create-wallet-identifiers-and-certificates).
Google Wallet issuance needs an issuer account and its onboarding/publishing
process; [new accounts begin in demo mode](https://developers.google.com/wallet/generic/getting-started/issuer-onboarding).
These requirements do not establish that this app has issuer authorization.

Before implementation, identify the issuer, authorized use, sample pass and
test account, accepted format, expiry/revocation mechanism, offline behavior,
privacy/retention and platform accounts. Keep signing keys server-side under
issuer control. Do not embed them in the Flutter bundle.

After a go decision: validate format/signature/issuer boundaries, build inert
preview, add confirmed system handoff, then test rejection, cancellation,
expiry, revoked/updated passes, offline mode and deletion. Confirm acceptance
with the issuer's actual verifier. Authorized issuer/sample, account owner,
physical devices and decision owner are currently absent. Decision: pending.

## Decision record required for each stream

Record owner, date, evidence links, go/no-go, rationale, unresolved risks and
reconsideration conditions. A go must name the pilot operations owner, estimate,
test hardware/accounts and acceptance criteria. This preparatory document
does not substitute for those decisions.
