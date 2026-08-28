# JapasTycoon iOS

iOS port of Japas Tycoon (match-3 puzzle game about traditional Indonesian snacks), built with Godot 4.6.

## Prerequisites

1. **Apple Developer Account** ($99/year) - [developer.apple.com](https://developer.apple.com)
2. **App ID** registered with bundle identifier `com.japastycoon` (with In-App Purchase capability)
3. **App Store Connect API Key** created (Admin role), `.p8` file downloaded
4. **IAP Products** registered in App Store Connect with IDs `com.japastycoon.instant_coins_1/2/3` (consumable) — approved before TestFlight purchases work
5. **GitHub Account** - For CI/CD pipeline (public repo = free macOS runners)

## Setup Instructions

### 1. GitHub Repository Setup

Create a **public** GitHub repository for this project, then add these repository secrets (Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `APP_STORE_CONNECT_API_KEY_ID` | Your App Store Connect API key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Your App Store Connect API issuer ID |
| `APP_STORE_CONNECT_API_KEY_KEY` | Your App Store Connect API private key (base64) |
| `BUILD_CERTIFICATE_P12` | Base64 of the `.p12` distribution certificate (see below) |

### 2. Initial Certificate Setup (One-Time)

Run the **Initialize Certificates** workflow manually (Actions → Initialize Certificates → Run workflow). It creates a distribution certificate + provisioning profile via Fastlane and uploads a `.p12` artifact.

Then:
1. Download the `ios-certificates` artifact and extract `certificate.p12`
2. Base64 encode it: `base64 -i certificate.p12`
3. Store the output as the `BUILD_CERTIFICATE_P12` secret

### 3. Build & Deploy

Push to `main` branch or trigger the **Distribute to TestFlight** workflow manually.

### 4. Test via TestFlight

1. Install the **TestFlight** app on your iOS device
2. Wait for the build to process (usually 10-30 minutes)
3. Install and test the build

### 5. App Store Submission

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select the TestFlight build
3. Submit for App Store review

## Project Structure

```
JapasTycoonIos/
├── assets/                  # Game art, icons, audio
├── resources/               # Game data + localization strings (JSON)
├── scenes/                  # Godot scene files
├── autoload/                # GDScript autoloads (AdsManager, IAPManager, etc.)
├── addons/godot-iap/        # OpenIAP (StoreKit 2) plugin
├── ios/plugins/             # Unity Ads iOS plugin (native bridge + SDK)
├── fastlane/                # Fastlane config
├── .github/workflows/       # GitHub Actions CI/CD
└── project.godot            # Godot project file
```

## Key Changes from Android Version

| Feature | Android | iOS |
|---------|---------|-----|
| IAP | Google Play Billing | OpenIAP (StoreKit 2) |
| Ads | Unity Ads | Unity Ads (native iOS bridge) |
| IAP product IDs | `instant_coins_1/2/3` | `com.japastycoon.instant_coins_1/2/3` |
| Build | Gradle | GitHub Actions + Fastlane |

## Unity Ads Configuration

- **iOS Game ID**: set under **Project Settings → unity_ads → ios → game_id** (currently a placeholder `0000000` test ID).
- **Rewarded placement**: `unity_ads → ios → placements → rewarded` (default `Rewarded_iOS`).
- `test_mode` is `true` by default — set it to `false` for production.

Replace the placeholder Game ID with your real Unity Ads Game ID before production release.

## Troubleshooting

### Build fails with "No matching provisioning profiles"

Run the **Initialize Certificates** workflow again (or re-download + re-import the `.p12`).

### Godot export fails

Ensure you have the latest Godot 4.6 stable release and iOS export templates installed.

### TestFlight build not appearing

Check the GitHub Actions logs. Common issues:
- Missing or incorrect secrets
- Certificate/profile mismatch
- Bundle ID mismatch
- IAP products not yet approved (purchases fail silently)
