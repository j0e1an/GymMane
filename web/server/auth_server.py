"""Serve the GymMane web build behind Google sign-in.

Secrets come from the environment (Docker injects them from .env).
The Google client secret never goes into the browser.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SESSION_COOKIE = "gymmane_session"
STATE_COOKIE = "gymmane_oauth_state"
SESSION_SECONDS = 14 * 24 * 60 * 60
STATE_SECONDS = 10 * 60


def _required(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"{name} is empty. Set it in .env before starting.")
    return value


def config() -> dict:
    base = _required("PUBLIC_BASE_URL").rstrip("/")
    return {
        "client_id": _required("GOOGLE_CLIENT_ID"),
        "client_secret": _required("GOOGLE_CLIENT_SECRET"),
        "public_base_url": base,
        "session_secret": _required("SESSION_SECRET"),
        "redirect_uri": f"{base}/auth/callback",
        "secure": base.startswith("https://"),
        "web_root": Path(os.environ.get("WEB_ROOT", "/app/web")).resolve(),
        "port": int(os.environ.get("PORT", "8080") or "8080"),
    }


def _b64(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")


def _b64decode(text: str) -> bytes:
    pad = "=" * (-len(text) % 4)
    return base64.urlsafe_b64decode(text + pad)


def sign(payload: dict, secret: str) -> str:
    body = _b64(json.dumps(payload, separators=(",", ":")).encode())
    mac = hmac.new(secret.encode(), body.encode(), hashlib.sha256).digest()
    return f"{body}.{_b64(mac)}"


def unsign(token: str, secret: str) -> dict | None:
    parts = token.split(".")
    if len(parts) != 2:
        return None
    body, sig = parts
    expected = hmac.new(secret.encode(), body.encode(), hashlib.sha256).digest()
    try:
        got = _b64decode(sig)
    except Exception:
        return None
    if not hmac.compare_digest(expected, got):
        return None
    try:
        data = json.loads(_b64decode(body))
    except Exception:
        return None
    return data if isinstance(data, dict) else None


def _cookies(header: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in header.split(";"):
        if "=" not in part:
            continue
        key, value = part.strip().split("=", 1)
        out[key] = value
    return out


def _cookie(name: str, value: str, max_age: int, secure: bool) -> str:
    bits = [
        f"{name}={value}",
        "HttpOnly",
        "Path=/",
        "SameSite=Lax",
        f"Max-Age={max_age}",
    ]
    if secure:
        bits.append("Secure")
    return "; ".join(bits)


def _clear_cookie(name: str, secure: bool) -> str:
    return _cookie(name, "", 0, secure)


LOGIN_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sign in · GymMane</title>
  <meta name="theme-color" content="#0A0908">
  <style>
    body { margin: 0; min-height: 100vh; display: grid; place-items: center;
      background: #0A0908; color: #fff; font-family: Nunito, sans-serif; }
    main { width: min(420px, calc(100% - 48px)); text-align: center; }
    h1 { font-weight: 800; font-size: 40px; margin: 0 0 8px; }
    p { color: #9A9A9A; line-height: 1.45; margin: 0 0 28px; }
    a { display: block; background: #fff; color: #1A1713; text-decoration: none;
      font-weight: 700; border-radius: 14px; padding: 16px; }
  </style>
</head>
<body>
  <main>
    <h1>GymMane</h1>
    <p>This browser keeps your log only after you sign in with Google.</p>
    <a href="/auth/login">Continue with Google</a>
  </main>
</body>
</html>
"""


def _google_user(code: str, cfg: dict) -> dict:
    form = urllib.parse.urlencode({
        "code": code,
        "client_id": cfg["client_id"],
        "client_secret": cfg["client_secret"],
        "redirect_uri": cfg["redirect_uri"],
        "grant_type": "authorization_code",
    }).encode()
    token_req = urllib.request.Request(
        "https://oauth2.googleapis.com/token",
        data=form,
        method="POST",
    )
    with urllib.request.urlopen(token_req, timeout=15) as resp:
        token = json.load(resp)
    access = token.get("access_token")
    if not access:
        raise RuntimeError("no access token")
    info_req = urllib.request.Request(
        "https://www.googleapis.com/oauth2/v3/userinfo",
        headers={"Authorization": f"Bearer {access}"},
    )
    with urllib.request.urlopen(info_req, timeout=15) as resp:
        info = json.load(resp)
    sub = info.get("sub")
    if not isinstance(sub, str) or not sub:
        raise RuntimeError("no subject")
    return info


class Handler(BaseHTTPRequestHandler):
    cfg: dict = {}
    server_version = "GymMane"

    def log_message(self, fmt: str, *args) -> None:
        path = self.path.split("?", 1)[0]
        print(f"{self.address_string()} {self.command} {path}")

    def do_HEAD(self) -> None:
        self.do_GET(head=True)

    def do_GET(self, head: bool = False) -> None:
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        if path == "/auth/login":
            self._login()
            return
        if path == "/auth/callback":
            self._callback(urllib.parse.parse_qs(parsed.query))
            return
        if path == "/auth/logout":
            self._logout()
            return
        if path == "/auth/me":
            self._me()
            return
        if self._account() is None:
            if path == "/":
                self._html(200, LOGIN_PAGE, head)
            else:
                self._text(401, "Sign in required", head)
            return
        self._file(path, head)

    def _account(self) -> dict | None:
        raw = _cookies(self.headers.get("Cookie", "")).get(SESSION_COOKIE, "")
        data = unsign(raw, self.cfg["session_secret"]) if raw else None
        if not data:
            return None
        sub = data.get("sub")
        exp = data.get("exp")
        if not isinstance(sub, str) or not sub:
            return None
        if not isinstance(exp, int) or exp < _now():
            return None
        return data

    def _login(self) -> None:
        if self._account() is not None:
            self._redirect("/")
            return
        state = secrets.token_urlsafe(32)
        query = urllib.parse.urlencode({
            "client_id": self.cfg["client_id"],
            "redirect_uri": self.cfg["redirect_uri"],
            "response_type": "code",
            "scope": "openid email profile",
            "state": state,
            "prompt": "select_account",
        })
        self._redirect(
            f"https://accounts.google.com/o/oauth2/v2/auth?{query}",
            extra=[_cookie(STATE_COOKIE, state, STATE_SECONDS, self.cfg["secure"])],
        )

    def _callback(self, query: dict) -> None:
        if query.get("error"):
            self._text(400, "Google sign-in was cancelled.")
            return
        code = (query.get("code") or [""])[0]
        state = (query.get("state") or [""])[0]
        saved = _cookies(self.headers.get("Cookie", "")).get(STATE_COOKIE, "")
        if not code or not state or not saved or not hmac.compare_digest(state, saved):
            self._text(400, "Sign-in could not be verified. Try again.")
            return
        try:
            info = _google_user(code, self.cfg)
        except (urllib.error.URLError, RuntimeError, json.JSONDecodeError, TimeoutError):
            self._text(502, "Google sign-in failed. Try again.")
            return
        payload = {
            "sub": info["sub"],
            "email": info.get("email") if isinstance(info.get("email"), str) else "",
            "name": info.get("name") if isinstance(info.get("name"), str) else "",
            "exp": _now() + SESSION_SECONDS,
        }
        token = sign(payload, self.cfg["session_secret"])
        self._redirect("/", extra=[
            _cookie(SESSION_COOKIE, token, SESSION_SECONDS, self.cfg["secure"]),
            _clear_cookie(STATE_COOKIE, self.cfg["secure"]),
        ])

    def _logout(self) -> None:
        self._redirect("/", extra=[_clear_cookie(SESSION_COOKIE, self.cfg["secure"])])

    def _me(self) -> None:
        account = self._account()
        if account is None:
            self._json(401, {"error": "unauthorized"})
            return
        self._json(200, {
            "sub": account["sub"],
            "email": account.get("email") or "",
            "name": account.get("name") or "",
        })

    def _file(self, url_path: str, head: bool) -> None:
        root = self.cfg["web_root"]
        rel = url_path.lstrip("/") or "index.html"
        candidate = (root / rel).resolve()
        if root != candidate and root not in candidate.parents:
            self._text(403, "Forbidden", head)
            return
        if candidate.is_dir():
            candidate = (candidate / "index.html").resolve()
        if not candidate.is_file():
            fallback = (root / "index.html").resolve()
            if fallback.is_file() and "." not in Path(rel).name:
                candidate = fallback
            else:
                self._text(404, "Not found", head)
                return
        data = b"" if head else candidate.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", _mime(candidate.suffix))
        self.send_header("Content-Length", str(candidate.stat().st_size if head else len(data)))
        self.send_header("Cache-Control", "private, no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        if not head:
            self.wfile.write(data)

    def _redirect(self, location: str, extra: list[str] | None = None) -> None:
        self.send_response(302)
        self.send_header("Location", location)
        self.send_header("Cache-Control", "no-store")
        for cookie in extra or []:
            self.send_header("Set-Cookie", cookie)
        self.end_headers()

    def _html(self, status: int, body: str, head: bool = False) -> None:
        raw = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        if not head:
            self.wfile.write(raw)

    def _text(self, status: int, body: str, head: bool = False) -> None:
        raw = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if not head:
            self.wfile.write(raw)

    def _json(self, status: int, body: dict) -> None:
        raw = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)


def _now() -> int:
    import time
    return int(time.time())


def _mime(suffix: str) -> str:
    return {
        ".html": "text/html; charset=utf-8",
        ".js": "text/javascript; charset=utf-8",
        ".css": "text/css; charset=utf-8",
        ".json": "application/json",
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".svg": "image/svg+xml",
        ".wasm": "application/wasm",
        ".ico": "image/x-icon",
        ".txt": "text/plain; charset=utf-8",
        ".woff2": "font/woff2",
        ".ttf": "font/ttf",
    }.get(suffix.lower(), "application/octet-stream")


def main() -> None:
    cfg = config()
    Handler.cfg = cfg
    if not cfg["web_root"].is_dir():
        raise SystemExit(f"Web build not found at {cfg['web_root']}")
    server = ThreadingHTTPServer(("0.0.0.0", cfg["port"]), Handler)
    print(f"GymMane listening on {cfg['port']}")
    server.serve_forever()


if __name__ == "__main__":
    main()
