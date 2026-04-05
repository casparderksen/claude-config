# Rules: Kubernetes

## GitOps is the only deployment mechanism
- All Kubernetes manifests live in Git. ArgoCD is the sole actor that applies
  changes to any cluster.
- Never run `kubectl apply` directly against a non-local cluster.
- Raising a change = committing to the GitOps repository. ArgoCD syncs from there.

## Packaging
- Package every application as a Helm chart.
- Environment differences are expressed as Helm values files — never as separate
  charts or branching chart logic.
- Maintain a values file per environment: `values-dev.yaml`, `values-staging.yaml`,
  `values-production.yaml`.

## Image references
- Production manifests must reference images by digest (`@sha256:...`), never by
  a mutable tag such as `latest` or a branch name.
- Tags are acceptable in dev/staging for convenience, but staging should mirror
  production image references before a promotion is approved.

## Resource governance
- Every container must declare `resources.requests` and `resources.limits`.
- No container runs as root. Set `securityContext.runAsNonRoot: true` and supply
  a non-zero `runAsUser`.
- Set `readOnlyRootFilesystem: true` unless the application explicitly requires
  write access.

## Health probes (Quarkus)
- Liveness probe: `GET /q/health/live`
- Readiness probe: `GET /q/health/ready`
- Both probes are mandatory on every Quarkus deployment.
- Set appropriate `initialDelaySeconds` to account for JVM startup; do not rely
  on default values.

## Secrets
- Sensitive values are sourced from HashiCorp Vault exclusively.
- Use the Vault Agent Injector or External Secrets Operator — never Kubernetes
  `Secret` manifests for sensitive data.
- Kubernetes `Secret` objects are acceptable only for non-sensitive configuration
  (e.g. internal service URLs).

## Network policy
- Every namespace must have a default-deny NetworkPolicy.
- Explicitly allow only the ingress and egress paths required.

## Namespace strategy
- One namespace per environment per application (e.g. `payments-dev`,
  `payments-staging`, `payments-production`).
