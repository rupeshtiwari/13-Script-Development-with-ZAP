"""Globomantics training app for the ZAP demo.

A single code base with two behaviours selected by the APP_BUILD environment
variable:

  * APP_BUILD=vulnerable   -> intentionally exploitable endpoints
  * APP_BUILD=remediated   -> the same endpoints, fixed

The app is deliberately small and self-contained. It is only ever exercised by
ZAP against the local stack; it must never be exposed to an untrusted network.
"""
import html
import json
import os
import re
import secrets
import subprocess

import psycopg
from fastapi import FastAPI, Form, Request, Response
from fastapi.responses import HTMLResponse, JSONResponse, PlainTextResponse
from pymongo import MongoClient

import seed

BUILD = os.environ.get("APP_BUILD", "vulnerable").strip().lower()
VULNERABLE = BUILD != "remediated"

PG_DSN = os.environ.get(
    "PG_DSN",
    "host=postgres port=5432 dbname=globomantics user=globo password=globo",
)
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://mongo:27017")
MONGO_DB = os.environ.get("MONGO_DB", "globomantics")

app = FastAPI(title="Globomantics", docs_url=None, redoc_url=None)

mongo = MongoClient(MONGO_URI, serverSelectionTimeoutMS=3000)
mdb = mongo[MONGO_DB]

# In-memory session + CSRF state. Fine for a single-process demo.
SESSIONS: dict[str, str] = {}          # session_id -> username
CSRF_TOKENS: dict[str, dict] = {}      # token -> {"session": sid, "used": bool}


def pg_conn():
    return psycopg.connect(PG_DSN)


@app.on_event("startup")
def _startup() -> None:
    seed.seed_all()


@app.get("/health")
def health() -> JSONResponse:
    status = {"build": BUILD, "vulnerable": VULNERABLE}
    try:
        with pg_conn() as c, c.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
        status["postgres"] = "ok"
    except Exception as exc:  # noqa: BLE001
        status["postgres"] = f"error: {exc}"
    try:
        mongo.admin.command("ping")
        status["mongo"] = "ok"
    except Exception as exc:  # noqa: BLE001
        status["mongo"] = f"error: {exc}"
    ok = status.get("postgres") == "ok" and status.get("mongo") == "ok"
    return JSONResponse(status, status_code=200 if ok else 503)


@app.get("/", response_class=HTMLResponse)
def index() -> str:
    return (
        "<html><head><title>Globomantics</title></head><body>"
        "<h1>Globomantics Portal</h1>"
        "<ul>"
        '<li><a href="/search?q=Router">Product search</a></li>'
        '<li><a href="/api/account?username=alice">Account lookup</a></li>'
        '<li><a href="/admin/ping?host=127.0.0.1">Admin ping</a></li>'
        '<li><a href="/greet?name=Globomantics">Greeting</a></li>'
        '<li><a href="/account/email">Change email</a></li>'
        "</ul></body></html>"
    )


# ---------------------------------------------------------------------------
# 1. SQL injection — product search (PostgreSQL)
# ---------------------------------------------------------------------------
@app.get("/search", response_class=HTMLResponse)
def search(q: str = "") -> str:
    rows = []
    error = None
    try:
        with pg_conn() as c, c.cursor() as cur:
            if VULNERABLE:
                # VULNERABLE: query built by string concatenation.
                sql = (
                    "SELECT name, category, price FROM products "
                    "WHERE name ILIKE '%" + q + "%'"
                )
                cur.execute(sql)
            else:
                # REMEDIATED: parameterized query.
                cur.execute(
                    "SELECT name, category, price FROM products "
                    "WHERE name ILIKE %s",
                    ("%" + q + "%",),
                )
            rows = cur.fetchall()
    except Exception as exc:  # noqa: BLE001
        error = str(exc)
    items = "".join(
        f"<li>{html.escape(str(r[0]))} — {html.escape(str(r[1]))} — "
        f"${html.escape(str(r[2]))}</li>"
        for r in rows
    )
    body = f"<h1>Results for {html.escape(q)}</h1><ul>{items}</ul>"
    if error:
        # Surfacing the DB error message aids ZAP's error-based SQLi detection.
        body += f"<pre>{html.escape(error)}</pre>"
    return f"<html><head><title>Search</title></head><body>{body}</body></html>"


# ---------------------------------------------------------------------------
# 2. NoSQL injection — account lookup (MongoDB)
# ---------------------------------------------------------------------------
# Matches qs-style bracket notation such as "username[$ne]".
_OP_KEY_RE = re.compile(r"^(?P<field>[^\[]+)\[(?P<op>\$[a-zA-Z]+)\]$")
_PROJECTION = {"_id": 0, "username": 1, "email": 1, "role": 1}


@app.get("/api/account")
def account(request: Request) -> JSONResponse:
    params = request.query_params
    try:
        if VULNERABLE:
            # VULNERABLE: the query string is parsed qs-style, so an attacker
            # can smuggle MongoDB operators through the parameter name, e.g.
            #   /api/account?username[$ne]=
            #   /api/account?username[$regex]=.*
            # which turns an equality lookup into an operator query and returns
            # accounts that should not match — classic NoSQL operator injection.
            username_filter: object = ""
            for key, value in params.multi_items():
                m = _OP_KEY_RE.match(key)
                if m and m.group("field") == "username":
                    if not isinstance(username_filter, dict):
                        username_filter = {}
                    username_filter[m.group("op")] = value
                elif key == "username" and not isinstance(username_filter, dict):
                    username_filter = value
            docs = list(mdb.users.find({"username": username_filter}, _PROJECTION))
        else:
            # REMEDIATED: only ever treat username as a plain string and match
            # for equality; operator smuggling via the parameter name is ignored.
            username = params.get("username", "")
            if not isinstance(username, str):
                return JSONResponse({"error": "invalid username"}, status_code=400)
            docs = list(mdb.users.find({"username": username}, _PROJECTION))
        return JSONResponse({"accounts": docs, "count": len(docs)})
    except Exception as exc:  # noqa: BLE001
        return JSONResponse({"error": str(exc)}, status_code=500)


# ---------------------------------------------------------------------------
# 3. Command injection — admin ping diagnostic
# ---------------------------------------------------------------------------
_HOST_RE = re.compile(r"^[A-Za-z0-9.-]{1,253}$")


@app.get("/admin/ping", response_class=PlainTextResponse)
def admin_ping(host: str = "127.0.0.1") -> Response:
    if VULNERABLE:
        # VULNERABLE: host interpolated into a shell command (shell=True).
        cmd = "ping -c 1 " + host
        try:
            out = subprocess.run(
                cmd, shell=True, capture_output=True, timeout=15, text=True
            )
            return PlainTextResponse(out.stdout + out.stderr)
        except Exception as exc:  # noqa: BLE001
            return PlainTextResponse(f"error: {exc}", status_code=500)
    else:
        # REMEDIATED: validate input and pass args as a list, no shell.
        if not _HOST_RE.match(host):
            return PlainTextResponse("invalid host", status_code=400)
        try:
            out = subprocess.run(
                ["ping", "-c", "1", host],
                shell=False,
                capture_output=True,
                timeout=15,
                text=True,
            )
            return PlainTextResponse(out.stdout + out.stderr)
        except Exception as exc:  # noqa: BLE001
            return PlainTextResponse(f"error: {exc}", status_code=500)


# ---------------------------------------------------------------------------
# 4. Reflected XSS — three contexts
# ---------------------------------------------------------------------------
@app.get("/greet", response_class=HTMLResponse)
def greet(name: str = "friend") -> str:
    if VULNERABLE:
        # VULNERABLE: raw reflection into HTML body, an HTML attribute, and a
        # JavaScript string literal.
        body_ctx = name
        attr_ctx = name
        js_ctx = name
    else:
        # REMEDIATED: context-appropriate encoding for each sink.
        body_ctx = html.escape(name)
        attr_ctx = html.escape(name, quote=True)
        js_ctx = json.dumps(name)[1:-1]  # escape for a JS string literal

    return (
        "<html><head><title>Greeting</title></head><body>"
        f"<p>Hello {body_ctx}</p>"
        f'<input type="text" value="{attr_ctx}">'
        f'<script>var greeting = "{js_ctx}"; </script>'
        "</body></html>"
    )


# ---------------------------------------------------------------------------
# 5. CSRF — login + email change
# ---------------------------------------------------------------------------
def _issue_csrf(sid: str) -> str:
    token = secrets.token_hex(16)
    CSRF_TOKENS[token] = {"session": sid, "used": False}
    return token


@app.post("/login")
def login(response: Response, username: str = Form("alice")) -> JSONResponse:
    sid = secrets.token_hex(16)
    SESSIONS[sid] = username
    resp = JSONResponse({"status": "logged in", "username": username})
    resp.set_cookie("session", sid, httponly=True, samesite="lax")
    return resp


@app.get("/account/email", response_class=HTMLResponse)
def email_form(request: Request) -> HTMLResponse:
    sid = request.cookies.get("session", "")
    if sid not in SESSIONS:
        return HTMLResponse("<p>Please log in first.</p>", status_code=401)
    token = _issue_csrf(sid)
    html_body = (
        "<html><head><title>Change email</title></head><body>"
        "<h1>Change email</h1>"
        '<form method="POST" action="/account/email">'
        f'<input type="hidden" name="csrf_token" value="{token}">'
        '<input type="email" name="email" value="">'
        '<button type="submit">Update</button>'
        "</form></body></html>"
    )
    return HTMLResponse(html_body)


@app.post("/account/email")
def change_email(
    request: Request,
    email: str = Form(...),
    csrf_token: str = Form(""),
) -> JSONResponse:
    sid = request.cookies.get("session", "")
    if sid not in SESSIONS:
        return JSONResponse({"error": "not authenticated"}, status_code=401)

    record = CSRF_TOKENS.get(csrf_token)

    # A token must exist and be structurally valid in every build.
    if record is None:
        return JSONResponse({"error": "invalid csrf token"}, status_code=403)

    if VULNERABLE:
        # VULNERABLE: token presence/validity is checked, but tokens are NOT
        # single-use and are NOT bound to the submitting session. So a reused
        # token still works, and session A's token works with session B's
        # cookie.
        pass
    else:
        # REMEDIATED: token must belong to this session and be unused.
        if record["session"] != sid:
            return JSONResponse({"error": "csrf token/session mismatch"}, status_code=403)
        if record["used"]:
            return JSONResponse({"error": "csrf token already used"}, status_code=403)
        record["used"] = True

    SESSIONS[sid + ":email"] = email
    return JSONResponse({"status": "email updated", "email": email})
