# Security

This project includes Kubernetes controls intended for a course/demo environment. It is not a production security certification.

## Secrets and Sensitive Configuration

The application depends on:

- `mongo-secret` for the MongoDB URI
- `s3-secret` for Garage credentials
- `regcred` for private image-registry access
- VM certificate and private-key files for public TLS

The committed YAML files are templates. Store real credentials outside Git, apply them to the cluster through a controlled process, rotate credentials when exposed, and do not paste secret values into CI logs or issue trackers.

`k8s/secrets/` is intended for local credential files and is gitignored. GitHub Actions do not require cluster credentials and should not receive them for manifest validation.

## Network Exposure

- Application Services use ClusterIP and are routed through Ingress-Nginx.
- MongoDB is available only through an internal headless Service and has no public NodePort or LoadBalancer.
- NetworkPolicies constrain traffic to the required application, database, DNS, backup, and external-service flows.
- NetworkPolicy enforcement depends on a CNI/plugin that supports policies; verify the cluster implementation.

## TLS and Identity

- VM Nginx terminates public HTTPS using the VM-installed certificates.
- cert-manager manifests demonstrate in-cluster certificate issuance with a self-signed issuer; that certificate is not a substitute for a publicly trusted certificate.
- The admin hostname proxies Keycloak endpoints to support the browser OIDC flow. Keep the Keycloak realm/client redirect URI configuration aligned with the public admin hostname.

## Workload Controls

Workload manifests define probes, CPU/memory/ephemeral-storage requests and limits, and preferred Pod anti-affinity. PDBs help control voluntary disruption. These settings improve resilience but do not harden every container privilege or kernel boundary.

The workloads currently do not set a `securityContext` (`runAsNonRoot`, `allowPrivilegeEscalation`, or `readOnlyRootFilesystem`). The application images are externally provided, and the historical scan reports indicate that some supplied images require root. These controls have not been enabled without image-level compatibility testing; do not treat the current containers as hardened.

## Security Scanning

Run the local scans:

```bash
bash k8s/security-reports/run-kube-score.sh
bash k8s/security-reports/run-kubescape.sh
```

GitHub Actions runs Gitleaks against the full Git history, Trivy against Kubernetes configuration, repository files, and the public MongoDB image, plus kube-score, Kubescape, and OpenSSF Scorecard. Trivy, kube-score, and Kubescape currently report findings without blocking merges while the course-provided manifests and image baseline are being assessed. Gitleaks is blocking. The kube-score step is explicitly advisory: its findings remain visible in the logs, but they do not fail the Security workflow.

The application images are hosted in a private course registry and are not scanned by CI because no registry credentials are configured. The `mongo:6` image is public and is scanned for high and critical vulnerabilities; Trivy reports findings without failing the workflow while the demo image baseline is evaluated. CI validates rendered Kubernetes objects with Kubeconform rather than `kubectl apply --dry-run=client`, which can require API-server discovery.

Configure branch protection in the GitHub repository settings. Require the validation and documentation checks appropriate to the repository after their first successful runs. Scorecard also reports repository governance signals; its results depend on settings such as branch protection being configured.

Known limitations include `latest` tags for some provided images and missing/non-root security contexts where the supplied images may require root. Pin images and harden security contexts when compatible, tested images are available.

## Production Hardening Priorities

1. Replace demo/default Grafana credentials.
2. Pin container images to immutable digests or approved versions.
3. Use a secret manager or external-secrets integration.
4. Add and test a MongoDB restore procedure.
5. Review and minimize NetworkPolicy CIDR allowances for the actual cluster network.
6. Apply and test appropriate `securityContext` settings.
7. Configure TLS and repository authentication for the exact deployment environment.
8. Add alerts for failed backups, unavailable replicas, and certificate expiry.
