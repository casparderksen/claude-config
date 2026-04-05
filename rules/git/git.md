# Rules: Git

---

## Branching

- Use trunk-based development; keep branches short-lived (1–2 days maximum).
- Branch naming: `<type>/<ticket-id>-<short-description>`
  e.g. `feat/ORD-42-place-order`, `fix/ORD-107-duplicate-payment`, `chore/ORD-88-upgrade-quarkus`
- Allowed types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`
- Never commit directly to `main`; always go through a pull request.

## Commits

- Follow Conventional Commits: `<type>(<scope>): <description>`
  e.g. `feat(orders): add place order use case`
  e.g. `fix(payments): handle duplicate payment gateway response`
- Scope maps to the bounded context or module, not a layer.
- One logical change per commit; do not mix refactoring with feature work.
- Write the description in imperative mood — "add", "fix", "remove", not "added" or "fixes".
- Reference the ticket id in the commit body, not the subject line.
- Keep subject lines under 72 characters.
- Do not include AI-generated attribution in commit messages.

## Pull Requests

- One PR per feature or fix; keep PRs small and reviewable in under 30 minutes.
- PR title follows the same Conventional Commits format as commit messages.
- PR description must include: what changed, why, and any migration or deployment notes.
- Do not merge a PR with unresolved review comments.
- Squash merge into `main` to keep history linear and readable.

## Commit Scope Examples

| Scope      | Meaning                         |
|------------|---------------------------------|
| `orders`   | Order bounded context           |
| `payments` | Payment bounded context         |
| `auth`     | Authentication / authorisation  |
| `infra`    | Infrastructure or build changes |
| `deps`     | Dependency upgrades             |

## What Not to Commit

- Never commit secrets, credentials, or environment-specific configuration.
- Never commit generated files (MapStruct generated sources, compiled assets).
- Never commit commented-out code; delete it — Git history preserves it.
- Never commit failing tests or code that does not compile.
