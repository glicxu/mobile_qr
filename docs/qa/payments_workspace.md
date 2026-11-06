# Payments local workspace validation

Date: 2026-10-30. Android first; iOS build/device validation remains pending.

## Implemented scope

The Payments tab and Settings entry open an independent package workspace.
Production uses `UnconfiguredPaymentsEntitlement`: there is no registered product,
hardcoded price, purchase call, restore call or implicit Customization unlock.
Sample exploration uses an in-memory database and a fixed example.com link;
changes disappear on exit and sample image/data exports are blocked.

The owned path implements profiles, exact-link template snapshots, Draft/Ready/
Archived state, editing, explicit profile-link refresh, duplication, preview,
QR copying and payment-card sharing. Ready requires decoding the generated QR
and full card back to the original link. Profile edits and template label edits
do not retarget snapshots; selecting an updated link resets a template to Draft.
No local state claims a payment succeeded or that archiving disables a provider.

Profiles/templates persist in a separate schema-v1 SQLite database under
Android noBackupFilesDir/dali_payments/payments.sqlite. The native iOS bridge
uses a protected, backup-excluded DaliPayments directory; this is staged source,
not validated iOS support. History/Saved database schemas are unchanged by this
module. Records remain viewable, exportable as versioned JSON and deletable
after entitlement loss; JSON import/recovery is not implemented. Database reopen
is tested. Deleting a profile with dependent templates is rejected.

Links are bounded opaque HTTPS URLs without credentials/custom ports/local
hosts/IP literals; stored/generated URLs are never normalized or fetched.
There are no provider adapters, amount changes, merchant identity verification,
external checkout calls, financial status synchronization or real charges here.
Existing free URL scanning/review and ordinary QR creation remain available.

## Verification

Host tests cover ownership separation, locked/unconfigured/sample behavior,
profile/template workflows, exact QR payloads, snapshot preservation and explicit
refresh, archive/restore, duplicate, storage reopen, deletion and revocation.
The app-level ownership checks cover Neither, Custom only, Payments only and Both.
This tests independent UI/feature gates, not store receipt validation.

Native QA uses `integration_test/payments_workspace_test.dart` through
`tool/qa_payments.py`. Before testing, the wrapper prebuilds and verifies the
QA APK identity, passes Flutter `--no-uninstall`, records normal/production
package presence, and explicitly removes only com.dalifin.qr.scannerqa.
Synthetic example.com links and test-only entitlement injection are used.
No real store purchase, provider account or checkout is invoked.

Native cases verify the separate no-backup storage bridge, close/reopen with
profile/template persistence, link snapshots, Ready validation, and exact decoding
of both the plain QR and complete card using Android ML Kit directly, without
the fallback decoder masking native failures. Revocation blocks premium image
export while record export/deletion remains possible. The sample is isolated.

Completed results:

- `flutter analyze`: no issues.
- `flutter test`: 318 host tests passed, including the ownership matrix.
- SM-T290, Android 11/API 30: native persistence and both image decodes passed.
  [Tablet evidence](evidence/payments-native-tablet.json).
- SM-G975U, Android 12/API 31: the same native cases passed.
  [Phone evidence](evidence/payments-native-phone.json).
- Release and normal debug APK builds passed; package identities verified.
- Both devices received the normal debug update using install -r. Installed APK
  hashes match the final build, and existing protected packages remained present.
- Normal tablet UI: Payments entry and in-memory sample workspace verified;
  the tablet is left on the sample workspace.
- Both wrappers removed only the disposable QA package and confirmed existing
  normal/production package presence was preserved.

Final build/install evidence is recorded in
[validation evidence](evidence/payments-validation.json). Native card
preview images in .dart_tool are synthetic and excluded from source control.

## Remaining gates

PAY2 still needs the commercial model, actual platform products, receipt/
ownership validation, purchase/restore lifecycle and billing sandbox tests.
PAY3 needs a selected provider/market and official test fixtures. PAY4 store
release/signing review and all iOS validation remain pending. The normal debug
app exposes the sample; production paid management remains locked.
