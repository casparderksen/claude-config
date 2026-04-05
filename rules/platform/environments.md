# Rules: Environment Promotion

---

## Core principle: build once, promote the artifact

- A Docker image is built exactly once per commit by Jenkins.
- The same image digest is promoted through environments — it is never rebuilt per environment.
- Environment-specific configuration is injected at deploy time via Helm values,
  environment variables, or Vault secrets — never baked into the image.

## Environment topology

Three environments are standard: `dev`, `staging`, `production`.
- **dev** — continuous deployment from the main branch; instability acceptable.
- **staging** — mirrors production topology (same Helm chart, same replica counts,
  same resource limits). Used for final validation before promotion.
- **production** — promotion is a deliberate, manual act.

## Promotion flow

Jenkins builds image → pushes to registry with digest
↓
ArgoCD deploys digest to dev (automatic)
↓
Acceptance criteria met → update staging values file in GitOps repo
↓
ArgoCD deploys same digest to staging (automatic on Git commit)
↓
Staging sign-off → update production values file in GitOps repo
↓
ArgoCD deploys same digest to production (automatic on Git commit)

## Configuration differences

- Allowed between environments: replica counts, resource limits, Vault paths,
  external service URLs, feature flags.
- Never allowed: different application code, different image, different build flags.

## Promoting to production checklist

- Staging has run the target image digest without error.
- All automated tests (integration, contract) have passed against staging.
- Database migration has been reviewed and tested on staging.
- Rollback procedure is documented for this release.
