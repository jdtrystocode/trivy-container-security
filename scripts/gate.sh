#!/usr/bin/env bash
# Security gate: exit with code 1 if the image has fixable HIGH or CRITICAL vulnerabilities.
# Usage: ./scripts/gate.sh trivy-demo:v3
set -euo pipefail
IMAGE="${1:-trivy-demo:v3}"
trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed "$IMAGE"
echo "Security gate passed for $IMAGE"
