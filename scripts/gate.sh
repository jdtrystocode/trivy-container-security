#!/usr/bin/env bash
# Security gate: exit with code 1 if the image has fixable HIGH or CRITICAL vulnerabilities.
# Usage: ./scripts/gate.sh trivy-demo:v3
set -euo pipefail
# macOS: add Docker Desktop's CLI to PATH if it is not there already.
for d in /Applications/Docker.app/Contents/Resources/bin /usr/local/bin /opt/homebrew/bin; do
  [ -d "$d" ] && case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
done
export PATH
IMAGE="${1:-trivy-demo:v3}"
trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed "$IMAGE"
echo "Security gate passed for $IMAGE"
