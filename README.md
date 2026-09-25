# GymMane

- `android/` is the Android app.
- `ios/` is the iOS app, including the Live Activity rest timer.
  - Simulator / Xcode (tested through iOS 27): [ios/README.md](ios/README.md)
  - Free-ID sideload: download **AltServer** from
    [altstore.io](https://altstore.io) (not in this repo), then:
    ```bash
    cd ios && ./scripts/build_altstore_ipa.sh
    # → build/ios/ipa/GymMane.ipa  → install via AltStore on the phone
    ```
    Details: [ios/docs/SIDELOAD.md](ios/docs/SIDELOAD.md)
- `web/` is the web app. Sign-in, Docker, and `.env.example` live there.
