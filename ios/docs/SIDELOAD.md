# Sideload GymMane with AltServer (free Apple ID)

Use this when you do not have a paid Apple Developer Program membership.
AltStore resigns the IPA with your Apple ID. Free accounts get a **7-day**
certificate — refresh from AltStore while AltServer is running on your Mac.

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

## Build the IPA

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

## Install with AltServer / AltStore

1. Install [AltServer](https://altstore.io) on this Mac and start it (menu bar).
2. Install **AltStore** on your iPhone (USB or Wi‑Fi via AltServer).
3. Sign in to AltStore with the **same free Apple ID** you use for sideloading.
4. In AltStore: **My Apps** → **+** → choose `build/ios/ipa/GymMane.ipa`.
5. Trust the developer profile on the device if iOS asks
   (**Settings → General → VPN & Device Management**).
6. Open GymMane and complete onboarding.

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
