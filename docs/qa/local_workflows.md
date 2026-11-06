# Local collections, GS1 fields, and batch sessions

Date: 2026-10-29. Implementation and automated validation are available;
the foundation release gate remains open. No online product provider is enabled.

The counts and hashes below describe the earlier local-workflow snapshot.
The subsequent [universal scanner report](universal_scanner.md) records the
current full host suite and Android scanner validation. Historical optional
format failures below were repaired by the local still-image fallback.

## Saved collections (WP6)

History schema 6 adds collections, memberships, tags, and tag assignments to
schema 5. Existing notes, payload/format identity, history access, Saved state,
and entitlement behavior are retained. Generated Drift code was regenerated.

All Saved and Unfiled filters, multiple memberships, collection creation,
rename/deletion, tags, and search work locally. Collection deletion removes
memberships without deleting Saved items. Unsaving removes organization even
if a history-only row remains. Clearing history preserves Saved organization.
Known sensitive payloads are masked in lists and excluded from raw-value search.
Names are case-insensitively unique. Limits: 100 collections; collection names
1–60 characters; 20 tags per item, each 1–40 characters without commas.

Seven repository tests cover migration, rollback, cleanup, preservation and
disk reopening. Three widget flows cover organization/search/deletion and
credential masking. Real upgrade/entitlement and iOS checks remain pending.

## GS1 Digital Link local subset (WP7a)

Pinned reference: [GS1 URI Syntax 1.7.0](https://ref.gs1.org/standards/digital-link/uri-syntax/1.7.0/),
sections 4.2, 4.5–4.10. This is a limited interpreter, not full conformance.

Supported: uncompressed HTTP/S links with AI 01 as exactly 14 ASCII digits
and a matching check digit; optional AI 22, 10, 21 path qualifiers in that order,
each 1–20 decoded XCHAR characters; optional query AI 17 as raw YYMMDD.
An optional simple alphanumeric/underscore/hyphen prefix path and trailing
slash are accepted. Percent escapes decode once. The original URI remains
unchanged. Expiry fields receive basic calendar checks; DD=00 is retained,
and no century, product usability, or current expiry status is inferred.

Duplicate/out-of-order/unknown AIs, legacy short GTINs/convenience names,
compressed identifiers, credentials, fragments, dot segments, unsupported
prefix characters, and malformed data fall back to ordinary URL review.
No issuer, allocation, product, or authenticity claim follows recognition.
Fields appear in scan, History, Saved and read-only share results. Opening a
link still requires destination confirmation. Resolution has no action or
network client. See the [independent resolver decision](../decisions/gs1_resolution.md).

Five parser tests cover exact values, escaped fields, boundaries and invalid
inputs. Five UI flows cover camera/gallery result models, read-only share,
History and Saved; host tests reject all HTTP-client creation and external
launches. This is presentation coverage, not physical capture coverage.

## Batch sessions (WP8)

From Scan, choose Batch sessions. Creating a session explicitly starts local
recording, independently of automatic history. Scan next opens one capture;
returning to the session rearms it. Live frames never increment counts.
Unique mode ignores exact `(format, value)` repeats; count mode adds one per
accepted capture. First source and first/last timestamps remain available.
Values are inert on review. Quantities can be edited, rows removed, sessions
paused/resumed/deleted. Successful transactions survive reopening.

Bounds: 50 sessions, 1,000 distinct rows per session, 4,096 UTF-8 bytes per
value, 1 MiB total raw value bytes per session, quantities 1–999,999. Rejected
captures report a reason. Existing rows remain intact when limits are reached.
Known Wi-Fi/passkey/contact/calendar/message/telephone/credentialed-URL
payloads are rejected before storage. Arbitrary text can still contain private
information; creation explains the local retention rule.

The separate `batch.sqlite` store is app-private. Android uses
`Context.noBackupFilesDir/dali_batch`; iOS uses Application Support/DaliBatch
with backup exclusion, file protection until first unlock, and file mode 0600.
There is no fallback to an unprotected location. SQLite foreign keys and
secure_delete are enabled. Deletion is logical/SQLite cleanup, not a promise
of forensic erasure on flash storage. iOS protection requires native validation.

CSV export is explicit and confirmed. All cells are quoted, embedded quotes
escaped, and files use UTF-8 BOM plus CRLF records. Formula-like leading values
(including whitespace/control prefixes and common fullwidth triggers) receive
an apostrophe plus tab prefix. Exported text may differ from the exact database
value. Spreadsheet imports can coerce leading zeroes; re-saving may remove
text protections. This follows the risk described by [OWASP CSV Injection](https://community.owasp.org/attacks/CSV_Injection)
and does not establish universal spreadsheet safety.

Export source files are removed when sharing completes or fails. A startup
sweep removes owned CSVs older than 24 hours in the app export folder and
Android share-plugin cache; recipient copies are outside app control.

Thirteen repository/export tests cover deduplication, quantities, sensitive
rejection, limits, disk reopening, unknown stored keys, quoting and cleanup.
Two scanner-event tests flood capture events while pause completes or fails,
proving exactly-once return without an automatic history write. Four widget
flows cover rapid taps/rearm, resume, rejection and 250% text on a
360-pixel viewport. Target Excel/LibreOffice imports, real share-sheet handoff,
process termination during camera capture, and airplane-mode capture/export
remain pending. Spreadsheet software is unavailable in this workspace.

## Current automated evidence

The full host Flutter suite passes **206 tests**. This includes previous
scanner, routing, migration, identifier and entitlement regressions.
All **13 device workflow cases pass on each of two Android devices** (26
checks): [SM-G975U / Android 12](evidence/android-phone-local-workflows.json)
and [SM-T290 / Android 11](evidence/android-tablet-local-workflows.json).
The records include scope, remaining checks, and source hashes. Static analysis
and formatting checks pass. The two scanner-event mock tests remain host-only;
they use a controlled fake camera rather than the live Android test binding.

Run host tests before device tests, sequentially on Windows:

```text
flutter analyze
flutter test
flutter test integration_test/local_workflows_test.dart -d <device-id>
```

The device harness uses synthetic capture callbacks for batch UI, in-memory
collections, and a separate native-path disk reopen check. It does not use the
real camera, picker, spreadsheet, or share sheet. Debug test transport remains
enabled; HTTP rejection is verified only in the host test variant.

## Manual checks needed to close these feature gates

Record device/OS, build, steps and observed results for each row. Keep failures
open rather than assuming that the automated harness covers these workflows.

| Check | Procedure | Status |
|---|---|---|
| Existing-user upgrade | Install over a previous build with history-only, Saved-only, mixed and older locked entries; verify values, notes, timestamps, collections and entitlement behavior | Pending |
| Real batch capture | In airplane mode create unique/count sessions; keep one code in view, return, then explicitly Scan next; verify one count per accepted capture and separate automatic history behavior | Pending |
| Process termination | Commit captures and quantity changes; terminate the test app while the capture screen is open; reopen and verify the committed session without an extra count | Pending |
| Real export | Cancel and complete the system share sheet; inspect UTF-8 CSV values, quantity/source/time columns and temporary-file cleanup on Android and iPad | Pending |
| Spreadsheet import | Import harmless values `00123`, `=1+1`, ` +1`, quotes, commas and newlines in the intended Excel/LibreOffice versions; formulas must remain inert, transformations and leading-zero coercion recorded | Pending |
| iOS native build | Compile Runner and ShareExtension; run RunnerTests and the integration target; verify private directory backup exclusion and file protection | Pending: macOS/Xcode unavailable |
| Foundation sources | Complete the camera/gallery/share and confirmed routing matrix in [scanner foundation QA](scanner_matrix.md) on Android and iOS | Pending |

These checks require physical interaction, target spreadsheet applications or
a macOS/iOS environment that this Windows workspace cannot provide.
