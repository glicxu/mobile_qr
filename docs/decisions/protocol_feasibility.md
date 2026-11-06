# Matter and payment protocol feasibility

Prepared 2026-10-29 for WP14–WP15. These are independent research gates;
neither protocol is enabled by this document. **User decision, 2026-10-29:
defer both Matter and payment pilots for now.** Do not start either integration
until that direction changes. Decision owners and concrete
pilot targets remain unassigned. Keep the local creation/authenticator work
independent of these inputs and of the unavailable product-information provider.

## Matter — WP14

Google documents a useful Android path for a general-purpose scanner:
recognize a supported `MT:` setup payload, obtain explicit confirmation, and
send an `ACTION_VIEW` intent targeted to Google Play Services. The platform
then selects a commissioning application. The documentation includes a minimum
Base38 payload shape, but matching that shape alone does not validate all
payload fields, authorize pairing or prove a compatible device is nearby.
See [Google's intent-based commissioning integration](https://developers.home.google.com/samples/intent-based-commissioning)
and the [CSA commissioning overview](https://csa-iot.org/all-solutions/matter/matter-faq/).

Proposed narrow pilot: recognize and locally validate one documented setup
payload version, mask setup credentials, exclude persistence and batch export,
then offer a confirmed platform commissioning handoff. Dali QR would not
become a Matter controller or invent replacement setup credentials.

Required before a go decision:

- A named Matter device, its legitimate setup code and a compatible commissioner.
- Confirmation of applicable payload versions, Play Services/Android support,
  unsupported-handler behavior and current platform prerequisites.
- Physical setup, cancellation, reset/retry and wrong-code checks. A launch
  must not be labeled as completed commissioning.
- An independently assessed iOS integration; no iPhone/Mac validation is available
  in the current Android-first workspace.

Engineering recommendation: defer enablement until hardware and commissioner
are selected. A documented Android entry point is promising feasibility
evidence, not a completed hardware interoperability test. No pairing attempted.

Read-only Android resolution checks on the connected SM-T290/API 30 and
SM-G975U/API 31 both resolve Google's documented sample `MT:` intent to Play
Services. The handler was not launched. This establishes a candidate entry
point on those devices, not commissioner availability or pairing success.

## Payment QR — WP15

Update, 2026-10-30: payment options have been reviewed, and the user requested
a separate management package and unlock purchase. The
[Payments Package proposal](../payments_package.md) is now the product-planning
reference. PAY1 local workspace and sample exploration are now implemented with
independent entitlement gates. Store configuration, verified ownership and
provider/market selection remain open; the earlier deferral still applies to
live pilot work. Matter remains deferred.

EMVCo specifies structured payment QR formats, while processing and network
messaging belong to the payment provider. A generic reader cannot claim that
decoding a merchant code completes a payment. See the
[EMVCo specification and processing overview](https://www.emvco.com/emv-technologies/qr-codes/).

Proposed narrow pilot: select one country/payment system and wallet; review
supported recipient/merchant fields, amount and currency locally, then offer
an approved, confirmed wallet handoff. No money movement, wallet-account
creation or arbitrary merchant-code issuance is part of initial feasibility.

Required before a go decision:

- Country, named payment system, intended wallet and a legitimate test merchant.
- Applicable specification/version, supported extensions, URI/API entry point,
  test/sandbox access, provider terms and authorization requirements.
- A decision on what recipient data can actually be verified. A readable label
  or checksum must not be presented as verified merchant identity.
- Test fixtures for malformed payloads, amount/currency discrepancies,
  unavailable wallets, cancellation and outcome reporting without sending money.

Engineering recommendation: defer implementation until the market and provider
are specified. No universal wallet route, payment approval or transaction
success is assumed, and no wallet or payment account has been accessed.
