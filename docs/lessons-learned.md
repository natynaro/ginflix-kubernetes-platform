# Lessons Learned

## Stateful Workloads Need Stateful Design

Increasing MongoDB Deployment replicas would create independent data stores, not a replicated database. Stable identities, persistent volumes, and MongoDB replica-set configuration are all required for the intended topology.

## Kind Requires an Explicit Edge Layer

Kind LoadBalancer addresses are constrained by the VM network. VM Nginx provides the public TLS endpoint and forwards traffic into the cluster through a single Ingress controller.

## Health Checks Must Match the Actual Service

Probe paths and ports need to correspond to the real application endpoints. A probe against a nonexistent route can restart a healthy process or prevent traffic from reaching it.

## Network Policies Need Tests

Policies can break DNS, database membership, initialization Jobs, or application traffic. Positive and negative connectivity checks make policy changes safer to operate.

## Autoscaling Depends on Metrics and Requests

An HPA needs a working metrics source and resource requests for CPU utilization. The target values in documentation should be verified against manifests, not copied from older notes.

## Identity Flows Cross Multiple Domains

OIDC redirects, cookies, browser reachability, and reverse-proxy host rewriting need to be planned together. Testing only service-to-service connectivity does not verify a browser login.

## GitOps Does Not Eliminate Secret Management

A GitOps application can reconcile ordinary manifests while credentials remain outside the repository. Secret delivery still needs a controlled, auditable process.

## Monitoring and Backups Require Operational Validation

Installing Prometheus and Loki does not guarantee useful alerts or log coverage. Creating a backup does not prove it can be restored. Both need explicit operational tests.

## Demo Infrastructure Is Not Production Infrastructure

Self-signed in-cluster certificates, static demo passwords, mutable image tags, and broad test-environment assumptions must be revisited before production use.
