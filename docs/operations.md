# Operations

## Cluster Health

```bash
kubectl get nodes
kubectl get pods,svc,ingress,hpa,pdb,networkpolicy -n ginflix
kubectl get statefulset,pvc -n ginflix
kubectl get events -n ginflix --sort-by=.lastTimestamp
```

Inspect a failing workload:

```bash
kubectl describe pod <pod-name> -n ginflix
kubectl logs <pod-name> -n ginflix --all-containers
```

## Rollouts and Scaling

```bash
kubectl rollout status deployment/backend -n ginflix
kubectl rollout history deployment/backend -n ginflix
kubectl rollout restart deployment/backend -n ginflix
kubectl get hpa -n ginflix
kubectl describe hpa backend-hpa -n ginflix
```

Backend and streamer HPAs are configured with 2 minimum replicas, 5 maximum replicas, and a 50% CPU utilization target. Check `kubectl top pods -n ginflix` and Metrics Server health if HPA metrics are unavailable.

## MongoDB

Check replica-set status:

```bash
kubectl exec -n ginflix database-0 -- mongosh --quiet \
  --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr}))"
```

The `database-rs-init` Job is a one-time bootstrap action. If re-running it is needed, inspect the current database state first; do not casually delete PVCs or StatefulSet Pods.

## Monitoring and Logs

Install or upgrade the monitoring charts:

```bash
bash k8s/monitoring/install.sh
kubectl get pods -n monitoring
```

Forward Grafana locally:

```bash
kubectl port-forward -n monitoring \
  svc/kube-prometheus-grafana 3000:80
```

Open `http://localhost:3000`. The repository's default chart values set the Grafana username to `admin` and password to `ginflix`; change these for any non-demo environment.

Loki collects logs from the `ginflix` namespace. In Grafana Explore, select Loki and query:

```text
{namespace="ginflix"}
```

## Backups

The MongoDB CronJob is scheduled daily at 02:00 UTC and writes timestamped `mongodump` output to the `mongodb-backup` PVC.

Run a manual backup and inspect Jobs:

```bash
bash k8s/mongodb/backup-now.sh
kubectl get jobs -n ginflix
kubectl logs -n ginflix job/<backup-job-name>
```

The repository does not currently define a tested restore procedure. Treat backups as unverified until restore testing has been implemented and exercised.

## Network Policy Regression

```bash
bash k8s/network-policies/test.sh
```

This script expects a running cluster, working `kubectl`, and required utilities in the selected Pods. Interpret failed probes alongside Pod readiness and cluster NetworkPolicy support.

## Ingress Address Changes

After recreating the cluster or changing the Ingress LoadBalancer address:

```bash
bash reverse-proxy/sync-ingress-ip.sh
sudo nginx -t
sudo systemctl reload nginx
```

## Common Failure Checks

| Symptom | First checks |
| --- | --- |
| `ImagePullBackOff` | `regcred`, registry reachability, image name/tag |
| Backend unavailable | Pod logs, MongoDB URI, ConfigMap/Secrets, port 8080 |
| MongoDB lacks a primary | StatefulSet Pods/PVCs, replica-set status, NetworkPolicies |
| Ingress 502 | Ingress controller, Service endpoints, Pod readiness, path/port mapping |
| OIDC login fails | Admin Nginx routes, Keycloak realm/client config, cookie/redirect host |
| HPA has `<unknown>` metrics | Metrics Server, CPU requests, API metrics availability |
