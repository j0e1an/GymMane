# Sideload GymMane with AltServer (free Apple ID)

Use this when you do not have a paid Apple Developer Program membership.

**AltServer is not part of this repository.** Get AltServer (Mac) and AltStore
(iPhone) from [https://altstore.io](https://altstore.io). This project only
ships a script that builds an unsigned IPA; AltStore resigns that IPA with your
Apple ID. Free accounts get a **7-day** certificate — refresh from AltStore
while AltServer is running on your Mac.

## What works on a free Apple ID

| Feature | Expected |
|---|---|
| Log workouts, body map, library, progress, backups | Yes |
| Home-screen widgets | Often no (App Groups stripped / extra App IDs) |
| Live Activity rest timer | Often no |
| Share extension | Often no |

GymMane’s main targets share `group.com.gymmane.app`. Free provisioning usually
cannot keep that entitlement, so anything that depends on the group may fail
quietly after install. Core logging does not need it.

## 1. Install AltServer and AltStore

1. Download **AltServer** from [altstore.io](https://altstore.io) and install it
   on this Mac. Keep it running (menu bar icon).
2. Plug in your iPhone (or use Wi‑Fi once set up) and use AltServer to install
   **AltStore** on the device.
3. Open AltStore and sign in with your **free Apple ID**.

## 2. Build the GymMane IPA

On a Mac with Xcode 15+ (Xcode 27 recommended for iOS 27 devices) and Flutter:

```bash
cd ios   # this Flutter project root (GymMane/ios)
chmod +x scripts/build_altstore_ipa.sh scripts/patch_spm_ios_floor.sh
./scripts/build_altstore_ipa.sh
```

The IPA lands at:

```text
build/ios/ipa/GymMane.ipa
```

## 3. Sideload the IPA

1. In AltStore: **My Apps** → **+** → choose `build/ios/ipa/GymMane.ipa`.
2. Trust the developer profile on the device if iOS asks
   (**Settings → General → VPN & Device Management**).
3. Open GymMane and complete onboarding.

Refresh the app in AltStore at least every **7 days**. Keep AltServer running
(or reconnect USB) when you refresh.

## Optional: run on device from Xcode instead

Open `ios/Runner.xcworkspace`, set your personal Team on **Runner**,
**GymManeWidgets**, and **GymManeShare**, then:

```bash
flutter run -d <your-iphone>
```

Free teams still hit the same App Group / extension limits. Prefer the AltStore
IPA path if Xcode signing fails on the extensions.

## Troubleshooting

- **Where is AltServer in the repo?** — It isn’t. Only the IPA script and docs
  live here; AltServer comes from [altstore.io](https://altstore.io).
- **Install failed / too many App IDs** — Free accounts have a low App ID cap.
  Remove unused sideloaded apps in AltStore, or delete old App IDs at
  [developer.apple.com](https://developer.apple.com/account) (Certificates,
  Identifiers & Profiles) if you have access.
- **Widgets blank / Live Activity missing** — Expected on free ID. Use the
  in-app rest timer.
- **SPM / FlutterFramework iOS 12 vs 13 error** — Run
  `./scripts/patch_spm_ios_floor.sh` after `flutter pub get`, then rebuild.
- **Need a paid team for full widgets** — Use a paid Apple Developer membership
  and enable App Group `group.com.gymmane.app` on all three targets.
