#!/usr/bin/env bash
# Install Prometheus/Grafana + Loki/Promtail for GINFlix.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MON="${ROOT}/k8s/monitoring"
LOKI_CHART_VERSION="${LOKI_CHART_VERSION:-2.10.3}"
PROM_CHART_VERSION="${PROM_CHART_VERSION:-69.8.2}"

echo "=== Kind node inotify limits (Promtail) ==="
mapfile -t KIND_NODES < <(docker ps --format '{{.Names}}' | grep '^kind-' || true)
if ((${#KIND_NODES[@]} == 0)); then
  echo "warning: no running Kind nodes found; skipped inotify tuning" >&2
else
  for node in "${KIND_NODES[@]}"; do
    if ! docker exec "$node" sh -c 'sysctl -w fs.inotify.max_user_instances=512 fs.inotify.max_user_watches=524288'; then
      echo "warning: could not adjust inotify limits on ${node}" >&2
    fi
  done
fi

echo "=== Namespace monitoring ==="
kubectl apply -f "${MON}/namespace.yaml"

echo "=== Helm repos ==="
helm repo add grafana https://grafana.github.io/helm-charts --force-update
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update

echo "=== Loki + Promtail (loki-stack ${LOKI_CHART_VERSION}) ==="
helm upgrade --install loki grafana/loki-stack \
  --version "${LOKI_CHART_VERSION}" \
  -n monitoring \
  -f "${MON}/values-loki.yaml" \
  --wait --timeout 15m

echo "=== Prometheus + Grafana (kube-prometheus-stack ${PROM_CHART_VERSION}) ==="
helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
  --version "${PROM_CHART_VERSION}" \
  -n monitoring \
  -f "${MON}/values-prometheus.yaml" \
  --wait --timeout 20m

echo "=== Ingress metrics ServiceMonitor ==="
kubectl apply -f "${MON}/servicemonitor-ingress.yaml"

kubectl rollout restart daemonset/loki-promtail -n monitoring
kubectl rollout status daemonset/loki-promtail -n monitoring --timeout=180s

echo ""
kubectl get pods -n monitoring
echo ""
echo "Grafana: admin / ginflix"
kubectl get svc -n monitoring kube-prometheus-grafana -o wide
