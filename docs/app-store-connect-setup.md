# App Store Connect Setup — V1.1 IAP

One-time configuration in App Store Connect before V1.1 launch. The code is ready; this is the manual administrative work.

## Prerequisites

- [ ] Apple Developer account active (Apple Developer Program membership, $99/year)
- [ ] App created in App Store Connect with bundle ID `com.tastefyapp.DirectorSeat`
- [ ] Paid Applications Agreement signed in App Store Connect → Agreements, Tax, and Banking
- [ ] Banking and tax forms completed (required before Apple will pay you)

## Create the In-App Purchase product

1. App Store Connect → My Apps → DirectorSeat → **In-App Purchases and Subscriptions** → **In-App Purchases** → **+**
2. Select **Consumable**
3. Reference Name: `Film Export Credit`
4. Product ID: `com.tastefyapp.DirectorSeat.filmexport` — MUST match exactly what's in `StoreManager.productIDs` and `Products.storekit`
5. Click **Create**

## Configure the product details

Under the product detail page:

1. **Pricing**: Tier matching $4.99 USD (Apple auto-calculates international tiers)
2. **Availability**: All territories where you want to sell — most apps select all available
3. **Localizations** → Add English (and any other languages you support):
   - Display Name: `Film Export`
   - Description: `Export your film without watermark.`
4. **Review Information**:
   - Screenshot (1024×1024 recommended): Take a screenshot of the paywall in simulator showing the purchase button. Apple uses this to verify the product is in the app.
   - Review Notes: `Tap "Make a film" on home screen, complete a short film, reach the paywall. The "Export Clean — $4.99" button triggers this IAP.`
5. **Status**: Save the product — it will show as "Ready to Submit" or "Missing Metadata" until everything is filled in

## Promo codes

1. Once the IAP is approved, you can generate promo codes:
2. App Store Connect → Promo Codes (left sidebar) → Request Promo Codes
3. Select the IAP, choose quantity (up to 100 per six-month period per product)
4. Codes are delivered as a `.txt` file with one code per line
5. **Share these via:** social media announcements, email to early testers, direct outreach to creators

Test promo codes can be created in App Store Connect → My Apps → DirectorSeat → TestFlight → Sandbox Apple ID (these work in TestFlight builds without real money).

## Sandbox testing

1. Create a Sandbox Apple ID in App Store Connect → Users and Access → Sandbox Testers
2. On your iPhone, sign out of the real App Store (Settings → App Store → Sandbox Account)
3. Build the app via TestFlight or directly via Xcode
4. The paywall will accept the sandbox account's purchases — no real money charged
5. Sandbox transactions appear faster than real ones for testing purposes

## Submission with the app

The IAP must be submitted **together with the app build** for review:

1. Upload your build via Xcode → Archive → Distribute → App Store Connect
2. In App Store Connect → App Store → Version → "In-App Purchases" section, attach the `filmexport` IAP to this version
3. Submit the version with the IAP included
4. Apple reviews both the app and the IAP — both must be approved
5. Common rejection reasons:
   - IAP not actually accessible in the app (paywall hidden or broken)
   - Description doesn't match what the IAP delivers
   - Missing screenshot or unclear what the user gets
   - Pricing tier seems excessive for what's offered (low risk at $4.99)

## After launch

- Monitor App Store Connect → Sales and Trends for purchase data
- Subscriptions (if added later) require additional configuration in the same section
- To add new tiers (Sketch, Larger Project, Creator Pack), repeat the "Create the In-App Purchase product" steps with different product IDs
- Add new product IDs to `StoreManager.productIDs` and `StoreManager.creditsPerProduct` in code
- The credit-based architecture means no other code changes are needed

## Open questions for V1.1 launch

- [ ] What's the actual launch price? Currently $4.99 in `Products.storekit` and assumed in App Store Connect setup. Change in code AND App Store Connect if different.
- [ ] Are promo codes distributed via X (Twitter), TikTok, email list, or 1:1 outreach? Decide before code generation.
- [ ] Will V1.1 launch in all territories, or limit initially? US-only launch reduces support burden but limits reach.
