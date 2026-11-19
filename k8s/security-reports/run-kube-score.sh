#!/usr/bin/env bash
# Score GINFlix manifests with kube-score (https://github.com/zegl/kube-score)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${ROOT}/k8s/security-reports"
mkdir -p "$OUT"

KUBE_SCORE="${KUBE_SCORE:-kube-score}"
KUBE_SCORE_VERSION="${KUBE_SCORE_VERSION:-1.20.0}"
if ! command -v kube-score >/dev/null 2>&1; then
  echo "Installing kube-score ${KUBE_SCORE_VERSION}..."
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) ARCH=amd64 ;;
    aarch64) ARCH=arm64 ;;
  esac
  URL="https://github.com/zegl/kube-score/releases/download/v${KUBE_SCORE_VERSION}/kube-score_${KUBE_SCORE_VERSION}_linux_${ARCH}"
  curl -sL "$URL" -o /tmp/kube-score
  chmod +x /tmp/kube-score
  KUBE_SCORE=/tmp/kube-score
fi

echo "=== kube-score: kustomize bundle (GitOps app) ==="
kubectl kustomize "${ROOT}/k8s/app" --load-restrictor LoadRestrictionsNone \
  | "${KUBE_SCORE}" score - \
  | tee "${OUT}/kube-score-app.txt"

echo "=== kube-score: individual manifests ==="
find "${ROOT}/k8s" -name '*.yaml' \
  ! -path '*/secrets/*' \
  ! -name 'secrets.yaml' \
  ! -path '*/monitoring/values-*' \
  -print0 | sort -z | xargs -0 "${KUBE_SCORE}" score \
  | tee "${OUT}/kube-score-all.txt"

echo "Reports: ${OUT}/kube-score-*.txt"
