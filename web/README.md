# GymMane on the web

The browser app is the Flutter project, not a separate product. It has the body
map, set logging, routines, progress, and the exercise catalog. Workouts stay
in this browser. Only the Google address in `ALLOWED_GOOGLE_EMAIL` can sign in.
That account's log stays in this browser.

Home-screen widgets, Wear OS, and the live workout notification stay on the
phone. The Android and iOS apps do not ask for a Google account.

The site is public, so the container does not serve the gym UI until Google
sign-in succeeds. `GOOGLE_CLIENT_SECRET` is read only by the server.

## Configure

From the `web` directory:

```bash
cp .env.example .env
```

Fill in `.env`. Leave the file uncommitted.

| Variable | Empty in `.env.example` | What to put |
| --- | --- | --- |
| `GOOGLE_CLIENT_ID` | yes | OAuth web client id |
| `GOOGLE_CLIENT_SECRET` | yes | OAuth web client secret |
| `PUBLIC_BASE_URL` | yes | Public origin, no trailing slash. Local: `http://localhost:8080` |
| `SESSION_SECRET` | yes | Long random string, for example `openssl rand -hex 32` |
| `ALLOWED_GOOGLE_EMAIL` | yes | The one Google address allowed to sign in. The server rejects every other account. |
| `PORT` | yes | Host port. Empty uses `8080` |

In Google Cloud Console, create an OAuth client of type **Web application**.
Add this authorized redirect URI, using the same origin as `PUBLIC_BASE_URL`:

```text
http://localhost:8080/auth/callback
```

For a public host, use `https://your-domain/auth/callback` and set
`PUBLIC_BASE_URL` to `https://your-domain`.

## Build and run the container

```bash
docker compose up --build
```

Run that in the `web` directory, next to `Dockerfile` and `.env`.

Open `http://localhost:8080` (or whatever `PORT` you set). You should see
**Continue with Google** before any gym screen. After Google returns the
account, sign-in continues only when that address matches
`ALLOWED_GOOGLE_EMAIL`. The log is stored in this browser for that account.
Sign out from Settings.

`docker compose` reads `.env` and passes those variables into the container.
The image does not contain `.env`.

Stop it with `docker compose down`.

The image builds the Flutter web release with Flutter 3.41.9 (Dart 3.11.5,
the SDK in `.metadata`), then serves `build/web` with `server/auth_server.py`.
The service worker is omitted so a cached copy cannot skip sign-in.

## Run the Flutter UI without the container

This does not perform Google sign-in. The app asks `/auth/me` and stays on the
sign-in screen unless the container is the thing serving it.

```bash
flutter pub get
flutter run -d chrome
```

Use the container when you want the real sign-in flow.

Training reminders and progress-photo reminders use the browser's notifications.
The site asks for permission when you save a training reminder, change the photo
interval, or start a rest. Rest-over also posts through a service worker so it
can show outside the tab. While the tab is open, the rest sound still plays in
the page. Vibrate uses the Vibration API. Timed-hold ticks use Web Audio. Keep
screen on uses the Screen Wake Lock API during a session. On a phone, Take photo
opens the camera. On a desktop, that control picks a file. Gallery upload is
unchanged. Home-screen widgets, Wear OS, and the live workout notification are
not part of the web app. Import reads a file you pick. It does not receive
Android share intents.
