# Skill: init-project

Initialises Claude Code configuration for a project by detecting its type,
copying the relevant rule files from the global rules library, and scaffolding
a minimal project-level CLAUDE.md.

## When to use

Invoke at the start of any new project before beginning substantive work.
Typically triggered via the `/init-project` slash command.

## Steps

### 1. Detect project type

Inspect the project root for the following signals and map them to rule modules:

| Signal                                        | Rule modules                                  |
|-----------------------------------------------|-----------------------------------------------|
| *(always)*                                    | `platform/environments.md`, `git/*.md`        |
| `pom.xml` + Quarkus dependency                | `backend/quarkus.md`, `java/*.md`             |
| `pom.xml` (generic)                           | `java/java.md`                                |
| `angular.json`                                | `frontend/*.md`                               |
| `openapi.yaml` / `openapi.json`               | `platform/openapi.md`                         |
| `Dockerfile` / `compose.yaml`                 | `platform/docker.md`                          |
| `*.tf` / `*.tofu`                             | `cloud/opentofu.md`                           |
| `aws-cdk.json` / `*.tf` targeting AWS         | `cloud/aws.md`                                |
| `*.tf` targeting GCP                          | `cloud/gcp.md`                                |

Multiple signals may match — collect all applicable modules.

### 2. Confirm with the user

Present the detected project type and the list of rule modules that will be
activated. Ask for confirmation before proceeding. Allow the user to select additional 
rule modules. Example:

> I detected: Quarkus + Angular project.
> Rule modules to activate: `java/quarkus.md`, `java/maven.md`, `frontend/angular.md`, `frontend/typescript.md`.
> Always included: `platform/environments.md`, `git/git.md`.
> Shall I proceed?

### 3. Create .claude/rules/

Create the `.claude/rules/` directory in the project root if it does not exist.

### 4. Copy rule files

Copy each confirmed rule module from `~/.claude/rules-library/` into
`.claude/rules/`, preserving the flat filename (strip the subdirectory prefix).
For example: `~/.claude/rules-library/java/quarkus.md` → `.claude/rules/quarkus.md`.

Always copy `platform/environments.md` and `git/git.md` regardless
of detected project type — they apply universally to all projects in this stack.

Do not symlink. Copy so that the rules can be committed to the project repository
independently of the user's personal config.

### 5. Scaffold project CLAUDE.md

Create `.claude/CLAUDE.md` in the project root (not the repo root) with the
following structure:

```markdown
# [Project Name] — Claude Project Configuration

## Project Type
[Detected type, e.g. "Quarkus REST API + Angular SPA"]

## Active Rules
The following rule modules are active in `.claude/rules/`:
- [list each copied rule file]

## Project-Specific Overrides
<!-- Add any project-specific instructions that do not belong in a shared rule file. -->
```

Derive the project name from the directory name, `pom.xml` `<artifactId>`, or
`package.json` `name` field, in that order of preference.

### 6. Offer to gitignore or commit

Ask the user whether to:
- **Commit** `.claude/rules/` and `.claude/CLAUDE.md` to the repository (recommended for teams)
- **Gitignore** `.claude/` entirely (recommended for solo or personal projects)

Add the appropriate entry to `.gitignore` if the user chooses to ignore.
