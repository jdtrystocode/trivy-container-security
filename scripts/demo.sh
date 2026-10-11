#!/usr/bin/env bash
# Guided live demo: build -> scan -> fix -> rescan -> gate -> deploy.
# Pauses before each step so the presenter can explain what is happening.
#
# Usage:
#   ./scripts/demo.sh            # interactive, press Enter to advance
#   AUTO=1 ./scripts/demo.sh     # run straight through (rehearsal)
#   ./scripts/demo.sh --bonus    # also show misconfig, secret and SBOM scans
#
# Live results are written to reports/live/ so the original reports
# (before.json, after.json, final.json) used in the report stay untouched.
set -uo pipefail
cd "$(dirname "$0")/.."

# macOS: Docker Desktop's CLI is not always on PATH (e.g. in bash when the
# PATH line was only added to ~/.zprofile). Add it if it exists.
for d in /Applications/Docker.app/Contents/Resources/bin /usr/local/bin /opt/homebrew/bin; do
  [ -d "$d" ] && case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
done
export PATH

BONUS=0
[ "${1:-}" = "--bonus" ] && BONUS=1
LIVE=reports/live
mkdir -p "$LIVE"

B=$'\033[1m'; DIM=$'\033[2m'; R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; C=$'\033[36m'; N=$'\033[0m'

step() {
  echo
  printf '%s\n' "${C}${B}━━━ $1 ━━━${N}"
  [ -n "${2:-}" ] && printf '%s\n' "${DIM}$2${N}"
  if [ -z "${AUTO:-}" ]; then read -r -p "  [Enter] " _; fi
}
run() { printf '%s\n' "${Y}\$ $*${N}"; "$@"; }

counts() {   # print a one-line severity summary from a Trivy JSON report
  local f=$1 total=0 line="" s n
  for s in CRITICAL HIGH MEDIUM LOW UNKNOWN; do
    n=$(grep -c "\"Severity\": \"$s\"" "$f" || true)
    total=$((total + n)); line="$line $s=$n"
  done
  printf '%s\n' "${B}  TOTAL=$total ${N}|$line"
  echo "$total" > "$f.total"
}

# ---------------------------------------------------------------- preflight
step "0. Tools" "Docker builds the image, Trivy scans it. No server, no account."
run docker --version || { echo "${R}Docker not found or not running${N}"; exit 1; }
run trivy --version  || { echo "${R}Trivy not found (brew install trivy)${N}"; exit 1; }

# ---------------------------------------------------------------- v1
step "1. The problem: an old base image" "A Dockerfile someone wrote long ago and never updated."
run cat dockerfiles/Dockerfile.v1
run docker build -q -f dockerfiles/Dockerfile.v1 -t trivy-demo:v1 .

step "2. Scan v1 with Trivy" "Watch for the end-of-life warning. Showing CRITICAL only to keep it readable."
run trivy image --severity CRITICAL trivy-demo:v1
trivy image -q --format json --output "$LIVE/v1.json" trivy-demo:v1
echo; echo "Full scan of v1:"; counts "$LIVE/v1.json"

# ---------------------------------------------------------------- v2
step "3. Fix 1: change ONE line - the base image" "Moving to a supported Alpine release."
run diff dockerfiles/Dockerfile.v1 dockerfiles/Dockerfile.v2
run docker build -q -f dockerfiles/Dockerfile.v2 -t trivy-demo:v2 .
run trivy image trivy-demo:v2
trivy image -q --format json --output "$LIVE/v2.json" trivy-demo:v2
echo; echo "Full scan of v2:"; counts "$LIVE/v2.json"

# ---------------------------------------------------------------- v3
step "4. Fix 2: patch the remaining packages" "apk upgrade pulls fixes released after the base image was published. --no-cache makes Docker really re-run it."
run diff dockerfiles/Dockerfile.v2 dockerfiles/Dockerfile.v3
run docker build -q --no-cache -f dockerfiles/Dockerfile.v3 -t trivy-demo:v3 .
run trivy image trivy-demo:v3
trivy image -q --format json --output "$LIVE/v3.json" trivy-demo:v3
echo; echo "Full scan of v3:"; counts "$LIVE/v3.json"

step "5. Result" ""
printf '  %-16s %s\n' "trivy-demo:v1" "$(cat "$LIVE/v1.json.total") vulnerabilities"
printf '  %-16s %s\n' "trivy-demo:v2" "$(cat "$LIVE/v2.json.total") vulnerabilities"
printf '  %-16s %s\n' "trivy-demo:v3" "$(cat "$LIVE/v3.json.total") vulnerabilities"
echo "  ${DIM}(report, 5 Oct 2026: 101 -> 4 -> 0. Live numbers can drift as new CVEs are published.)${N}"
rm -f "$LIVE"/*.total

# ---------------------------------------------------------------- gate
step "6. Security gate on v1 (what CI/CD runs)" "--exit-code 1 makes Trivy fail the build on fixable HIGH/CRITICAL."
printf '%s\n' "${Y}\$ ./scripts/gate.sh trivy-demo:v1${N}"
./scripts/gate.sh trivy-demo:v1 > /dev/null 2>&1; rc=$?
if [ $rc -ne 0 ]; then
  printf '%s\n' "${R}${B}  ✗ GATE FAILED (exit code $rc) - pipeline stops, v1 is never deployed${N}"
else
  printf '%s\n' "${G}  gate passed${N}"
fi

step "7. Security gate on v3" ""
printf '%s\n' "${Y}\$ ./scripts/gate.sh trivy-demo:v3${N}"
if ./scripts/gate.sh trivy-demo:v3 > /dev/null 2>&1; then
  printf '%s\n' "${G}${B}  ✓ GATE PASSED (exit code 0) - safe to deploy${N}"
else
  printf '%s\n' "${R}  gate failed - a fix for a new CVE is not in the Alpine repo yet; see the v3 table above${N}"
fi

# ---------------------------------------------------------------- deploy
step "8. Deploy the hardened image and verify it still works" ""
docker rm -f trivy-demo-container > /dev/null 2>&1 || true
run docker run -d --name trivy-demo-container -p 8081:80 trivy-demo:v3
sleep 2
run docker ps --filter name=trivy-demo-container
run curl -s http://localhost:8081
[ "$(uname)" = "Darwin" ] && open http://localhost:8081

# ---------------------------------------------------------------- bonus
if [ $BONUS -eq 1 ]; then
  step "Bonus A. Misconfiguration scan of the Dockerfiles" "Same tool, different target: finds issues like running as root."
  run trivy config dockerfiles/
  step "Bonus B. Secret scan of the repository" ""
  run trivy fs --scanners secret .
  step "Bonus C. Generate an SBOM (CycloneDX) for v3" ""
  run trivy image -q --format cyclonedx --output reports/sbom.cdx.json trivy-demo:v3
  run ls -lh reports/sbom.cdx.json
fi

echo
printf '%s\n' "${G}${B}Demo complete.${N} Stop the container with: docker rm -f trivy-demo-container"
