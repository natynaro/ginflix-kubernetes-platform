# Kube-score summary

Complements Kubescape (`k8s/security-reports/KUBESCAPE-REPORT.md`).

> **Historical snapshot:** The scan date was not recorded; the change notes below refer to 2026-06. This is not a current assessment. Re-run the scan manually before using its results.

**Reproduce:**

```bash
bash k8s/security-reports/run-kube-score.sh
```

The script writes `kube-score-app.txt` and `kube-score-all.txt` locally. Generated text outputs are ignored and are not committed.

---

## What we improved (2026-06)

| Check | Fix |
|-------|-----|
| Missing CPU/memory limits | `resources` on Deployments, StatefulSet, init Job, and backup CronJob |
| Missing ephemeral-storage | Added to all containers |
| Missing PodDisruptionBudget | `k8s/pdb/` — backend, streamer, frontend, frontend-admin, database |
| HPA vs static replicas | Removed `replicas` from backend/streamer Deployments; HPA `minReplicas: 2` |
| Identical readiness/liveness | HTTP `/health` readiness + TCP liveness (backend/streamer); HTTP + TCP (frontend/admin); distinct MongoDB exec commands |
| rs-init Job NetworkPolicy | `k8s/network-policies/rs-init-policy.yaml` |
| imagePullPolicy | `Always` on course images |

---

## Last recorded results (GitOps bundle `k8s/app/`)

| Resource | Result | Notes |
|----------|--------|-------|
| HPA ×2 | ✅ | |
| Ingress | ✅ | |
| NetworkPolicy ×7 | ✅ | incl. rs-init and backup |
| PodDisruptionBudget ×5 | ✅ | |
| Services ×5 | ✅ | |
| Deployments / StatefulSet / CronJob | 💥 | Historical CRITICALs on provided images |

### Historical findings requiring image-specific assessment

- **`:latest` image tags** — the recorded assessment stated that the registry published only `latest`; verify current image tags before relying on this limitation
- **No `securityContext`** — historical notes cite image compatibility as a concern, but current image user requirements have not been retested. Test before enabling `runAsNonRoot` or `readOnlyRootFilesystem`.

### Remaining WARNINGs (acceptable)

- Frontend / frontend-admin: ingress-only NetworkPolicy (no egress by design)
- rs-init Job: no ingress policy (one-shot init, egress restricted)
- database StatefulSet: no egress policy (replica traffic allowed via dedicated ingress rules)

---

## Files

| Path | Role |
|------|------|
| `run-kube-score.sh` | Score `k8s/app/` bundle + all YAML under `k8s/` |
| Generated output | Local ignored text files; not committed |
