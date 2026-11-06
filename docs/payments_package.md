# Dali QR — Payments Package

**Date:** 2026-10-30<br>
**Status:** Hidden from all users as of 2026-11-06 pending further work and planning; PAY1 implementation retained, purchases and provider integrations disabled<br>
**User decision:** Payments is a separate package with its own management and unlock purchase<br>
**Platforms:** Android first; iOS requires its own build, billing and device validation

## 1. Package boundary

Payments is an optional Dali QR add-on with a dedicated management workspace
and an independent purchase entitlement. It is separate from the existing
Customization lifetime unlock, free scanner, basic QR creation, and ordinary
History/Saved features. The bank, wallet or checkout provider authorizes and
processes the underlying payment.

This document owns the payments product proposal. It complements the
[monetization plan](monetization.md), [usage roadmap](roadmap.md),
[implementation plan](roadmap_implementation_plan.md) and earlier
[protocol feasibility findings](decisions/protocol_feasibility.md).
The user authorized the local foundation on 2026-10-30. The independent Payments
workspace is implemented with in-memory sample exploration, protected local
profiles/templates, exact-link QR/card rendering and separate entitlement gates.
Production ownership remains unconfigured: real management/image exports and
purchase/restore are disabled until PAY2 is implemented with verified store
products. Existing records remain viewable, deletable and exportable as JSON.
No provider is represented as integrated; PAY0 commercial/provider decisions,
PAY2 billing and PAY3 provider pilots remain open.
Matter remains deferred. See [PAY1 implementation and validation](qa/payments_workspace.md).

| Decision | State |
|---|---|
| Separate Payments package | Confirmed by the user |
| Separate management workspace | Confirmed by the user |
| Separate unlock purchase | Confirmed by the user |
| One-time, non-consumable local-tools unlock | Recommended initial model; confirm before store configuration |
| Free scanning/review and ordinary payment-link QR creation | Recommended to preserve the existing free-core policy |
| Initial provider, market, price, store SKUs and launch date | Open |
| Payment processing, custody or a hosted Dali payment service | Outside the initial proposal |

## 2. Who it serves

| User/workflow | Payments package value |
|---|---|
| Market vendor or small shop | Keep checkout links organized and produce reusable payment signs |
| Freelancer or service provider | Maintain service/deposit templates and import provider-issued invoice links |
| Creator, performer or community organization | Manage tip/donation links and reusable display cards |
| Event organizer | Create labeled checkout QR cards from an existing ticket/payment provider |
| Customer scanning a code | Review the destination and continue to the payment provider without buying the management package |

Separate reusable requests from individual invoices. A reusable tip/product
link can serve many customers. A customer-specific invoice may carry private
references, expiry and a fixed amount; these properties belong to its provider.

## 3. Recommended first release

Start with provider-issued HTTPS checkout links, with Stripe Payment Links,
PayPal Payment Links and Square Payment Links as candidates. Select a small,
explicitly tested provider/market matrix rather than promising all wallets.
These services offer hosted checkout or shareable payment-link/QR workflows:
[Stripe](https://docs.stripe.com/payment-links),
[PayPal](https://developer.paypal.com/payment-links-buttons/overview/),
[Square](https://squareup.com/help/us/en/article/6692-get-started-with-square-checkout-links).

The initial flow is:

1. A merchant obtains an official link from their existing provider account.
2. They open Payments, create a named profile and add that link.
3. Dali QR reviews its destination and generates an exact-payload QR preview.
4. The merchant saves a payment template and exports/shares a display card.
5. A payer scans the QR, reviews the destination and confirms opening checkout.
6. The provider presents current recipient/amount details and obtains approval.

Dali QR does not register merchants, invent payment accounts, accept card
details or move funds in this version. Importing an existing checkout link
does not need a Dali payment backend. API-created links, OAuth connections,
payment-status synchronization and webhooks are later integrations.

Regional formats such as UPI/Pix, SEPA invoice QR, EMV merchant payloads and
crypto-wallet requests remain separate adapter candidates. Each needs a
selected use case, format, provider and native interoperability evidence.
Do not expose an unsupported format in Create merely because text can be
encoded into a QR.

## 4. Separate Payments management

Provide a dedicated Payments destination, reachable from navigation and
Settings. Its final tab placement can follow a UI review. Payments management
has its own profiles, templates, archive and purchase/settings screens; it is
not another filter in ordinary scan History or Saved.

Recommended initial screens:

- **Overview:** payment profiles and reusable templates, with clear empty states.
- **Profiles:** a local display name, provider, official link and optional notes.
- **Create request/template:** choose a profile, give the template a label,
  review the exact destination and generate a QR/display card.
- **Template details:** preview, share/export, duplicate, edit and archive.
- **Settings and access:** package ownership, localized purchase price, restore,
  provider availability, local data export/deletion and help.

Management rules:

- A locally entered business/payee label is not a verified merchant identity.
- Preserve the official link exactly. An adapter may add amount, currency or
  reference parameters only when that provider documents and supports them.
  Otherwise these inputs stay unavailable; a printed caption does not set a charge.
- Editing a local template changes future exports. It does not change a QR
  already printed or shared. A mutable destination would require a separately
  scoped managed-link service.
- Archiving/deleting a local record does not deactivate its provider link or
  cancel an invoice. Direct the merchant to the provider for those actions.
- Initial local states are Draft, Ready and Archived. They describe template
  management, not whether money was received or a provider link is still valid.
- Do not display Paid, Refunded, live scan counts or settlement reports without
  an integration that can establish those facts. Later manual annotations must
  be labeled separately from provider-confirmed transaction state.

## 5. Free core and paid package

The paid value is payment-specific management and workflow. Basic QR encoding
and safe scanning remain useful to everyone, including customers receiving
codes from merchants who own the package.

| Capability | Free core | Payments unlock |
|---|---|---|
| Scan supported payment codes and review available fields/destination | Yes, once the protocol is supported | No purchase required |
| Confirm opening a supported checkout/wallet/bank route | Yes | No purchase required |
| Paste a payment URL into the ordinary Text or link QR creator | Yes | No purchase required |
| Existing Contact/Event/Location/Email/Phone/SMS/Wi-Fi creation | Unchanged | No purchase required |
| Dedicated payment profiles, reusable templates and management | Preview/sample workspace only | Full access |
| Payment-specific creation workflow and template duplication | Preview with sample data | Full access |
| Payment display-card layouts and managed-template export/share | Preview | Full access |
| Plain QR export through the ordinary creator | Yes | Unchanged |
| User-supplied custom center emblem | Existing Customization entitlement | Not automatically included |
| Older ordinary History access | Existing Customization entitlement | Not automatically included |

Payments must be independently useful without buying Customization. Its
standard QR/card exports are included in its own unlock; existing free Dali
and plain QR styles remain available. A custom center emblem continues to
follow the existing customization policy unless a future bundle explicitly
includes that entitlement. Identify this before users choose a custom option.

Do not move existing free functions behind the new purchase. Existing
Customization owners retain their current benefits; ownership of either
package does not silently unlock or revoke the other. A future combined bundle
needs a separately declared entitlement mapping and upgrade policy.

## 6. Independent unlock purchase

Recommended first model: one non-consumable Payments unlock for local
management tools. The price and exact scope must be confirmed before sale.
No new subscription, transaction commission, per-provider SKU or QR quota is
introduced by this proposal. Ongoing hosted services would need their own
cost/entitlement decision; do not imply that a local lifetime unlock includes
unlimited future hosting or payment processing.

Use a distinct logical entitlement, for example `payments_lifetime`. Actual
App Store/Google Play product IDs are **TBD and not registered**. Do not reuse
the current customization product identifiers or preference keys. Preserve
all existing recognized/legacy customization IDs and restoration behavior.

| Ownership | Customization features | Payments management |
|---|---|---|
| Neither | Free core only | Preview |
| Customization only | Existing customization/history benefits | Preview |
| Payments only | Free QR appearance/history rules | Unlocked |
| Both | Existing customization/history benefits | Unlocked |

Purchase experience:

1. Explain exactly which Payments functions unlock and which provider accounts
   the user still needs. A payer does not need this purchase.
2. Query the store for the current product and localized price. If unavailable,
   offer retry/restore rather than a guessed price or successful unlock.
3. Use the store confirmation flow. Pending or cancelled purchases do not unlock.
4. Validate ownership and grant only the matching Payments entitlement; finish
   platform transaction processing using the supported billing integration.
5. Offer Restore Purchases and a visible ownership state in Payments settings.

Keep the Dali package purchase and a merchant payment visually distinct.
Buying Payments must never open a merchant checkout, and returning from a
merchant checkout must never grant a Dali entitlement.

## 7. Purchase architecture and lifecycle

Use an independent Payments entitlement interface/controller. Shared billing
infrastructure may dispatch validated transactions by product ID to separate
entitlement states. A generic successful purchase event must not unlock every
package or cause competing handlers to complete the same transaction.

Model at least Locked, Purchasing/Pending, Owned, Restoring and Error states.
Track provider availability separately from ownership: a provider outage does
not mean the user needs to purchase again.

- Cache previously verified ownership for offline local use. A fresh unknown
  installation must not gain ownership from an unverified preference value.
- A transient store/network error must not erase established ownership or data.
- A verified refund/revocation changes premium access according to the declared
  policy, while retaining read/delete access to existing local records and a
  route to export the user's original data. Do not silently delete templates.
- Printed/shared QR codes continue to resolve to their original provider
  destination independently of Dali package ownership.
- Restoration follows the applicable store account and product. Cross-store
  Android/iOS ownership portability is not an initial promise; an account-based
  entitlement service would require a separate design.
- Existing development/TestFlight unlocks must not grant Payments implicitly.
  Any Payments test override must be separately scoped and absent from production.

## 8. Storage and module boundaries

Implemented code boundary: `lib/features/payments/`, with domain models, provider
adapters, management UI and its own repository. Share the existing QR renderer,
decoder, destination review and billing transport through defined interfaces.
Do not overload `CustomizationEntitlement` to represent Payments ownership.

Initial local records can include profile/template IDs, display label,
provider key, exact link, layout choice, timestamps and archive state. Keep
these independent of the ordinary History retention/paywall. Database changes
need non-destructive migration and rollback/disable behavior that preserves data.

Provider adapters declare supported hosts/payload versions, field validation,
documented creation parameters and handoff behavior. An unsupported provider
uses ordinary safe URL review where applicable; it must not receive invented
payment parameters or a claimed integration status.

Do not collect card details, bank login credentials, wallet seeds or private
keys. Treat invoice links and financial references as potentially sensitive:
keep them out of logs, analytics and store purchase metadata, and define backup,
export and deletion behavior before persistence. Future OAuth/API credentials
need appropriate protected storage and revocation; private provider API keys
must not ship inside the app.

No scan tracking, transaction synchronization, Dali account requirement or
remote payment-data storage is introduced by the local package alone.

## 9. Payment review and store boundaries

Require an explicit action before opening checkout. Show the actual destination
and any locally available payment fields. Provider recognition or a QR checksum
does not verify the intended recipient. The payer confirms recipient, amount
and currency in the provider's authoritative interface.

Only report Provider opened/Checkout opened after a handoff. A return URL,
resumed app, screenshot or client callback alone is not proof of payment.
Verified status needs a separately scoped provider-authenticated integration.

The Payments unlock sells digital app functionality; merchant payments are
different transactions. Design billing for the applicable store/distribution
rules and approved regional exceptions. Do not use a generic payment-link
feature to bypass billing rules for Dali's own digital unlocks. Merchant use
cases also need review based on what is sold and where it is consumed.
Policy references, checked 2026-10-30:
[Apple App Review Guidelines, section 3.1](https://developer.apple.com/app-store/review/guidelines/),
[Google Play Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en).

## 10. Delivery and acceptance gates

| Stage | Deliverable | Acceptance evidence |
|---|---|---|
| PAY0 — Scope | Select initial market/providers, free/paid boundary, purchase model, price and store IDs | Recorded product decisions; no provider or SKU represented as live prematurely |
| PAY1 — Local workspace | Independent profiles/templates, sample preview, persistence and deletion | Offline operation, exact link preservation, migration/data recovery and accessibility checks |
| PAY2 — Unlock | Separate purchase/restore and entitlement gating | Neither/Custom/Payments/Both matrix; pending, cancellation, restart, offline ownership, restore and revocation cases |
| PAY3 — Provider pilot | Tested hosted-link creation/import, QR round trips and confirmed handoff | Official test links, correct provider destination, expiry/invalid-link behavior, unavailable apps, native device checks; no automatic charges |
| PAY4 — Release | Store configuration, disclosures, pricing and supported-provider matrix | Billing sandbox/license tests, platform review and signed release checks; Android/iOS evidence kept separate |
| Later | API-created requests, authenticated status, regional formats, optional hosted services | Independent provider, architecture, commercial and validation decisions |

Use disposable QA packages with verified APK identity and Flutter
`--no-uninstall`; explicitly clean up only the QA package and check protected
installations. Apply the [QA cleanup safeguards](qa/qa_cleanup_incident.md).
Never run payment or billing tests by deleting a user's normal app data, and
do not submit a real charge or add a provider account as an automated test.

Before enabling a paid flow, demonstrate that scanning/security review remains
free, package ownership stays independent, ordinary QR creation still works,
unknown providers fail safely, and neither a purchase nor a scan starts a
merchant payment without a separate user action.

## 11. Decisions still required

1. Confirm the recommended one-time unlock versus another commercial model.
2. Select the first country/provider matrix and merchant test account(s).
3. Set the package name, localized price strategy and actual store product IDs.
4. Approve the exact paid management/export features and any future bundle policy.
5. Decide whether later provider APIs, verified payment status or hosting are
   in a separate service tier; none is promised by the local-tools proposal.

This document creates no store product, registers no merchant, enables no
payment adapter and changes no existing purchase entitlement.
