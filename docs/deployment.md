# Deployment

This guide describes how to deploy GINFlix on a Kubernetes cluster.

The repository intentionally excludes real credentials, private registry access details, domain names, and institution-specific configuration. Replace all placeholder values with environment-specific settings.

## Prerequisites

Required components:

- Linux VM or Kubernetes-capable host
- Docker
- Kind (or compatible Kubernetes cluster)
- kubectl
- Helm
- Nginx
- Ingress-Nginx
- MetalLB or another LoadBalancer implementation
- Metrics Server
- Access to the private application container registry
- Keycloak (or compatible OIDC provider)
- S3-compatible storage
- TLS certificate and private key

Verify cluster connectivity:

```bash
kubectl get nodes
```

All nodes should report `Ready`.

## 1. Namespace and Configuration

Create the application namespace:

```bash
kubectl apply -f k8s/namespace.yaml
```

Create the required configuration resources:

- `ginflix-config` ConfigMap
- `s3-secret`
- `mongo-secret`
- `regcred`

Templates are provided in:

```text
k8s/examples/configmap.yaml
k8s/examples/secrets.yaml
k8s/secrets/
```

These files contain placeholder values only. Copy the needed templates to environment-specific files under `k8s/secrets/`, replace the placeholders, and apply only those completed files.

Never commit real:

- Registry credentials
- Database connection strings
- S3 credentials
- TLS private keys
- OIDC client secrets

Apply environment-specific files:

```bash
kubectl apply -f k8s/secrets/ginflix-config.yaml
kubectl apply -f k8s/secrets/s3-secret.yaml
kubectl apply -f k8s/secrets/mongo-secret.yaml
kubectl apply -f k8s/secrets/regcred.yaml
```

Verify:

```bash
kubectl get configmap,secrets -n ginflix
```

## 2. MongoDB

Deploy the MongoDB headless Service first:

```bash
kubectl apply -f k8s/mongodb/database-service.yaml
```

Deploy the StatefulSet:

```bash
kubectl apply -f k8s/mongodb/database-deployment.yaml
```

Wait for the first member:

```bash
kubectl wait \
  --for=condition=ready \
  pod/database-0 \
  -n ginflix \
  --timeout=180s
```

Initialize the ReplicaSet:

```bash
kubectl delete job database-rs-init \
  -n ginflix \
  --ignore-not-found

kubectl apply -f k8s/mongodb/database-rs-init-job.yaml

kubectl wait \
  --for=condition=complete \
  job/database-rs-init \
  -n ginflix \
  --timeout=180s
```

### Important

The `mongo-secret` connection string must use the ReplicaSet URI.

Example structure:

```text
mongodb://database-0.database.<namespace>.svc.cluster.local:27017,
database-1.database.<namespace>.svc.cluster.local:27017,
database-2.database.<namespace>.svc.cluster.local:27017/<database>?replicaSet=rs0
```

Do not use a legacy single-node URI with the current ReplicaSet architecture.

### Verification

```bash
kubectl get pods -n ginflix -l app=database

kubectl exec -n ginflix database-0 \
  -- mongosh --quiet \
  --eval "rs.status().members.map(m => m.stateStr)"
```

Expected result:

```text
PRIMARY
SECONDARY
SECONDARY
```

### Migration Note

If migrating from a standalone MongoDB deployment to the ReplicaSet architecture, existing local data may need to be recreated or restored from backup.

## 3. Application Workloads

Deploy application services:

```bash
kubectl apply -f k8s/backend/
kubectl apply -f k8s/streamer/
kubectl apply -f k8s/frontend/
kubectl apply -f k8s/frontend-admin/
```

Verify rollout status:

```bash
kubectl rollout status deployment/backend -n ginflix
kubectl rollout status deployment/streamer -n ginflix
kubectl rollout status deployment/frontend -n ginflix
kubectl rollout status deployment/frontend-admin -n ginflix
```

Deploy supporting resources:

```bash
kubectl apply -f k8s/hpa/
kubectl apply -f k8s/pdb/
kubectl apply -f k8s/network-policies/
kubectl apply -f k8s/mongodb/backup-cronjob.yaml
```

The backend and streamer HPAs target 2–5 replicas at 50% average CPU utilization.

Verify:

```bash
kubectl get hpa,pdb,networkpolicy -n ginflix
```

## 4. GitOps Bundle

Render the complete Kustomize bundle:

```bash
kubectl kustomize k8s/app \
  --load-restrictor LoadRestrictionsNone
```

The bundle may be applied with:

```bash
kubectl apply -k k8s/app
```

only after:

- ConfigMaps exist
- Secrets exist
- CRDs are installed
- External controllers are available

The MongoDB ReplicaSet initialization Job is intentionally excluded from the GitOps bundle.

## 5. Metrics Server

Horizontal Pod Autoscalers require:

- Metrics Server
- CPU requests configured on workloads

Install Metrics Server:

```bash
kubectl apply -f \
https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Verify:

```bash
kubectl top nodes
kubectl top pods -n ginflix
```

Some Kind environments may require additional kubelet TLS settings for Metrics Server. Apply such workarounds only in development environments.

## 6. Ingress and TLS

Install Ingress-Nginx and project resources:

```bash
bash k8s/ingress/install.sh

kubectl apply \
  -f k8s/ingress/ginflix-ingress.yaml
```

If cert-manager is available:

```bash
kubectl apply -f k8s/cert-manager/
```

The installer scripts use explicit, overridable release/chart versions. These are reproducibility pins, not a guarantee of current upstream support; review compatibility and security status before upgrading or using them for production.

Verify:

```bash
kubectl get ingress -n ginflix
```

Get the Ingress controller address:

```bash
kubectl get svc \
  -n ingress-nginx \
  ingress-nginx-controller
```

## 7. VM Reverse Proxy

Configure:

```text
reverse-proxy/ginflix.conf
reverse-proxy/admin.conf
```

Update:

- Domain names
- TLS certificate paths
- Ingress controller address

Optional helper:

```bash
bash reverse-proxy/sync-ingress-ip.sh
```

Validate the Nginx configuration:

```bash
sudo nginx -t
```

Reload:

```bash
sudo systemctl reload nginx
```

Ensure certificates exist and have the correct permissions:

```text
/etc/certs/
```

or the location appropriate for your environment.

## 8. Argo CD

Before applying the Application resource:

```bash
k8s/gitops/ginflix-application.yaml
```

replace:

```yaml
repoURL: https://github.com/<OWNER>/<REPOSITORY>.git
```

with the repository that hosts your manifests.

If the repository is private:

- configure repository credentials
- verify connectivity from Argo CD

Secrets and ConfigMaps remain intentionally outside the GitOps bundle.

## 9. Post-Deployment Verification

Verify cluster resources:

```bash
kubectl get \
pods,svc,ingress,hpa,pdb,networkpolicy \
-n ginflix

kubectl get \
statefulset,pvc \
-n ginflix
```

Verify MongoDB ReplicaSet:

```bash
kubectl exec -n ginflix database-0 \
  -- mongosh --quiet \
  --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr}))"
```

Verify application endpoints:

```bash
curl -sk https://ginflix.example.invalid/api/videos
```

Expected result:

```text
HTTP 200
```

The response may be an empty collection when no media has been uploaded.

## Optional Validation

Network Policies:

```bash
bash k8s/network-policies/test.sh
```

Manual backup:

```bash
bash k8s/mongodb/backup-now.sh
```

Render the GitOps bundle. Schema validation is performed by Kubeconform in CI; client-side `kubectl apply --dry-run` may still require API-server discovery.

```bash
kubectl kustomize k8s/app \
  --load-restrictor LoadRestrictionsNone
```

Security scans:

```bash
bash k8s/security-reports/run-kube-score.sh
bash k8s/security-reports/run-kubescape.sh
```

## Related Documentation

- `docs/architecture.md`
- `docs/security.md`
- `docs/operations.md`
- `docs/demo-runbook.md`
- `docs/decisions.md`
- `docs/lessons-learned.md`

These documents describe architecture, operational procedures, security controls, validation workflows, and engineering decisions in greater detail.
