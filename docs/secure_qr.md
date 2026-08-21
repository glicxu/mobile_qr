# Secure QR — Domain and Link Verification Design

**Version:** 2.0  
**Status:** Proposed Design

## 1. Overview

Secure QR is a verification mechanism for standard QR codes designed primarily to detect **QR replacement attacks**, such as placing a malicious QR sticker over a legitimate QR code.

The key design decision is:

> **Secure QR does not change the QR-code format. It enhances the QR scanner.**

A Secure QR remains an ordinary standards-compliant QR code containing an ordinary URL. Any traditional QR scanner can scan it normally.

A Secure-QR-aware scanner additionally calculates a short verification code from the destination and displays it to the user.

The user compares this code with the verification code printed beside the physical QR code.

Example:

```text
Printed beside QR             Secure QR Scanner

    KDM-427                       KDM-427
                                    ✓
```

If someone covers the original QR with a malicious QR sticker:

```text
Printed beside QR             Secure QR Scanner

    KDM-427                       XPA-183
                                    ✕
```

The mismatch warns the user that the QR may have been replaced.

---

## 2. Primary Threat: QR Sticker Replacement

Consider a legitimate parking sign:

```text
PAY FOR PARKING

Secure QR
KDM-427

┌──────────────────────┐
│                      │
│     STANDARD QR      │
│                      │
└──────────────────────┘
```

The QR might contain:

```text
https://pay.example.com/parking?id=8472
```

An attacker could place another QR sticker over the original QR:

```text
PAY FOR PARKING

Secure QR
KDM-427

┌──────────────────────┐
│      MALICIOUS       │
│      QR STICKER      │
└──────────────────────┘
```

A traditional QR scanner simply follows the replacement URL.

A Secure QR scanner calculates the verification code of the replacement URL.

If it displays:

```text
XPA-183
```

the user immediately sees:

```text
KDM-427 ≠ XPA-183
```

and should not continue.

---

## 3. No New QR Format

An important simplification is that Secure QR does **not** introduce:

- a new QR-code standard;
- a second QR code;
- a secondary barcode;
- OCR inside the QR;
- hidden verification data;
- a special QR payload;
- a proprietary QR decoder.

The QR itself remains completely standard.

```text
Standard QR
     ↓
Standard URL
     ↓
Secure QR-aware scanner
     ↓
Verification calculation
     ↓
KDM-427
```

Traditional scanners remain fully compatible.

---

## 4. Human Verification

Secure QR deliberately keeps the final security decision simple.

The user does not need to inspect:

```text
https://pay.example.com/parking?id=8472&session=...
```

Instead, the user compares:

```text
KDM-427
```

with the code printed beside the QR.

The intended user interaction is:

> **Scan once. Compare six characters.**

---

# 5. Verification Code Format

## Verification eligibility

Secure QR 1.0 generates a domain-based verification code only when the QR
payload is an absolute HTTP or HTTPS URL with a valid registrable domain.

```text
https://example.com/path
```

is eligible for a verification code because `example.com` is its registrable
domain.

All other payloads use the default content-comparison profile. This profile can
confirm that two complete payload strings produce the same short code, but it
does not verify the identity or legitimacy of the payload's semantic target,
including:

- plain text;
- Wi-Fi credentials;
- phone numbers or `tel:` links;
- email addresses or `mailto:` links;
- `geo:` locations;
- payment payloads; or
- custom application links.

HTTP or HTTPS URLs whose host is an IP address or a single-label local host
also do not receive a domain-based verification code because they have no
registrable domain. They remain unverified web URLs and do not fall back to the
generic content profile.

The content-comparison format is:

```text
DDD-LLL
```

`DDD` is the complete payload's UTF-8 byte length modulo 1,000, padded to three
digits. `LLL` is a three-letter SHA-256 bucket over the complete payload using
the `secure-qr/v1/content\0` domain-separation prefix. Reversing the character
classes from the web format (`LLL-DDD`) makes the two profiles visibly
distinct. The modulo behavior is required because the payload limit exceeds
999 bytes.

Secure QR uses:

```text
AAA-000
```

Example:

```text
KDM-427
```

The code contains:

- **3 letters**
- **3 digits**

The two groups have different purposes.

```text
K D M  -  4 2 7
─────     ─────
Domain     Link
```

More specifically:

```text
KDM = eTLD+1 domain fingerprint

4   = URL-length fingerprint

27  = full-URL fingerprint
```

Therefore:

```text
KDM-427
│    ││
│    │└── Full URL fingerprint
│    │
│    └─── URL length fingerprint
│
└──────── eTLD+1 fingerprint
```

---

# 6. Domain Fingerprint

The first three letters are derived from the URL's **registrable domain**, also known as **eTLD+1**.

Example:

```text
https://pay.example.com/parking/8472
```

is parsed into:

```text
Hostname:
pay.example.com

Registrable domain / eTLD+1:
example.com
```

Secure QR calculates:

```text
DomainFingerprint("example.com")
        ↓
       KDM
```

Therefore these URLs share the same domain fingerprint:

```text
https://example.com/
https://www.example.com/
https://pay.example.com/
https://login.example.com/
```

All reduce to:

```text
example.com
```

and therefore all produce:

```text
KDM
```

---

# 7. Why eTLD+1 Matters

Simply taking the last two hostname components is incorrect.

For example:

```text
www.example.co.uk
```

has:

```text
Effective TLD:
co.uk

Registrable domain:
example.co.uk
```

Secure QR should therefore use the **Public Suffix List** or equivalent standards-based logic to determine the registrable domain.

---

# 8. Domain Verification as the Security Anchor

The domain fingerprint is the most important part of Secure QR.

An attacker can cheaply generate millions of URL variations:

```text
evil.com/pay?id=1
evil.com/pay?id=2
evil.com/pay?id=3
...
```

But obtaining large numbers of useful registrable domains is significantly harder.

Domains generally must be:

- available;
- registered;
- paid for;
- configured in DNS;
- configured for HTTPS;
- controlled by the attacker;
- plausible enough to deceive the victim.

Therefore Secure QR deliberately places more verification space into the domain component.

Three letters provide:

```text
26³ = 17,576
```

possible domain fingerprints.

A random alternative domain therefore has approximately:

```text
1 / 17,576
```

chance of producing the same domain fingerprint.

This domain constraint is an important part of Secure QR's practical resistance to deliberate collision searching.

---

# 9. Full URL Verification

Domain verification alone cannot detect changes within the legitimate domain.

For example:

```text
https://example.com/document/123

https://example.com/document/999
```

both have:

```text
eTLD+1 = example.com
```

and therefore the same three-letter domain fingerprint.

Secure QR consequently also includes a fingerprint derived from the **complete canonical URL**.

This is represented by the final two digits.

Example:

```text
https://example.com/document/123
                         ↓
                  URL fingerprint
                         ↓
                        27
```

---

# 10. URL Length Fingerprint

The first numerical digit provides an additional constraint related to the URL length.

Example:

```text
KDM-427
    ↑
    4
```

The purpose is to make trivial collision searching through arbitrary URL variations somewhat more constrained.

An attacker trying variations such as:

```text
evil.com/page?a=1
evil.com/page?a=2
evil.com/page?a=3
...
```

must satisfy both:

```text
URL length fingerprint
```

and:

```text
URL content fingerprint
```

The exact length-to-digit algorithm should be formally defined during implementation and must produce a deterministic value from the canonical URL length.

---

# 11. Combined Verification

The complete verification code therefore verifies three related properties:

```text
        KDM - 4 27
         │    │ │
         │    │ └── URL content
         │    │
         │    └──── URL length
         │
         └───────── registrable domain
```

Conceptually:

```text
SecureCode(URL):

    domain = eTLD+1(URL)

    letters =
        DomainHash(domain)

    lengthDigit =
        LengthHash(CanonicalURL)

    linkDigits =
        URLHash(CanonicalURL)

    return letters + "-" +
           lengthDigit + linkDigits
```

---

# 12. Code Space

Assuming uniformly distributed independent outputs:

## Domain portion

Three letters:

```text
26³ = 17,576
```

## URL-length portion

One digit:

```text
10
```

## URL fingerprint

Two digits:

```text
100
```

## Total

```text
17,576 × 10 × 100
```

equals:

```text
17,576,000
```

possible Secure QR verification codes.

The probability that two unrelated URLs randomly produce the same complete code is therefore approximately:

```text
1 / 17,576,000
```

or roughly:

> **1 in 17.6 million**

This should not be interpreted as equivalent to a cryptographic authentication strength of 17.6 million, because an attacker may actively choose inputs and search for collisions.

---

# 13. Why Domain and URL Security Differ

The two portions have different security properties.

## URL Fingerprint

An attacker can generate URL variations essentially for free.

For example:

```text
https://evil.com/pay?a=001
https://evil.com/pay?a=002
https://evil.com/pay?a=003
...
```

Therefore a short full-URL fingerprint alone is relatively easy to brute-force.

## Domain Fingerprint

The domain input space is much more constrained.

An attacker generally cannot cheaply create tens of thousands of useful, believable registrable domains.

Therefore:

> **The three-letter domain fingerprint is the primary practical security mechanism.**

The three numerical digits provide additional link verification.

---

# 14. Example

Original QR:

```text
https://pay.cityparking.com/session/8472
```

Suppose:

```text
eTLD+1:
cityparking.com

Domain fingerprint:
KDM

Length fingerprint:
4

Full URL fingerprint:
27
```

The Secure QR code is:

```text
KDM-427
```

The parking sign prints:

```text
PAY HERE

Secure QR: KDM-427

[STANDARD QR]
```

The scanner displays:

```text
SECURE QR

KDM-427

Domain:
cityparking.com
```

The user only needs to compare:

```text
KDM-427
```

---

# 15. Sticker Attack Example

An attacker replaces the QR with:

```text
https://cityparking-payment.net/pay
```

The scanner determines:

```text
eTLD+1:
cityparking-payment.net
```

and might calculate:

```text
XPR-183
```

The physical sign still says:

```text
KDM-427
```

The user sees:

```text
SIGN             PHONE

KDM-427          XPR-183

        ✕
```

This strongly suggests that the QR has been replaced or does not belong to the surrounding material.

---

# 16. Scanner User Interface

After scanning a Secure QR, the verification code should be the most visually prominent information.

Example:

```text
┌──────────────────────────┐
│                          │
│       SECURE QR          │
│                          │
│        KDM-427           │
│                          │
│   cityparking.com        │
│                          │
│ Compare this code with   │
│ the code beside the QR.  │
│                          │
└──────────────────────────┘
```

The scanner should not claim that the QR is automatically verified merely because it calculated a code.

The scanner does **not know the trusted printed code**.

The human comparison establishes the connection between:

```text
physical material
       ↕
QR destination
```

---

# 17. User Instructions

The basic Secure QR instruction should remain extremely simple:

> **Scan the QR and compare the six-character Secure QR code shown on your phone with the code printed beside the QR.**

For example:

```text
KDM-427 = KDM-427 ✓
```

If they do not match:

> **Do not open the link. The QR may have been replaced.**

---

# 18. Backward Compatibility

Secure QR requires no changes to the QR standard.

A traditional scanner performs:

```text
QR
 ↓
URL
 ↓
Open
```

A Secure QR scanner performs:

```text
QR
 ↓
URL
 ↓
Parse destination
 ↓
Determine eTLD+1
 ↓
Canonicalize URL
 ↓
Calculate AAA-000
 ↓
Display code
 ↓
Human comparison
```

Therefore the same physical QR works with both traditional and Secure QR scanners.

---

# 19. Security Properties

Secure QR is primarily intended to provide:

### Physical QR Replacement Detection

Detect a QR sticker placed over an existing legitimate QR.

### Domain Verification

Provide a short human-verifiable fingerprint of the destination's registrable domain.

### Link Verification

Provide additional verification that the exact URL has not changed.

### Offline Operation

No Secure QR server is required to calculate the verification code.

### Backward Compatibility

Existing QR codes and scanners continue to work normally.

---

# 20. Limitations

Secure QR does not provide complete cryptographic authentication.

In particular, it cannot prevent an attacker from replacing the entire physical sign:

```text
Original:

Sign
+ QR
+ KDM-427
```

with:

```text
Fake:

Fake Sign
+ Fake QR
+ matching fake code
```

Because the Secure QR algorithm is public and deterministic, the attacker can calculate the verification code for their own URL.

Secure QR primarily protects against:

> **replacement of the QR while the trusted surrounding material remains intact.**

This is the common sticker-overlay threat.

---

# 21. Terminology

The following terminology should be used consistently.

**Secure QR**

The overall destination-verification system.

**Secure QR Scanner**

A QR scanner capable of calculating and displaying Secure QR verification codes.

**Domain Fingerprint**

The three-letter code derived from eTLD+1.

Example:

```text
KDM
```

**Length Fingerprint**

The first numerical digit derived from URL length.

Example:

```text
4
```

**Link Fingerprint**

The final two digits derived from the complete canonical URL.

Example:

```text
27
```

**Secure QR Verification Code**

The complete six-character human-readable value.

Example:

```text
KDM-427
```

---

# 22. Proposed Secure QR 1.0 Format

The initial Secure QR specification should therefore use:

```text
AAA-000
```

with:

```text
AAA = eTLD+1 fingerprint
0   = canonical URL length fingerprint
00  = canonical full-URL fingerprint
```

Example:

```text
KDM-427
```

The design intentionally favors usability.

Six characters divided into:

```text
3 letters - 3 numbers
```

are fast for a human to recognize, remember briefly, and compare.

The conceptual meaning is also simple:

> **Letters verify the website. Numbers verify the link.**

That should be the foundation of **Secure QR 1.0**.

---

# 23. Prototype Algorithm Profile

The test implementation uses the following deterministic Secure QR 1.0
profile. These details are normative for its test vectors.

## Registrable domain

- Convert the hostname to lowercase ASCII using IDN/Punycode processing.
- Remove a trailing root dot.
- Determine eTLD+1 with the complete Public Suffix List, including its private
  section. Including private rules keeps independently controlled tenants such
  as `alice.github.io` and `bob.github.io` separate.
- IP addresses and single-label development hosts do not have a registrable
  domain and are not eligible for a Secure QR 1.0 verification code.

The Public Suffix List is bundled with the application. Code generation is
therefore offline and reproducible for a given application release.

## Canonical URL

1. Accept only an absolute HTTP or HTTPS URL without embedded credentials.
2. Lowercase the scheme and ASCII hostname.
3. Remove a trailing root dot from the hostname.
4. Remove the default port (`80` for HTTP or `443` for HTTPS).
5. Resolve dot segments in the path and use `/` for an empty path.
6. Preserve query parameter order and the fragment. URI percent escapes are
   serialized in the canonical form produced by Dart's `Uri` implementation.
7. Measure URL length in UTF-8 bytes, not UTF-16 code units.

## Fingerprints

All hashes use SHA-256. The first 32 digest bits are interpreted as an unsigned
big-endian integer and reduced into the required output space.

```text
domainValue = SHA256("secure-qr/v1/domain\0" + eTLD+1) mod 17,576
letters     = domainValue encoded as three base-26 letters, A through Z

lengthDigit = UTF8(canonicalURL).length mod 10

linkValue   = SHA256("secure-qr/v1/url\0" + canonicalURL) mod 100
linkDigits  = linkValue as two zero-padded decimal digits
```

The `\0` above is one NUL byte. The prefixes provide domain separation so the
domain and URL hashes cannot accidentally be treated as the same hash input.

## Fixed test vectors

```text
https://example.com/                         XIH-000
https://pay.example.com/parking?id=8472      XIH-955
https://example.co.uk/document/123           KNM-485
https://alice.github.io/pay                   RDG-731
https://你好.cn/                              FVV-217
```
