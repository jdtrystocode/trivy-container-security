#!/usr/bin/env bash
# Build every image version, scan it with Trivy and save JSON reports.
# Usage: ./scripts/scan.sh
set -euo pipefail
# macOS: add Docker Desktop's CLI to PATH if it is not there already.
for d in /Applications/Docker.app/Contents/Resources/bin /usr/local/bin /opt/homebrew/bin; do
  [ -d "$d" ] && case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
done
export PATH
cd "$(dirname "$0")/.."
mkdir -p reports

for v in v1 v2 v3; do
  case $v in v1) name=before ;; v2) name=after ;; v3) name=final ;; esac
  echo "=== Building trivy-demo:$v ==="
  docker build -f "dockerfiles/Dockerfile.$v" -t "trivy-demo:$v" .
  echo "=== Scanning trivy-demo:$v ==="
  trivy image "trivy-demo:$v"
  trivy image --format json --output "reports/$name.json" "trivy-demo:$v"
done

echo "Reports saved in reports/:"
ls -lh reports/
