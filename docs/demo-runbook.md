# Demo Runbook

This checklist is for demonstrating the deployed system. Run commands from the VM hosting the Kind cluster unless otherwise noted. Confirm that the environment-specific domains and credentials are available before the session.
Replace the `example.invalid` hostname in the commands with the configured deployment hostname.

## Before the Demo

```bash
kubectl get nodes
kubectl get pods -n ginflix
kubectl get hpa,pdb,networkpolicy -n ginflix
kubectl get statefulset,pvc -n ginflix
curl -sk -o /dev/null -w "HTTP %{http_code}\n" \
  https://ginflix.example.invalid/api/videos
```

Expected: cluster nodes Ready, required Pods healthy, MongoDB PVCs Bound, API returns HTTP 200. If the external domain is unavailable from the VM, test VM Nginx locally with the appropriate `curl --resolve` host mapping.

## Viewer Flow

1. Open the main site.
2. Confirm that the video list loads.
3. Play an available video and verify HLS playback.

## Administrator Flow

1. Open the admin site.
2. Start the Keycloak login flow and authenticate with the assigned account.
3. Upload a small test video.
4. Wait for processing to complete.
5. Confirm the new item appears in the viewer site and plays.

Do not use production or personal media without permission. Respect the course environment's upload limits.

## Platform Features

Show the following when time allows:

```bash
kubectl get pods,hpa,pdb,networkpolicy -n ginflix
kubectl get statefulset,pvc -n ginflix
kubectl exec -n ginflix database-0 -- mongosh --quiet \
  --eval "rs.status().members.map(m => m.stateStr)"
kubectl get pods -n monitoring
```

Discuss the MongoDB StatefulSet/replica set, HPA, PDBs, NetworkPolicies, dashboards/logs, daily backup CronJob, and Argo CD synchronization.

## CI Workflows

In the GitHub repository, open **Actions** and show the latest run for:

- Validate
- Test Kubernetes Manifests
- Security
- Documentation

These workflows run independently. Gitleaks blocks on detected secrets; Trivy, kube-score, and Kubescape findings are currently non-blocking.

## Recovery Checklist

If a demo check fails:

1. Inspect Pod readiness, events, and logs.
2. Confirm `ginflix-config`, `mongo-secret`, `s3-secret`, and `regcred` exist without displaying secret values.
3. Check MongoDB replica-set health and PVCs.
4. Check Ingress endpoints and the current controller address.
5. Validate VM Nginx syntax before reloading it.

Use [Operations](operations.md) for command references and [Deployment](deployment.md) for setup steps.
