#!/usr/bin/env bash
# Patch reverse-proxy/*.conf with the current ingress-nginx LoadBalancer IP.
# Run on the VM after cluster recreate or MetalLB IP change.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IP="$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

if [[ -z "${IP}" ]]; then
  echo "error: ingress-nginx-controller has no LoadBalancer IP" >&2
  exit 1
fi

if [[ ! "${IP}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "error: expected an IPv4 LoadBalancer IP, got '${IP}'" >&2
  exit 1
fi

CONFIGS=("${ROOT}/reverse-proxy/ginflix.conf" "${ROOT}/reverse-proxy/admin.conf")
for conf in "${CONFIGS[@]}"; do
  if ! grep -Eq '^[[:space:]]*server[[:space:]]+[0-9.]+:80' "$conf"; then
    echo "error: no placeholder upstream found in ${conf}" >&2
    exit 1
  fi
done

for conf in "${CONFIGS[@]}"; do
  sed -i -E "s/^[[:space:]]*server[[:space:]]+[0-9.]+:80/    server ${IP}:80/" "$conf"
done

echo "Updated upstream to ${IP}:80 in reverse-proxy/*.conf"
echo "Run: sudo nginx -t && sudo systemctl reload nginx"
