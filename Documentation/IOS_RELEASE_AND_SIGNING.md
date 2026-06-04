# iOS Release and Signing

Condensed guide for distributing Switch2Go. For everyday builds, use [iosApp/BUILD_AND_RUN.md](../iosApp/BUILD_AND_RUN.md).

## Apple Developer account

- **Free Apple ID:** run on your own devices (short-lived provisioning).
- **Paid program ($99/year):** TestFlight, App Store, longer profiles.

In Xcode: **Settings → Accounts** → add your Apple ID. Select your **Team** on the iosApp target → **Signing & Capabilities** → **Automatically manage signing**.

### App ID capabilities

At [developer.apple.com](https://developer.apple.com/account) → Identifiers, ensure the app ID includes **Camera** (required for tracking modes).

## Cloud Mac (optional)

If you do not own a Mac, use a rented Mac mini (e.g. MacStadium, MacinCloud) or AWS EC2 Mac for Xcode builds. Connect via Screen Sharing or Jump Desktop; install Xcode, CocoaPods, and JDK 17 as in [BUILD_AND_RUN.md](../iosApp/BUILD_AND_RUN.md).

## Archive and upload

1. In Xcode, destination: **Any iOS Device (arm64)**.
2. **Product → Archive**.
3. In Organizer: **Distribute App** → **App Store Connect** → upload.
4. Wait for processing in [App Store Connect](https://appstoreconnect.apple.com).

## TestFlight

1. App Store Connect → your app → **TestFlight**.
2. Add **internal** testers (team) or **external** testers (beta review required for external).
3. Install via TestFlight app on iPad; verify camera, gaze, and switch flows per [TESTING_GUIDE.md](../TESTING_GUIDE.md).

## App Store submission

Prepare screenshots, description, support URL, and privacy policy URL (in-app policy matches [switch2goaac.org](https://switch2goaac.org) / Settings → Privacy Policy).

Select the TestFlight build → submit for review.

## CI

GitHub Actions workflow: `.github/workflows/ios.yml` — builds KMP framework and Xcode project on `macos-latest` (see workflow for simulator destination).

## Common signing errors

| Issue | Fix |
|-------|-----|
| No signing certificate | Xcode → Accounts → Download Manual Profiles; pick Team |
| Provisioning profile doesn't match | Clean build folder; toggle automatic signing |
| Device untrusted | iPad: Settings → General → VPN & Device Management → Trust |

## Full bootstrap archive

The long step-by-step guide used when the iOS app was first created (sample Swift/Kotlin, manual framework linking) is archived at [legacy/IOS_DEVELOPMENT_GUIDE.md](legacy/IOS_DEVELOPMENT_GUIDE.md). Do not follow it for normal development.
