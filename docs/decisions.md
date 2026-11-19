# Architecture Decisions

This document records the rationale behind key architecture choices. It describes the repository's current design, not an endorsement of every choice for production.

## ADR-001: Use VM Nginx in Front of Ingress-Nginx

**Decision:** Terminate public TLS on VM Nginx and forward application traffic to one Ingress-Nginx address.

**Context:** The application runs on Kind, whose LoadBalancer address is reachable from the VM but is not a public entry point.

**Consequences:** One public proxy handles host routing and TLS; the Ingress controller routes to internal ClusterIP Services. The Nginx upstream must be updated if the cluster's Ingress address changes.

## ADR-002: Keep Application Services Internal

**Decision:** Use ClusterIP Services and expose the application through Ingress.

**Context:** Multiple independently exposed LoadBalancers are unnecessary for this demo environment.

**Consequences:** Routing and CORS must be correctly configured at the ingress edge. MongoDB remains internal and is not included in public routing.

## ADR-003: Use a MongoDB StatefulSet Replica Set

**Decision:** Run three MongoDB members as a StatefulSet with stable DNS identities, per-Pod PVCs, and replica set `rs0`.

**Context:** MongoDB requires coordinated replication and persistent member identities; merely scaling a Deployment would not synchronize data.

**Consequences:** The design requires persistent storage, a headless Service, and a bootstrap Job. It also requires monitoring replica-set health and testing recovery.

## ADR-004: Keep Video Blobs in External S3-Compatible Storage

**Decision:** Store video/HLS assets in the course-provided Garage service and metadata in MongoDB.

**Context:** Large media objects are better suited to object storage than database documents or ephemeral container filesystems.

**Consequences:** Backend and streamer require external S3 connectivity and credentials. Database backups do not back up the object-store contents.

## ADR-005: Use Relative Frontend API and Stream Paths

**Decision:** Configure browser-facing paths as `/api` and `/stream`.

**Context:** Viewer and admin frontends run on different hostnames but share backend and streamer routes.

**Consequences:** The same relative URLs work on both hosts and route through VM Nginx and Ingress.

## ADR-006: Proxy Keycloak on the Admin Host

**Decision:** Proxy Keycloak realm and resource endpoints through VM Nginx on the admin hostname.

**Context:** The browser-facing environment requires the OIDC flow to remain reachable through the admin domain.

**Consequences:** Cookie domains, redirects, response URLs, and Keycloak client redirect URIs must remain aligned and be regression-tested after configuration changes.

## ADR-007: Separate GitOps Manifests from Credentials

**Decision:** Argo CD synchronizes `k8s/app/`; credentials are configured separately.

**Context:** Secrets must not be committed to the repository.

**Consequences:** The cluster must receive required ConfigMaps and Secrets through a separate process. The Argo CD repository URL must be set to the actual GitHub repository.

## ADR-008: Use HPA for Backend and Streamer

**Decision:** Scale backend and streamer between 2 and 5 replicas at a CPU utilization target of 50%.

**Context:** These stateless services are the primary candidates for request-driven horizontal scaling.

**Consequences:** Metrics Server and CPU requests are required. HPA behavior should be checked under representative load; this setting is a course/demo configuration rather than a capacity guarantee.
