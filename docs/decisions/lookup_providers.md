# Lookup provider gate (WP4)

Date: 2026-10-29. No provider is selected or integrated. No live coverage,
latency, price or match-quality trial has been completed. This is preparation
for a decision, not approval to enable lookup.

## Product information

Deferred by the project owner: no online product-information provider is
available. Product lookup remains disabled. Offline UPC/EAN/ISBN validation
does not substitute for provider-backed product support. Revisit only when
the owner supplies an accessible candidate and the trial inputs below.

## Independent book candidates

These are documentation-reviewed candidates, not recommendations or evidence
of adequate coverage for this app. No app/user history was sent to them.

| Candidate | Documented capability | Selection constraints still open |
|---|---|---|
| Open Library | Public catalog APIs include book search and work/edition retrieval; its developer documentation asks frequent clients to identify the application and a contact through User-Agent | Measure ISBN/edition correctness and target language/region coverage; review endpoint-specific rate limits, attribution, caching and deletion terms; name an operational contact |
| Google Books | Volume search/retrieval; public requests identify the application using an API key or OAuth token | Obtain a project/key owner, verify applicable quota and spending limits, measure edition/region coverage, approve attribution/cache/privacy handling and the app's monetization compatibility |

Open Library's [API documentation](https://openlibrary.org/developers/api)
and [catalog-data FAQ](https://openlibrary.org/help/faq/using) are the starting
references. Its catalog-data description must not be assumed to license cover
images, third-party excerpts or every API response field. Initial pilot scope
should exclude remote images and previews until those rights are reviewed.

Google's [API guide](https://developers.google.com/books/docs/v1/using) documents
request identification and volume operations. Its published
[Books API terms](https://developers.google.com/books/terms) contain a restriction
on charging application users without an agreement or written permission.
This app offers a paid customization entitlement, so the owner must resolve
the applicability before selecting this service. No compatibility conclusion
or permission is assumed here.

## Inputs required before any live trial

| Input | Current value |
|---|---|
| Product / engineering decision owners | Unassigned |
| Target regions and languages | Unspecified |
| Representative, independently labeled ISBN/edition sample | Not supplied |
| Minimum correct-match rate, by region/language/edition | Unset |
| Maximum wrong-match and ambiguous/no-match rates | Unset |
| p95 latency budget and timeout | Unset |
| Monthly request forecast and funded cost ceiling | Unset |
| Allowed disclosure, retention/cache TTL and deletion requirements | Unset |
| Attribution, commercial use and media rights approval | Unresolved |
| API account/key owner or public-client approval | Unassigned |

Use a deliberately selected sample, never user history. Include older and
newer editions, ISBN-10/13 equivalence, translated/local editions, multi-volume
works, ambiguous records and valid-checksum no-matches. Verify returned ISBNs
and edition/format against independent ground truth. Report wrong matches
separately from missing results and separate all regional/category cohorts.
Predeclare thresholds before measuring; unmet or unset gates defer selection.

## Request contract to finalize after selection

Inputs are supported, validated identifiers and identifier kind, never raw
payloads, arbitrary URLs, images or history. Results distinguish success,
ambiguous, not found, timeout, rate-limited and unavailable. Each success must
retain provider ID, attribution, retrieval time, source identifiers and
edition/format where known. Provider fields render as inert text.

An explicit action must identify the service and identifier being disclosed.
Transport limits, retries, cache TTL/size, cancellation/generation checks and
deletion races must be validated before enablement. Select direct access only
when public-client credentials and terms permit; otherwise keep credentials
in a narrow identifier-only backend. No provider, transport or cache has been
added under this preparatory decision.
