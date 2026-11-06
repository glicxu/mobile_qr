# GS1 resolution gate

Status: deferred; local parsing is implemented. No resolver has been selected
or contacted. Product-provider availability does not control this decision.

Before an online action can be implemented, record a selected resolver/issuer
mechanism, protocol/version, permitted use and attribution, identifiers and
device metadata disclosed, authentication/backend needs, quotas and funded cost
limit, privacy/retention policy, redirect limits and response bounds.

The acceptance design must require an explicit request, disclosure of the
contacted service, review of each changed destination before contact, and a
separate confirmation before browser handoff. Bound timeouts, redirect hops,
response size, cancellation, stale responses and retry count. Any backend fetch
must block private/reserved networks and defend DNS rebinding on every hop.

Reconsider when a decision owner supplies a resolver candidate and operating
constraints. Until then ordinary confirmed URL opening and local GS1 fields
remain usable; no resolution UI is enabled.
