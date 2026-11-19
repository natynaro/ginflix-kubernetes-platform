# Kubescape Security Scan Report

**Tool:** [Kubescape](https://kubescape.io) v4.0.9  
**Date:** 2026-06-12  
**Project:** GINFlix (`ginflix` namespace)

> **Historical snapshot:** These scores and findings describe the cluster and manifests scanned on 2026-06-12. They have not been regenerated for the current repository state.

## Summary scores

| Scan target | Framework / scope | Compliance score |
|-------------|-------------------|------------------|
| Live cluster | NSA framework | **63%** |
| Git manifests | `k8s/` YAML files | **81%** |

Higher is better (100 = excellent). Manifest score is higher because our repo includes NetworkPolicy, PDB, probes, HPA, and resource limits on all workloads; the Kind control plane lowers cluster score (etcd encryption, audit logs, etc. are platform-level).

## What was scanned

```bash
export PATH="$HOME/.kubescape/bin:$PATH"

# Cluster (NSA hardening framework)
kubescape scan framework nsa --submit=false \
  --format json --format-version v2 \
  --output k8s/security-reports/cluster-nsa.json

# Repository manifests
kubescape scan k8s/ --submit=false \
  --format pretty-printer | tee k8s/security-reports/manifests-summary.txt
```

Re-run anytime: `bash k8s/security-reports/run-kubescape.sh`

## Manifest scan — remaining findings (examples)

| Category | Control | Notes |
|----------|---------|--------|
| Network | Ingress and Egress blocked | Some workloads still allow broad egress (by design for S3/Keycloak) |
| Network | Missing network policy | Non-workload resources (e.g. Job) may lack policies |
| Resources | CPU / memory limits | The historical scan reported gaps; current manifests now specify requests and limits, but require a new scan to confirm |
| Hardening | Non-root containers, read-only root FS | Historical notes cite image-user compatibility concerns; current image requirements have not been retested |

## Highest-stake workloads (Kubescape ranking)

1. `Job/database-rs-init` — one-time MongoDB replica-set init
2. `StatefulSet/database` — MongoDB data plane
3. `Deployment/frontend-admin` — admin UI + upload path

## Reproducing the scan

Run `bash k8s/security-reports/run-kubescape.sh` manually to generate fresh results. Raw JSON and text outputs are ignored and are not committed.

## Limitations on Kind

- Some NSA controls require the **Kubescape operator** or cloud-provider APIs (not available on local Kind).
- Cluster score reflects control-plane gaps (etcd encryption, audit logging) outside our application YAML.
