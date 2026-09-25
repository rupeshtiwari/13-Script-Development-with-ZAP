# Alert Disposition Template

Use one row per ZAP alert observed during the demo. "Disposition" is the
triage decision: **True Positive**, **False Positive**, or **Accepted Risk**.
"Evidence" is what proves the call — the payload, the response, or the fix.

| Alert ID | Rule | Endpoint | Disposition | Evidence |
|----------|------|----------|-------------|----------|
| 40018 | SQL Injection (PostgreSQL) | `GET /search?q=` | True Positive | Injected `q=Router'` → `unterminated quoted string` DB error; parameterized query in the remediated build returns HTTP 200 with no error |
| 40033 | NoSQL Injection - MongoDB | `GET /api/account?username=` | True Positive | `username[$ne]=` returns all 4 accounts vs 1 for the baseline; remediated build treats `username` as a string only (count=0) |
| 90020 | Remote OS Command Injection | `GET /admin/ping?host=` | True Positive | `host=127.0.0.1;id` runs `id` (uid output); remediated build rejects the value (HTTP 400) and drops `shell=True` |
| 90037 | Remote OS Command Injection (Time Based) | `GET /admin/ping?host=` | True Positive | Time-based payload delays the response; remediated build validates the host and uses an argv list |
| 40012/40014/40016/40017 | Cross Site Scripting (Reflected) | `GET /greet?name=` | True Positive | Marker reflected unescaped in HTML body, HTML attribute, and JS string; remediated build encodes each context |
| _add rows as needed_ | | | | |

## Notes
- The scan policy is scoped to the SQL-injection family, NoSQL rule 40033, and
  command-injection rules 90020/90037, so unrelated rules are out of scope.
- Passive header alerts (e.g. 10020, 10021, 10038, 10024) are expected on a demo
  app and are outside the scope of this exercise unless you choose to discuss them.
