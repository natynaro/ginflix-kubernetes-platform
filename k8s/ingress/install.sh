#!/usr/bin/env bash
# Install cert-manager + ingress-nginx on Kind (MetalLB assigns LB IP to ingress).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.16.3}"
INGRESS_VERSION="${INGRESS_VERSION:-controller-v1.11.3}"

echo "=== cert-manager ${CERT_MANAGER_VERSION} ==="
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=180s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=180s
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=180s

echo "=== ingress-nginx ${INGRESS_VERSION} ==="
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_VERSION}/deploy/static/provider/cloud/deploy.yaml"
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=180s

kubectl apply -f "${ROOT}/k8s/namespace.yaml"

echo "=== ClusterIssuer + Certificate ==="
kubectl apply -f "${ROOT}/k8s/cert-manager/cluster-issuer-selfsigned.yaml"
kubectl apply -f "${ROOT}/k8s/cert-manager/certificate-ginflix.yaml"

echo "Waiting for TLS secret ginflix-tls..."
tls_secret_ready=false
for ((attempt = 1; attempt <= 60; attempt++)); do
  if kubectl get secret ginflix-tls -n ginflix >/dev/null 2>&1; then
    echo "ginflix-tls ready"
    tls_secret_ready=true
    break
  fi
  sleep 3
done

if [[ "${tls_secret_ready}" != true ]]; then
  echo "error: timed out waiting for TLS secret ginflix-tls" >&2
  exit 1
fi

echo "=== Ingress resource ==="
kubectl apply -f "${ROOT}/k8s/ingress/ginflix-ingress.yaml"

echo "Ingress controller LoadBalancer IP:"
INGRESS_IP="$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
if [[ -z "${INGRESS_IP}" ]]; then
  echo "error: ingress-nginx-controller has no LoadBalancer IP" >&2
  exit 1
fi
echo "${INGRESS_IP}"
