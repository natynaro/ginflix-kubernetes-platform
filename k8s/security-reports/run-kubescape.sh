#!/usr/bin/env bash
# Run Kubescape scans for GINFlix (install: https://kubescape.io/docs/install-cli/)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PATH="${HOME}/.kubescape/bin:${PATH}"
OUT="${ROOT}/k8s/security-reports"
mkdir -p "$OUT"

if ! command -v kubescape >/dev/null 2>&1; then
  echo "Installing Kubescape CLI..."
  curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash
  export PATH="${HOME}/.kubescape/bin:${PATH}"
fi

echo "=== Cluster scan (NSA framework) ==="
kubescape scan framework nsa --submit=false \
  --format json --format-version v2 \
  --output "${OUT}/cluster-nsa.json"

echo "=== Manifest scan (k8s/) ==="
kubescape scan "${ROOT}/k8s/" --submit=false \
  --format pretty-printer | tee "${OUT}/manifests-summary.txt"

echo "Reports written to ${OUT}/"
