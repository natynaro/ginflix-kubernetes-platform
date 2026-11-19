#!/usr/bin/env bash
# One-shot MongoDB backup Job (uses same PVC as CronJob).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
kubectl apply -f "${ROOT}/k8s/mongodb/backup-cronjob.yaml"

kubectl create job "mongodb-backup-manual-$(date +%s)" \
  --from=cronjob/mongodb-backup -n ginflix

echo "Watch: kubectl get jobs -n ginflix -w"
echo "Logs:  kubectl logs -n ginflix job/$(kubectl get jobs -n ginflix --sort-by=.metadata.creationTimestamp -o name | tail -1 | cut -d/ -f2)"
