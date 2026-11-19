#!/usr/bin/env bash
# Install Argo CD and register the GINFlix Application (GitOps).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ARGO_VERSION="${ARGO_VERSION:-v2.14.5}"

echo "=== Namespace argocd ==="
kubectl apply -f "${ROOT}/k8s/gitops/namespace.yaml"

echo "=== Argo CD ${ARGO_VERSION} ==="
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGO_VERSION}/manifests/install.yaml"
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "=== GINFlix Application (sync k8s/app manifests) ==="
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"kustomize.buildOptions":"--load-restrictor LoadRestrictionsNone"}}'
kubectl apply -f "${ROOT}/k8s/gitops/ginflix-application.yaml"

echo ""
echo "Argo CD UI — port-forward:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Initial admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo ""
echo "Note: cluster secrets (mongo, s3, regcred) stay outside Git; apply manually once."
