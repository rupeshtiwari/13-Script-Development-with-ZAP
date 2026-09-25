# Validate Injection, XSS, and CSRF with ZAP

A hands-on lab where you turn a broad ZAP scan into a set of **targeted, proven
security checks** against one deliberately vulnerable application — the
Globomantics training app.

---

## The problem you are solving

A default ZAP scan gives you a long list of alerts, but a list is not a
decision. Which alerts are real? Which are noise? Can you *reproduce* each one
against the application's actual behavior? Security engineer **Maya Chen** at
Globomantics needs to answer exactly that: confirm injection, XSS, and CSRF
findings against concrete application behavior — not just trust the scanner.

**What you gain in this lab:** by the end you can build a focused scan policy,
prove three injection findings and a reflected-XSS finding are real, show why a
weak CSRF protection fails, and write down a defensible disposition for every
alert. These are the skills that separate "I ran a scanner" from "I validated
the risk."

> **Authorization and scope.** Every request in this lab targets **only** the
> local Globomantics training app on your machine. Never point these techniques
> at any system you are not explicitly authorized to test.

---

## What each step teaches (learning-objective coverage)

| Step | You will… | Objective |
|------|-----------|-----------|
| 1 | Build a scan policy scoped to exactly the rules you want | EO1a |
| 2 | Prove SQL injection on the product-search parameter | EO1a |
| 3 | Prove NoSQL injection on the account lookup | EO1a |
| 4 | Prove OS command injection on the admin diagnostic | EO1a |
| 5 | Map reflected XSS to its three output contexts | EO1b |
| 6 | Compare five CSRF token states and find the two that fail | EO1c |
| 7 | Record a disposition for every alert you observed | EO1a · EO1b · EO1c |

---

## Before you start

1. Prepare your machine once:
   ```bash
   ./env-setup/setup-macos.sh
   ```
   Wait for the readiness table to show every component **READY**.

2. Bring the lab up (starts on the vulnerable build):
   ```bash
   ./module1/m1-demo1-validate-injection-xss-and-csrf-with-zap/scripts/demo_up.sh
   ```
   When it prints **Up**, open the ZAP GUI at <http://localhost:8080/zap/> and
   set your browser's HTTP proxy to `localhost:8090` so traffic flows through
   ZAP.

3. To return to a clean starting point at any time:
   ```bash
   ./module1/m1-demo1-validate-injection-xss-and-csrf-with-zap/scripts/demo_reset.sh
   ```

Throughout, `APP` is `http://app:8000` as ZAP sees it on the container network.

---

## Step 1 — Build the targeted scan policy

**Why you run this:** a broad scan wastes time and buries the findings you care
about. A scoped policy is the difference between "scan everything" and "test
these specific weaknesses."
**What you learn:** how a scan policy is assembled from individual rule IDs, and
which rules map to which weakness.

Enable only the SQL-injection family, the NoSQL rule `40033`, and the two
command-injection rules in a policy named `m1demo1`, then list what is enabled.

```
┌──────────────────────────────────────────────────────────────────────┐
│ WHAT:  The exact scan rules this policy enables — and nothing else     │
│ WHY:   A focused policy turns a broad scan into a targeted test (EO1a)  │
└──────────────────────────────────────────────────────────────────────┘

  ★ Enabled scan rules: 40018 40019 40020 40021 40022 40027 40033 90020 90037
```

The highlighted rule IDs are the ones this lab proves: **40018/40022** (SQL),
**40033** (NoSQL), **90020/90037** (command injection).

**Proof artifact:** *Configured targeted scan policy and rule list.*

---

## Step 2 — Validate SQL injection on product search

**Why you run this:** the product search builds its query from your input, so a
crafted value can change the query itself.
**What you learn:** how ZAP confirms SQL injection from the application's own
response, and how to read the alert's risk and confidence.

Active-scan `GET ${APP}/search?q=Router` with the policy, then read the alert.

```
┌──────────────────────────────────────────────────────────────────────┐
│ WHAT:  ZAP alert raised on the product-search parameter                │
│ WHY:   Confirms the SQL-injection finding is real behavior (EO1a)      │
└──────────────────────────────────────────────────────────────────────┘

  ★ pluginId: 40018

  ★ risk: High

  ★ confidence: Medium

  ★ param: q
```

Read the **pluginId** and **confidence** aloud: alert `40018` on parameter `q`.

**Proof artifact:** contributes to *Configured targeted scan policy and rule list.*

---

## Step 3 — Validate NoSQL injection on account lookup

**Why you run this:** the account lookup queries MongoDB. If the parameter can
smuggle a query operator, an equality check becomes an "any account" match.
**What you learn:** to see NoSQL injection as a **behavior change** first, then
confirm it with ZAP's dedicated rule `40033`.

Compare a normal lookup with an operator-injection lookup, then scan the endpoint.

```
┌──────────────────────────────────────────────────────────────────────┐
│ WHAT:  A normal lookup returns one account; an injected one returns many│
│ WHY:   Shows the MongoDB weakness as behavior, then confirms it (EO1a) │
└──────────────────────────────────────────────────────────────────────┘

  ★ Accounts for a normal lookup: 1

  ★ Accounts when an operator is injected: 4

  ★ pluginId: 40033
```

The jump from **1** to **4** is the injection; alert **40033** is ZAP's
confirmation.

**Proof artifact:** contributes to *Configured targeted scan policy and rule list.*

---

## Step 4 — Validate command injection on admin diagnostics

**Why you run this:** the admin "ping" tool runs a real OS command built from
the `host` value.
**What you learn:** how ZAP detects that untrusted input reached a shell, and
which rule reports it.

Active-scan `GET ${APP}/admin/ping?host=127.0.0.1`, then read the alert.

```
┌──────────────────────────────────────────────────────────────────────┐
│ WHAT:  ZAP alert raised on the admin ping host parameter               │
│ WHY:   Confirms untrusted input reaches an OS command (EO1a)           │
└──────────────────────────────────────────────────────────────────────┘

  ★ pluginId: 90037

  ★ risk: High

  ★ confidence: Medium

  ★ param: host
```

Read the **pluginId**: command-injection alert `90037` on parameter `host`.
(`90020` detects the same weakness; either is a valid confirmation.)

**Proof artifact:** contributes to *Configured targeted scan policy and rule list.*

---

## Step 5 — Map reflected XSS to its three output contexts

**Why you run this:** the payload that works for XSS depends on *where* your
input lands in the page. The same value behaves differently in an HTML body, an
HTML attribute, and a JavaScript string.
**What you learn:** to identify the output context first, because it decides the
payload you would use.

Send a harmless marker to `GET ${APP}/greet?name=zzMARKzz` and see where it
lands, unescaped, in the response.

```
┌──────────────────────────────────────────────────────────────────────┐
│ WHAT:  The same marker echoed into three different output contexts     │
│ WHY:   The context decides the payload — this is why it matters (EO1b) │
└──────────────────────────────────────────────────────────────────────┘

  ★ HTML body context: <p>Hello zzMARKzz

  ★ HTML attribute context: value="zzMARKzz"

  ★ JavaScript string context: var greeting = "zzMARKzz"
```

All three reflect the marker unescaped — three different contexts, one input.

**Proof artifact:** *XSS request and response body.*

---

## Step 6 — Compare CSRF token states

**Why you run this:** a CSRF token is only as good as its rules. A token that is
checked for *presence* but not for *freshness* or *session ownership* still
leaves the form exploitable.
**What you learn:** to test a protection by its state transitions, and to spot
which two states reveal the real weakness.

Log in, then submit the email-change form under five token states and read the
HTTP status code for each.

```
┌──────────────────────────────────────────────────────────────────────┐
│ WHAT:  The same request under five CSRF token states                   │
│ WHY:   The two that still succeed reveal the real weakness (EO1c)      │
└──────────────────────────────────────────────────────────────────────┘

  ★ valid token, own session: 200

  ★ missing token: 403

  ★ invalid token: 403

  ★ token reused after first use: 200

  ★ session A token with session B cookie: 200
```

Presence is checked (missing and invalid are both `403`), but the two
highlighted `200`s show the token is **not single-use** and **not bound to the
session** — the weakness this endpoint hides.

**Proof artifact:** *CSRF token-state comparison.*

---

## Step 7 — Record the alert disposition

**Why you run this:** validation ends in a decision. A disposition is what you
hand to a developer or keep for the record.
**What you learn:** to reconcile each alert with what the application actually
did and mark it confirmed or a false positive.

```
┌──────────────────────────────────────────────────────────────────────┐
│ WHAT:  Each alert reconciled with observed application behavior        │
│ WHY:   Turns raw alerts into decisions you can defend (EO1a/b/c)       │
└──────────────────────────────────────────────────────────────────────┘

  ★ SQL injection (40018/40022) on /search: confirmed

  ★ NoSQL injection (40033) on /api/account: confirmed

  ★ Command injection (90020/90037) on /admin/ping: confirmed

  ★ Reflected XSS on /greet: confirmed
```

Fill in the full table in [`docs/alert-disposition-template.md`](../../docs/alert-disposition-template.md).

**Proof artifact:** *Alert disposition record.*

---

## Check your work

Run the validator; it walks these seven steps, proves each one, and writes a
readable log to `logs/`:

```bash
./scripts/preflight_check.sh
```

Every step prints **PASS** or **FAIL**. On a failure it prints the reason and a
prompt you can use to fix it. When you are done:

```bash
./scripts/demo_down.sh
```

---

## See the fixes hold (optional exploration)

The same application ships a remediated build where the query is parameterized,
the Mongo lookup treats input as a plain string, the command validates its
input, XSS output is context-encoded, and CSRF tokens are single-use and
session-bound:

```bash
APP_BUILD=remediated docker compose up -d --build app
```

Re-run the steps and watch the injection alerts disappear, the XSS output become
encoded, and the two CSRF `200`s become `403`.
