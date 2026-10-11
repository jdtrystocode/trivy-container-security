# Container Security Scanning and Vulnerability Assessment Using Trivy

DevOps Theory IA case study. Alternative tool for the Security (DevSecOps) stage.
K J Somaiya School of Engineering. Kavya Mehta (16010123169), Jayaditya Singhvi (16010123158), Muaaz Khan (16010123173).

A static web page served by NGINX is containerised on an outdated base image, scanned with Trivy, fixed in two steps and rescanned. The scan is then automated as a CI/CD security gate in a shell script, GitHub Actions and Jenkins.

| Image | Base | Change | Vulnerabilities | Security gate |
|---|---|---|---|---|
| `trivy-demo:v1` | `nginx:1.21-alpine` (Alpine 3.15.4, EOL) | baseline | **101** (11 C, 42 H, 42 M, 6 L) | Fails (53 fixable HIGH/CRITICAL) |
| `trivy-demo:v2` | `nginx:1.30.5-alpine3.24` | new base image | **4** (2 H, 1 M, 1 U) | Fails (2 fixable HIGH) |
| `trivy-demo:v3` | `nginx:1.30.5-alpine3.24` | `+ RUN apk upgrade --no-cache` | **0** | Passes, deployed |

Scanned 5 Oct 2026 with Trivy 0.75.0 and Docker 29.7.2 on macOS (Apple Silicon).

## Repository layout

```
trivy-container-security/
├── app/index.html                       # sample web page
├── Dockerfile                           # final hardened image (= v3), used by CI
├── dockerfiles/
│   ├── Dockerfile.v1                    # baseline: nginx:1.21-alpine
│   ├── Dockerfile.v2                    # updated base image
│   └── Dockerfile.v3                    # + apk upgrade
├── scripts/
│   ├── scan.sh                          # build + scan all versions, save JSON
│   ├── gate.sh                          # security gate (exit 1 on fixable HIGH/CRITICAL)
│   └── demo.sh                          # guided live demo for the presentation
├── .github/workflows/
│   ├── trivy-scan.yml                   # main pipeline: push/PR -> build -> scan -> gate
│   └── gate-demo.yml                    # manual run: v1, v2, v3 side by side (red, red, green)
├── Jenkinsfile                          # same pipeline for Jenkins
├── .trivyignore                         # reviewed exceptions (empty)
├── dashboard/index.html                 # interactive results dashboard (open in a browser)
└── reports/                             # before.json, after.json, final.json
```

## How to run

Prerequisites: Docker Desktop running, Trivy installed (`brew install trivy`).

```bash
chmod +x scripts/*.sh

./scripts/scan.sh                 # build and scan v1, v2, v3; writes reports/*.json
./scripts/gate.sh trivy-demo:v1   # fails with exit code 1
./scripts/gate.sh trivy-demo:v3   # passes

docker run -d --name trivy-demo-container -p 8081:80 trivy-demo:v3
curl http://localhost:8081
```

Guided demo with pauses between steps: `./scripts/demo.sh` (add `--bonus` for misconfiguration, secret and SBOM scans; `AUTO=1` runs without pauses for rehearsal). Live results go to `reports/live/`, so the original reports are not overwritten.

Results drift over time. New CVEs are published daily, so a scan run today may show different counts from the 5 Oct 2026 reports, especially for v2. That is lesson 2 of the report: images must be rebuilt and rescanned regularly.

## CI/CD

- **GitHub Actions** — `trivy-scan.yml` runs on every push to `main` and every pull request. It builds the root `Dockerfile`, uploads the JSON report as an artefact, and fails the job on fixable HIGH/CRITICAL findings.
- **Gate demo** — Actions tab → *security-gate-demo* → *Run workflow*. It builds all three versions in parallel. v1 and v2 go red at the gate, v3 goes green and is deployed and curled. On a public repo the findings also appear under the Security tab (code scanning).
- **Jenkins** — `Jenkinsfile`: Checkout → Build Image → Trivy Scan → Security Gate → Deploy. It always archives `reports/*.json`.

Trivy runs as the `aquasec/trivy:0.75.0` container in CI, so nothing needs installing on the runner.
