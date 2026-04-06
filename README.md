# Claude config

Personal Claude Code configuration — skills, commands, agents, and a modular rules library.
Designed to be installed once and reused across every project.

## Quickstart

```sh
$ git clone https://github.com/casparderksen/claude-config.git claude-config
$ cd claude-config
./setup-claude.sh
```

Then, in any new project:

```sh
$ claude   # open Claude Code
> /init-project
```

Claude will detect the project type, confirm the rule modules to activate,
and wire everything into `.claude/` for you.

## Overview

### Installation

`setup-claude.sh` creates symlinks from this repository into `~/.claude/`:

| Repository path | Symlinked to                  |
|-----------------|-------------------------------|
| `CLAUDE.md`     | `~/.claude/CLAUDE.md`         |
| `settings.json` | `~/.claude/settings.json`     |
| `skills/`       | `~/.claude/skills/`           |
| `commands/`     | `~/.claude/commands/`         |
| `agents/`       | `~/.claude/agents/`           |
| `rules/`        | `~/.claude/rules-library/`    |

If an existing file in `~/.claude` is found that is not already a symlink, it is not overwritten.
The script is idempotent: re-running it after a `git pull` refreshes all symlinks without further action.

### Project initialisation skill

When you run `/init-project` in a new project, the `init-project` skill:

1. **Detects** the project type by inspecting the project root for known signals
   (`pom.xml`, `angular.json`, `Dockerfile`, OpenAPI specs, Terraform files, etc.).
2. **Confirms** the detected type and the list of rule modules to activate.
3. **Copies** the relevant rule files from `~/.claude/rules-library/` into the
   project's `.claude/rules/`. Files are copied — not symlinked — so they can be
   committed to the project repository independently of your personal config.
4. **Scaffolds** a minimal `.claude/CLAUDE.md` declaring the project type and
   listing the active rules.
5. **Asks** whether to commit `.claude/` to the repository or add it to `.gitignore`.

### Rules

Rule files are plain Markdown. Each file contains conventions for one framework or
concern. They are intentionally kept separate so that a Quarkus + Angular project
activates `quarkus.md`, `java.md`, `angular.md`, and `typescript.md` as four
independent files — no merging, no coupling.

### Available rule modules

| Module            | Path                              | Description                                                           |
|-------------------|-------------------------------- --|-----------------------------------------------------------------------|
| `java`            | `rules/java/java.md`              | Java code style, idioms, and language conventions                     |
| `quarkus`         | `rules/backend/quarkus.md`        | Quarkus backend development standards (REST, CDI, persistence)        |
| `angular`         | `rules/frontend/angular.md`       | Angular project structure, component, and module conventions          |
| `typescript`      | `rules/frontend/typescript.md`    | TypeScript compiler configuration and type-safety rules               |
| `design-system`   | `rules/frontend/design-system.md` | Theming tokens, typography, colour, spacing, and iconography          |
| `ux`              | `rules/frontend/ux.md`            | Interaction patterns, states, accessibility, and responsive behaviour |
| `git`             | `rules/git/git.md`                | Branching strategy, commit conventions, and merge policies            |
| `docker`          | `rules/platform/docker.md`        | Container image conventions and multi-stage build patterns            |
| `kubernetes`      | `rules/platform/kubernetes.md`    | GitOps-only deployments via ArgoCD; manifest standards                |
| `openapi`         | `rules/platform/openapi.md`       | API spec conventions (spec-first, versioning, schema naming)          |
| `environments`    | `rules/platform/environments.md`  | Environment promotion strategy (build once, promote the artifact)     |
| `aws`             | `rules/cloud/aws.md`              | AWS resource conventions, IAM patterns, and tagging strategy          |
| `gcp`             | `rules/cloud/gcp.md`              | GCP project structure, service account policy, and IaC conventions    |

The platform and cloud modules are placeholders and need elaboration.

### Adding a new rule module

1. Create a `.md` file in the appropriate `rules/<domain>/` directory.
2. Add a detection signal → rule module mapping to `skills/init-project.md`.
3. The new module is immediately available for all future project initialisations.

### Adding a new skill or command

Drop a `.md` file into `skills/` or `commands/`. It is available globally as soon
as the file exists — no reinstall required, because the directories are symlinked.
