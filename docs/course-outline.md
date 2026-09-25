# Script Development with ZAP — Approved Video Course Outline

> Source of truth for this course. Outline template version: March 9, 2020.
> Outline deadline: 2026-08-27 · Outline approved: 2026-08-27

## Course Information

| Field | Value |
|---|---|
| Course title | Script Development with ZAP |
| Author | Rupesh Tiwari |
| Opportunity ID | 52ec2e92-c06e-4009-8425-23fac289dc18 |
| Skill path | Zed Attack Proxy (ZAP) |
| Path placement | 3 |
| Content tags | Penetration testing; OWASP ZAP; Web application penetration testing |
| Length (estimate) | 45 minutes |
| Content level | Entry-Level |

## Course Planning

### Learner Profile

Application security engineers, penetration testers, developers, and DevSecOps practitioners who know basic web security concepts and want to customize ZAP beyond default scans. Learners need practical skills for targeted vulnerability testing, scripting, authenticated workflows, and CI/CD integration.

### Learner Prerequisites

- Basic understanding of HTTP requests and responses
- Basic familiarity with common web vulnerabilities such as injection, XSS, and CSRF
- Comfort using a terminal, editing text files, and writing simple JavaScript or Python
- Basic awareness of CI/CD pipelines and build quality gates
- Basic familiarity with ZAP alerts, scan policies, and running a standard ZAP scan

### Storyline

Globomantics security engineer **Maya Chen** is responsible for protecting a deliberately vulnerable training web application with search, account, authentication, and administrative workflows. Maya first narrows ZAP scans to validate injection, XSS, and CSRF findings against concrete application behavior, then writes custom JavaScript and Python security scripts for authenticated checks, and finally runs those same custom checks through a GitHub Actions workflow on a hosted runner. All testing remains confined to the Globomantics course training application under written authorization, giving learners one continuous path from focused testing to scripted automation and CI/CD quality gates.

### Platform/Tool Versions

| Technology | Version(s) | Pre-release? |
|---|---|---|
| ZAP | 2.17.0 recording baseline; verify `:stable` core version at recording time | N |
| ZAP stable Docker image | `ghcr.io/zaproxy/zaproxy:stable` | N |
| Automation Framework add-on | 0.60.0 beta (verify at recording time) | Y |
| Script Console add-on | 45.20.0 (verify at recording time) | N |
| GraalVM JavaScript add-on | 0.14.0 alpha (verify at recording time) | Y |
| Python Scripting add-on | 15 beta (Jython 2.7.2; verify at recording time) | Y |
| Active Scanner Rules add-on | 83 (verify at recording time) | N |
| Active scanner rules (beta) | 66 beta (verify at recording time) | Y |
| Alert Filters add-on | 27 (verify at recording time) | N |
| GitHub Actions hosted runner | ubuntu-24.04 hosted runner | N |
| Container runtime | Colima 0.10.4 | N |
| Training app language | Python | N |
| Training app framework | FastAPI | N |
| Relational database | PostgreSQL | N |
| NoSQL database | MongoDB | N |

### Additional Notes

- **GitHub repo:** github.com/rupeshtiwari/pluralsight-script-development-with-zap
- **Local demo stack:** Colima 0.10.4, Docker Compose, ZAP 2.17.0, `ghcr.io/zaproxy/zaproxy:stable`, a Python/FastAPI training application, PostgreSQL, MongoDB, JavaScript scripts using GraalVM JavaScript, and Python scripts using the ZAP Python Scripting add-on
- **Pipeline demo stack:** GitHub Actions on the ubuntu-24.04 hosted runner, ZAP Automation Framework YAML plans, ZAP API examples, reports, workflow files, and pipeline gate configuration
- **Container runtime alternative:** Rancher Desktop 1.22.3 is a free alternative to Colima; ZAP images support linux/arm64 for Apple Silicon
- **ZAP image:** `ghcr.io/zaproxy/zaproxy:stable` is a rolling tag updated on full ZAP releases and regenerated monthly with updated base image and installed add-ons; verify the image digest, ZAP core version, and bundled add-on versions at recording time
- **Add-on quality levels:** Script Console, Active scanner rules, and Alert Filters are release quality; Automation Framework, Python Scripting, and Active scanner rules (beta) are beta quality; GraalVM JavaScript is alpha quality. These are the current quality levels published for ZAP 2.17.0 and are the versions the course demonstrates
- **Python scripting:** Install the Python Scripting (jython) add-on explicitly before running Python scripts; do not assume it is installed in the ZAP container
- **Python runtime:** The ZAP Python Scripting add-on bundles Jython 2.7.2 and uses Python 2.7-compatible syntax; host-side automation uses CPython
- **NoSQL scanner:** Install Active scanner rules (beta) version 66 explicitly; NoSQL Injection - MongoDB is alert 40033 in ascanrulesBeta and is not installed by default
- **Training application:** Python with FastAPI, PostgreSQL for relational data, and MongoDB for the NoSQL injection path
- **Authorization:** All vulnerability demonstrations target only the Globomantics course training application under written authorization
- **Reusable learner assets:** Scan policies, JavaScript and Python script templates, authentication scripts, Automation Framework plans, API examples, GitHub Actions workflow files, pipeline gate configuration, and a vulnerable and a remediated build of the training application

### Short Description

Custom ZAP scripting turns generic scans into repeatable security checks for real application behavior. This course will teach you to build targeted ZAP scans, automate custom scripts, and enforce DevSecOps security gates.

### Long Description

Modern web applications often need security tests that understand application-specific inputs, authentication flows, and release criteria. In this course, Script Development with ZAP, you'll gain the ability to extend ZAP for targeted security testing and repeatable DevSecOps automation. First, you'll explore specialized injection scanners, context-specific XSS validation, and CSRF-aware testing. Next, you'll discover how to build JavaScript and Python scripts for custom ZAP behavior and authenticated security checks. Finally, you'll learn how to run ZAP headlessly, control scans through the ZAP API, and enforce threshold-based security quality gates in CI/CD pipelines. When you're finished with this course, you'll have the skills and knowledge of ZAP scripting and automation needed to build focused, repeatable web application security tests that fit modern delivery workflows.

## Learning Objectives

1. **Scanning Techniques for Specific Vulnerabilities (TO1)**
   - EO1a: Configure specialized scanners for injection vulnerabilities (SQL, NoSQL, Command)
   - EO1b: Implement Cross-Site Scripting (XSS) validation with context-specific payloads
   - EO1c: Execute CSRF token bypass techniques for testing anti-CSRF protections
2. **Utilize ZAP Scripting for Custom Security Tests (TO2)**
   - EO2a: Develop JavaScript scripts to extend ZAP functionality
   - EO2b: Implement Python scripts for custom scanning rules
   - EO2c: Apply scripting for authentication sequence automation
3. **Integrate ZAP with DevSecOps Pipelines (TO3)**
   - EO3a: Configure ZAP for headless execution in CI/CD environments
   - EO3b: Implement ZAP API for programmatic security testing
   - EO3c: Apply threshold-based quality gates for security findings in build pipelines

## Course Organization

### Module 1 – Targeted security testing and ZAP scripting (23 min)

Covers TO1 (EO1a–c) and TO2 (EO2a–c).

#### Clip 1: ZAP authorized scanning architecture and alert controls (3 min)

- Course introduction slide block: Globomantics security engineer Maya Chen must turn broad scanner output into authorized security decisions across one training application
- The alert-lifecycle spine maps rule or script raises alert → filter applied → risk and confidence assigned → report generated → gate evaluates → exit code returned
- Authorization and scope: Maya tests only the Globomantics course training application under written authorization
- Maya separates alert Risk from alert Confidence, then distinguishes scan rule Threshold from scan rule Strength before tuning focused rules
- Scan rule Threshold and pipeline gate threshold are unrelated concepts that share the word "threshold"
- Learning objectives: TO1, EO1a

#### Clip 2: ZAP scripting architecture and language boundaries (3 min)

- The Globomantics scripting path extends the alert-lifecycle spine by showing where a custom script can raise an alert before filtering, reporting, and gating occur
- Maya chooses JavaScript for message-level extension behavior, Python for a focused custom scan rule, and a separate authentication script for login sequencing
- The ZAP Python Scripting add-on bundles Jython 2.7.2 and uses Python 2.7-compatible syntax, while host-side automation uses CPython
- Learning objectives: TO2, EO2a, EO2b, EO2c

#### Clip 3: Demo: Validate injection, XSS, and CSRF with ZAP (6 min)

- Before sending payloads, Maya maps each XSS case to HTML body, attribute, or JavaScript execution context and each CSRF case to valid, missing or invalid, or replayed token state so the request tests the intended protection
- Maya creates a focused scan policy, enables the SQL injection, NoSQL Injection - MongoDB, and command-injection rules, sets rule Threshold and Strength, then runs the scan — proof artifact: **"Configured targeted scan policy and rule list"**
- For XSS, Maya runs a context-matched case and captures the exact request and response body — proof artifact: **"XSS request and response body"**
- Maya establishes a valid-token baseline, repeats the request with the token missing or invalid, then replays the captured token to test freshness and session binding — proof artifact: **"CSRF token-state comparison"**
- Maya reconciles ZAP alerts with application behavior and records the disposition — proof artifact: **"Alert disposition record"**
- Learning objectives: TO1, EO1a, EO1b, EO1c

#### Clip 4: Demo: Write a JavaScript security script in ZAP (5 min)

- Maya starts from the ZAP HTTP Sender script template, writes a JavaScript request-marker action for Globomantics, and saves it — proof artifact: **"JavaScript source file"**
- An authorized Globomantics request then passes through ZAP, where Maya confirms the script adds the marker header to the outbound message — proof artifact: **"Modified HTTP request"**
- Maya writes a fixed marker string to the console and runs the request again so the script action produces named output — proof artifact: **"Script console output"**
- Maya saves the reusable script path and name that the Automation Framework will call later — proof artifact: **"Saved script registration"**
- Learning objectives: TO2, EO2a

#### Clip 5: Demo: Write Python scan and authentication scripts in ZAP (6 min)

- Maya installs the Python Scripting (jython) add-on in the ZAP container, starts from the active-rule template, writes the Jython 2.7.2-compatible Globomantics rule, and saves it — proof artifact: **"Python active-rule source"**
- From the ZAP authentication script template, Maya writes credential submission and logged-in verification, then saves it separately — proof artifact: **"Authentication script source"**
- Maya runs scripted authentication and the custom Python rule against the authenticated Globomantics endpoint — proof artifact: **"Authenticated custom-scan result"**
- Maya runs the rule and confirms it raises the intended alert, then records its rule output for pipeline reuse — proof artifact: **"Custom alert record"**
- Learning objectives: TO2, EO2b, EO2c

### Module 2 – Automated ZAP security gates in DevSecOps pipelines (22 min)

Covers TO3 (EO3a–c).

#### Clip 1: ZAP automation architecture with GitHub Actions (3 min)

- At Globomantics, Maya maps a GitHub Actions workflow on the ubuntu-24.04 hosted runner to the ZAP container, training application, Automation Framework plan, ZAP API, report, and process exit code
- The Automation Framework environment defines the Globomantics context, authentication method, users, and target URLs; the plan then runs `passiveScan-config` → `alertFilter` → `script` → `spider` → `passiveScan-wait` → `activeScan-policy` → `activeScan` → `passiveScan-wait` (to catch active-scan traffic) → `report` → `exitStatus`
- The script job loads the JavaScript and Python scripts authored in Module 1, while the env context binds the authentication script so those same checks run against the authenticated Globomantics scope
- Learning objectives: TO3, EO3a, EO3b

#### Clip 2: ZAP gate semantics, reporting, and exitStatus (3 min)

- Maya accounts for ZAP 2.17.0 alert de-duplication when setting gate thresholds because lower duplicate counts change the baseline used for threshold tuning
- Maya distinguishes alert filtering from the exitStatus decision: filters change alert disposition, while `warnLevel` and `errorLevel` evaluate the resulting alert risks
- The default `-cmd -autorun` process result is 0 for ok, 1 for errors, and 2 for warnings, with explicit exit-value overrides available when a pipeline needs different values
- Learning objectives: TO3, EO3c

#### Clip 3: Demo: Run authenticated ZAP scripts in GitHub Actions (5 min)

- Maya runs the Globomantics GitHub Actions workflow on the ubuntu-24.04 hosted runner and starts `ghcr.io/zaproxy/zaproxy:stable` headlessly — proof artifact: **"GitHub Actions job log"**
- Maya confirms the Automation Framework env binds the Globomantics context, scripted authentication, user, and target scope before scanning — proof artifact: **"Authenticated context configuration"**
- The script job executes the Module 1 custom JavaScript and Python checks against the authenticated scope — proof artifact: **"Authenticated script job result"**
- Maya confirms the scripted rule raises the expected custom alert under the authenticated workflow — proof artifact: **"Authenticated custom alert record"**
- Learning objectives: TO3, EO3a

#### Clip 4: Demo: Query the ZAP API and inspect scan evidence (5 min)

- Maya queries the ZAP API for runtime and scan status after the authenticated workflow completes — proof artifact: **"ZAP API status response"**
- Maya queries the API for the script-generated alert and confirms its rule identity and disposition — proof artifact: **"ZAP API alert response"**
- Maya retrieves the official JSON report and reconciles its alert data with the API result — proof artifact: **"ZAP JSON report"**
- Maya reviews ZAP 2.17.0 Insights alongside the JSON report to assess scan effectiveness and operational issues — proof artifact: **"ZAP Insights evidence"**
- Learning objectives: TO3, EO3b

#### Clip 5: Demo: Enforce ZAP quality gates in GitHub Actions (6 min)

- Maya uses the `alertFilter` job to mark a known benign Globomantics finding as False Positive — proof artifact: **"False Positive alert filter"**
- Following the architecture job order, Maya confirms `alertFilter` is applied before scanning so later alerts inherit the intended disposition — proof artifact: **"Automation Framework job order"**
- Maya runs `report` and `exitStatus`, applies `warnLevel` and `errorLevel`, and reads the JSON report plus process result — proof artifact: **"Gate JSON report and exit code"**
- Course summary slide block: After the filtered alert report confirms the final disposition, Maya closes the Globomantics storyline by tracing authorized scanning, authored scripts, automated reuse, filtering, reporting, and gating — proof artifact: **"Filtered alert report"**
- Learning objectives: TO3, EO3c
