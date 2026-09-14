# Dali QR — Payload Classification, App Routing, and Security Verification

## 1. Purpose

Dali QR should support QR codes containing more than website URLs while maintaining a clear distinction between:

1. **QR decoding**
2. **Payload classification**
3. **Security verification**
4. **Application/action routing**

A QR code itself does not specify which application must open. It contains a payload. Dali QR decodes that payload, determines its type, applies any applicable security verification, and then asks the operating system to perform the appropriate action.

A central security principle is:

> **No verification code without a defined verification model for that QR payload type.**

The Dali Secure QR domain-based profile applies only to web URLs with valid
domains. Other payloads use a separate content-comparison profile whose
digit-first format cannot be confused with a domain code.

---

## 2. QR Codes Are Data Containers

A QR code contains bytes representing data.

Examples include:

```text
https://example.com/product/123

mailto:support@example.com

tel:+14255551212

sms:+14255551212?body=Hello

geo:47.6101,-122.2015

WIFI:T:WPA;S:MyNetwork;P:password;;

BEGIN:VCARD
...
END:VCARD
```

The QR format itself does not mean:

> "Open Safari"

or:

> "Open Google Maps"

Instead, the scanner interprets the payload and determines the appropriate action.

---

## 3. High-Level Architecture

```text
                QR Image
                    │
                    ▼
              QR Decoder
                    │
                    ▼
             Raw QR Payload
                    │
                    ▼
          Payload Classification
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
      Web URL     Known Type    Unknown
        │           │           │
        ▼           ▼           ▼
     Parser       Parser     Plain Data
        │           │           │
        └───────────┼───────────┘
                    ▼
             Security Policy
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
      Web Domain            Other
          │                   │
          ▼                   ▼
   Domain Verification    Content Comparison
          │
          └─────────┬─────────┘
                    ▼
              User Preview
                    │
                    ▼
             User Confirmation
                    │
                    ▼
              OS/App Routing
```

The three major subsystems should remain independent:

```text
Classification
      ↓
Verification
      ↓
Routing
```

This separation will make it possible to add new QR types and new verification methods later without redesigning the entire scanner.

---

# 4. Supported Payload Types

## 4.1 Web URLs

Examples:

```text
https://dalifin.com
https://example.com/products/123
http://example.org
```

Classification:

```text
WEB_URL
```

Action:

```text
Open URL
```

Security:

```text
Domain Verification Supported
```

The registrable domain (`eTLD+1`) is extracted.

For example:

```text
https://shop.example.com/product/123

Host:
shop.example.com

eTLD+1:
example.com
```

The Dali Secure QR verification code can then be calculated using the defined domain/URL algorithm.

---

## 4.2 Email

Example:

```text
mailto:support@example.com
```

Classification:

```text
EMAIL
```

Action:

```text
Compose Email
```

Typical OS behavior:

```text
Default email application
```

Security:

```text
Not currently verified
```

Although an email address contains a domain, Dali QR should **not reuse the website verification algorithm automatically**.

Email requires its own security definition before verification is offered.

---

## 4.3 Telephone

Example:

```text
tel:+14255551212
```

Classification:

```text
PHONE
```

Action:

```text
Call Number
```

Security:

```text
Not currently verified
```

Dali QR should display the number before allowing the call.

---

## 4.4 SMS

Examples:

```text
sms:+14255551212
```

or:

```text
sms:+14255551212?body=Hello
```

Classification:

```text
SMS
```

Action:

```text
Compose SMS
```

Security:

```text
Not currently verified
```

The destination number and message should be shown before opening the messaging application.

---

## 4.5 Geographic Location

Example:

```text
geo:47.6101,-122.2015
```

Classification:

```text
LOCATION
```

Action:

```text
Open Location
```

The operating system can determine the appropriate mapping application.

Security:

```text
Not currently verified
```

---

## 4.6 Wi-Fi

Example:

```text
WIFI:T:WPA;S:GuestNetwork;P:password123;;
```

Classification:

```text
WIFI
```

Parsed fields may include:

```text
SSID
Security Type
Password
Hidden Network
```

Action:

```text
Connect / Configure Wi-Fi
```

Security:

```text
Not currently verified
```

Because Wi-Fi QR codes can cause a device to connect to an attacker-controlled network, Dali QR should clearly display the SSID before proceeding.

---

## 4.7 Contact / vCard

Example:

```text
BEGIN:VCARD
VERSION:3.0
FN:John Smith
TEL:+14255551212
EMAIL:john@example.com
END:VCARD
```

Classification:

```text
CONTACT
```

Action:

```text
Preview Contact
Add to Contacts
```

Security:

```text
Not currently verified
```

---

## 4.8 Calendar Event

Example:

```text
BEGIN:VEVENT
SUMMARY:Sunday Service
DTSTART:20260823T100000
DTEND:20260823T113000
END:VEVENT
```

Classification:

```text
CALENDAR_EVENT
```

Action:

```text
Preview Event
Add to Calendar
```

Security:

```text
Not currently verified
```

---

## 4.9 Application Deep Links

Examples could include custom URI schemes such as:

```text
someapp://resource/123
```

Classification:

```text
APP_DEEP_LINK
```

Action:

```text
Request OS to open URI
```

Security:

```text
Not currently verified
```

Dali QR should not assume that a particular URI scheme belongs to a trustworthy application merely because an application on the device has registered it.

---

## 4.10 Unknown / Plain Text

Example:

```text
Meeting room access code: 839274
```

Classification:

```text
TEXT
```

Action:

```text
Display
Copy
Share
```

Security:

```text
Not verified
```

Unknown data should **never automatically launch an external application**.

---

# 5. Payload Classification Table

| Payload | Classification | OS Action | Current Verification |
|---|---|---|---|
| `https://...` | Web URL | Open URL | **Domain verified** |
| `http://...` | Web URL | Open URL | **Domain verified** |
| `mailto:` | Email | Compose email | Content comparison only |
| `tel:` | Phone | Call | Content comparison only |
| `sms:` / `smsto:` | SMS | Compose message | Content comparison only |
| `geo:` | Location | Open location | Content comparison only |
| `WIFI:` | Wi-Fi | Configure/connect | Content comparison only |
| `BEGIN:VCARD` | Contact | Add contact | Content comparison only |
| `BEGIN:VEVENT` | Calendar | Add event | Content comparison only |
| Known/custom URI | Deep link | OS application routing | Content comparison only |
| Unknown | Text/data | Display | Content comparison only |

---

# 6. Do Not Map QR Types Directly to Applications

Dali QR should **not** maintain a large table such as:

```text
geo → Google Maps
mailto → Gmail
https → Chrome
music → Spotify
```

This would be fragile and platform-dependent.

Instead, use:

```text
Payload Type
      ↓
Logical Action
      ↓
Operating System
      ↓
Installed / Default Application
```

For example:

```text
geo:
   ↓
OPEN_LOCATION
   ↓
Operating System
   ↓
User's mapping application
```

This keeps Dali QR independent of specific third-party applications.

---

# 7. HTTPS URLs Can Also Open Apps

Web URLs require special consideration.

For example:

```text
https://example.com/product/123
```

may open:

```text
Browser
```

or an installed application associated with that domain.

On iOS this can occur through **Universal Links**.

On Android this can occur through **App Links**.

Therefore Dali QR does not need to predict exactly which application will ultimately open.

Its responsibility is:

```text
Decode
    ↓
Recognize HTTPS
    ↓
Verify Domain
    ↓
Display Destination
    ↓
User Approves
    ↓
Pass URL to OS
```

The OS then performs final routing.

---

# 8. Security Verification Boundary

The existing Dali Secure QR system is based on the web domain.

For example:

```text
https://shop.example.com/order/123
```

Dali QR can derive:

```text
eTLD+1 = example.com
```

and generate/check the Dali verification code.

This provides a meaningful relationship between:

```text
Printed Verification Code
            ↕
Encoded URL
            ↕
Destination Domain
```

Other payload types use a content-comparison code. It can show that two complete
payload strings match, but it does not establish the identity or legitimacy of
an email address, network, phone number, payment recipient, application, or
other semantic target.

---

# 9. Critical Security Rule

Dali QR must never present a generic content hash as identity verification.

A hash is not necessarily a meaningful security verification.

Therefore:

> **No verification code without a defined verification model for that QR payload type.**

For example:

```text
WIFI:T:WPA;S:AirportFreeWiFi;P:abc123;;
```

Dali QR could technically hash this string and produce:

```text
ABC-123
```

but that would not establish what is actually being verified.

The user might incorrectly interpret the code as meaning:

> "This Wi-Fi network is legitimate."

Therefore the code may be shown only as a content-comparison code, with no claim
that the Wi-Fi network is legitimate.

---

# 10. Current Verification Policy

Initial implementation:

```text
if payload.type == WEB_URL
   and URL has valid registrable domain:

       verification = DOMAIN_VERIFICATION

else:

       comparison = CONTENT_COMPARISON
```

The default content format is `DDD-LLL`. `DDD` is the complete payload's UTF-8
byte length modulo 1,000, padded to three digits. `LLL` is a three-letter
SHA-256 bucket over the complete payload using the
`secure-qr/v1/content\0` domain-separation prefix. This reverses the web
format's letter/digit order so users can distinguish the profiles.

UI examples:

### Website

```text
Website

example.com

Verification
ABC-923

[Open]
```

### Wi-Fi

```text
Wi-Fi Network

GuestNetwork

Content code
041-AVZ

[Connect]
```

### Telephone

```text
Phone Number

+1 425 555 1212

Content code
016-ABC

[Call]
```

The UI must not claim that Dali QR has verified the payload merely because it
calculated a code. Dali QR does not know whether a trusted comparison code is
available or whether the user found a match.

For supported web URLs, prompt the user with:

```text
VERIFY IF AVAILABLE
```

If a trusted printed code is available, the user may compare it and confirm a
match. If no trusted code is available, any decision to continue must be
presented as opening unverified. Content codes remain:

```text
CONTENT COMPARISON ONLY
```

---

# 11. Future Verification Models

Other QR types can eventually receive verification support, but each requires a separate design.

Possible future examples:

### Email

Potential identity:

```text
normalized email address
```

or:

```text
email domain
```

But the threat model must first define what the verification code guarantees.

### Payment

Potential identity:

```text
payment network
merchant identifier
account identifier
currency
```

Payment QR verification should not be implemented until the relevant payment specification is understood.

### Wi-Fi

Potential identity might involve:

```text
SSID
security type
organization identity
```

However, an SSID alone does not prove ownership of a network.

### Application Deep Links

Verification might eventually be based on:

```text
Application identity
Associated domain
Registered application link
```

Again, this requires a separate trust model.

---

# 12. Classifier Design

The classifier should use explicit parsers rather than loose substring matching.

Suggested precedence:

```text
1. HTTP/HTTPS URL
2. Email URI
3. Telephone URI
4. SMS URI
5. Geographic URI
6. Wi-Fi payload
7. vCard
8. Calendar event
9. Recognized custom URI
10. Generic URI
11. Plain text / unknown
```

The classifier should return a structured object.

Example:

```json
{
  "type": "WEB_URL",
  "rawPayload": "https://shop.example.com/product/123",
  "scheme": "https",
  "host": "shop.example.com",
  "registrableDomain": "example.com",
  "path": "/product/123",
  "verificationType": "DOMAIN"
}
```

For Wi-Fi:

```json
{
  "type": "WIFI",
  "ssid": "GuestNetwork",
  "security": "WPA",
  "verificationType": "NONE"
}
```

---

# 13. Safe Fallback Behavior

When Dali QR cannot confidently classify a QR payload:

```text
UNKNOWN
```

should be returned.

The application should:

1. Display the decoded content.
2. Allow the user to copy it.
3. Optionally allow sharing.
4. **Not automatically execute it.**
5. **Not display a security verification code.**

This gives Dali QR a fail-safe default:

> **Unknown means data, not an action.**

---

# 14. User Confirmation

Dali QR should generally separate scanning from executing.

Recommended workflow:

```text
Scan
 ↓
Decode
 ↓
Classify
 ↓
Verify if supported
 ↓
Preview
 ↓
User confirms
 ↓
Execute
```

This is especially important for:

- Websites
- Phone calls
- SMS
- Wi-Fi
- App deep links
- Payment payloads
- Unknown URI schemes

Scanning should not itself constitute permission to execute the payload.

---

# 15. Separation of Responsibilities

The implementation should have independent components such as:

```text
QrDecoder
    │
    ▼
PayloadClassifier
    │
    ▼
PayloadParser
    │
    ▼
VerificationEngine
    │
    ▼
ActionResolver
    │
    ▼
UserConfirmation
    │
    ▼
PlatformLauncher
```

### QrDecoder

Responsible only for extracting bytes/text from the QR symbol.

### PayloadClassifier

Determines what the payload represents.

### PayloadParser

Converts the raw payload into structured data.

### VerificationEngine

Determines whether a verification model exists and performs it.

Initially:

```text
WEB_URL → DomainVerificationEngine
Everything else → ContentComparisonEngine
```

### ActionResolver

Maps the classified payload to a logical action.

For example:

```text
WEB_URL  → OPEN_URL
EMAIL    → COMPOSE_EMAIL
PHONE    → CALL
SMS      → COMPOSE_SMS
LOCATION → OPEN_LOCATION
WIFI     → CONNECT_WIFI
CONTACT  → IMPORT_CONTACT
CALENDAR → IMPORT_EVENT
TEXT     → DISPLAY
```

### PlatformLauncher

Converts the logical action into the appropriate iOS or Android platform operation.

---

# 16. Design Principle

The key distinction in Dali QR is:

What is this QR?
        ↓
Classification

Can its identity be verified?
        ↓
Verification

What should happen with it?
        ↓
Routing

These are three separate questions.

Dali QR should never infer security from its ability to recognize or open a payload.

A QR may be:

Recognized
Openable
Unverified

at the same time.

That distinction should remain fundamental to the Dali QR architecture.

# 17. Initial Scope Recommendation

For the first general-purpose Dali QR implementation, support:

Web URL
Plain text
Email
Telephone
SMS
Wi-Fi
Location
Contact/vCard
Calendar event
App/deep link

# 18. Center Badge and Future OCR

The optional center verification badge uses black characters on an opaque
white background. Its short two-line format is intended to remain readable by
people and compatible with possible future OCR experiments.

OCR output must initially be treated only as an untrusted alert that a visible
code may be present. It must not establish verification, approve an action, or
change routing. Dali QR continues to decode the primary QR payload and
calculate its comparison code independently. A future OCR result may invite
the user to compare the visible and calculated values, but the application
must not claim that they match without explicit confirmation.

# 19. Code Images Saved on the Same Phone

The Scan screen also allows the user to choose an image from the system photo
picker. This supports screenshots, downloaded images, QR codes, and supported
1D barcodes displayed elsewhere on the same phone without requiring a second
device or pointing the camera at another screen.

The selected image is decoded locally and is not retained by Dali QR. A decoded
payload follows the same classification, preview, history, and
user-confirmation flow as a camera scan. Comparison codes remain available
only for QR Code symbols. Choosing an image must never open or send its payload
automatically. If the image contains no readable QR code or supported barcode,
the app reports that result and resumes the camera scanner. If it contains
multiple supported symbols, the app asks the user which result to inspect.

Other applications may also send a single image to Dali QR through the system
share sheet. Android exposes Dali QR as an `image/*` share target. iOS uses a
Share Extension and an App Group shared only by that extension and the main
application. In both cases, Dali QR copies the received image into private
temporary storage, opens the Scan screen, decodes it through the same
format-aware pipeline, and deletes the temporary image when analysis finishes.
Sharing an image does not approve or launch the decoded payload.

The Android application ID and iOS main-app bundle ID are `com.dalifin.qr`.
The iOS share extension uses `com.dalifin.qr.ShareExtension`, and both iOS
targets use the `group.com.dalifin.qr.shared` App Group.
