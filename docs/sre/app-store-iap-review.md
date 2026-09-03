# App Store IAP Review Runbook

## Dali Secure QR Custom

- App bundle ID: `com.dalifin.qr`
- IAP product ID: `dali_secure_qr_custom_lifetime`
- IAP type: non-consumable lifetime unlock
- Price used for review/testing: `$3.99`

## Lessons Learned

Use a dedicated App Store Connect sandbox tester for IAP testing. Do not rely on
a production Apple ID signed in as the sandbox account, even if it appears to
work sometimes. It can produce inconsistent results, especially around product
lookup, restore state, and stale non-consumable purchase history.

For Dali Secure QR, use a sandbox tester account in the United States storefront,
such as:

```text
gli+sandbox@dalifin.com
```

The IAP review screenshot should be a real screenshot of Apple's sandbox
purchase sheet, not a generic in-app paywall screenshot. The screenshot should
show:

- The `Sandbox` purchase sheet title.
- Product name `Dali Secure QR Custom`.
- Price, such as `$3.99`.
- The sandbox account email.
- Apple's testing notice that the account will not be charged.

The current reviewed screenshot artifact is stored locally at:

```text
artifacts/screenshots/dali-secure-qr-iap-sandbox.jpg
```

## Phone Setup

On the physical iPhone:

1. Open Settings.
2. Go to Developer.
3. Open Sandbox Apple Account.
4. Sign out of any production Apple ID.
5. Sign in with the dedicated sandbox tester.

Do not sign into the sandbox tester as the device's main iCloud/App Store
account.

## App Test Path

Primary review path:

1. Open Dali Secure QR.
2. Tap Settings.
3. Under Customization, tap `Unlock lifetime customization`.
4. Confirm that Apple's sandbox purchase sheet appears.

Alternate path:

1. Open Create.
2. Enter content, such as `https://example.com`.
3. Select Custom.
4. Choose a center image or logo.
5. Generate the QR code.
6. Tap Share QR image or Copy QR image.
7. Confirm that the lifetime unlock appears.

Plain QR export and Secure QR verification must remain free.

## App Store Connect Flow

Before resubmitting after IAP rejection:

1. Fix IAP metadata. Remove all references to other platforms.
2. Update the IAP Review Note with the Settings path and alternate custom-export
   path.
3. Replace the IAP App Review screenshot with a real Apple sandbox purchase
   sheet screenshot.
4. Submit the app version and IAP version together for review.

If the IAP screenshot is locked, remove the IAP review item from the unresolved
review submission first. Once removed, App Store Connect allows deleting and
replacing the review screenshot.

## Known Good Review Note

```text
Dali Secure QR Custom unlocks lifetime export of QR codes with a custom center image or logo. To locate the In-App Purchase: open Dali Secure QR, tap Settings in the bottom navigation, then under Customization tap Unlock lifetime customization. The Apple sandbox purchase sheet appears for Dali Secure QR Custom and shows the current localized price. Alternative path: open the Create tab, enter QR content such as https://example.com, select Custom, choose any image from Photos, tap Generate QR code, then tap Share QR image or Copy QR image. The lifetime customization unlock is shown. Plain QR export and Secure QR verification remain free. The In-App Purchase is available for the United States storefront and is not restricted by device configuration.
```

## StoreKit Diagnostics

In a debug build, product lookup should log:

```text
StoreKit product query: found=[dali_secure_qr_custom_lifetime] notFound=[] error=null
```

If it logs `notFound=[dali_secure_qr_custom_lifetime]`, check:

- The IAP has a valid price.
- The sandbox tester country matches an available territory.
- The IAP screenshot and metadata are complete.
- The app version and IAP version are submitted together when required.

