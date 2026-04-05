# Claude config

Personal Claude Code configuration — skills, commands, agents, and a modular rules library.
Designed to be installed once and reused across every project.

## Quickstart

```sh
git clone <your-repo-url> ~/projects/claude-config
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

```
claude-config/
├── install.sh                       # Idempotent installer
├── CLAUDE.md                        # Global preferences (symlinked to ~/.claude/CLAUDE.md)
│
├── skills/                          # Symlinked to ~/.claude/skills/
│   └── init-project.md              # Detects project type and wires rules
│
├── commands/                        # Symlinked to ~/.claude/commands/
│   └── init-project.md              # /init-project slash command
│
├── agents/                          # Symlinked to ~/.claude/agents/
│
└── rules/                           # Symlinked to ~/.claude/rules-library/
    ├── java/
    │   ├── quarkus.md
    │   ├── spring.md
    │   └── maven.md
    ├── frontend/
    │   ├── angular.md
    │   ├── react.md
    │   └── typescript.md
    ├── platform/
    │   ├── openapi.md
    │   ├── docker.md
    │   └── kubernetes.md
    └── cloud/
        ├── aws.md
        └── gcp.md
```

**`CLAUDE.md`** — Universal working preferences: communication style, commit conventions,
and a pointer to the rules library. Loaded by Claude Code in every session, globally.

**`skills/`** — Reusable instructional workflows. The `init-project` skill is the core
of this setup. Add further skills here for any repeatable workflow (e.g. generating
a release, running a DB migration, producing an ADR).

**`commands/`** — Slash commands, each wrapping a skill or a short one-off instruction.
Available in every project once installed.

**`agents/`** — Custom sub-agents for specialised or long-running tasks.

**`rules/`** — Modular, framework-specific coding conventions. Organised by domain.
Rules are never loaded globally; they are copied into a project on demand by the
`init-project` skill.

## How It Works

### Installation

`install.sh` creates symlinks from this repository into `~/.claude/`:

| Repository path | Symlinked to              |
|-----------------|---------------------------|
| `CLAUDE.md`     | `~/.claude/CLAUDE.md`     |
| `skills/`       | `~/.claude/skills/`       |
| `commands/`     | `~/.claude/commands/`     |
| `agents/`       | `~/.claude/agents/`       |
| `rules/`        | `~/.claude/rules-library/`|

If an existing `~/.claude/CLAUDE.md` is found that is not already a symlink, it is
backed up with a timestamp before being replaced. The script is idempotent: re-running
it after a `git pull` refreshes all symlinks without further action.

### Project initialisation

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
activates `quarkus.md`, `maven.md`, `angular.md`, and `typescript.md` as four
independent files — no merging, no coupling.

Fill in the placeholder comments in each rule file with your own conventions.
The files are yours to version-control, share, or fork.

### Adding a new rule module

1. Create a `.md` file in the appropriate `rules/<domain>/` directory.
2. Add a detection signal → rule module mapping to `skills/init-project.md`.
3. The new module is immediately available for all future project initialisations.

### Adding a new skill or command

Drop a `.md` file into `skills/` or `commands/`. It is available globally as soon
as the file exists — no reinstall required, because the directories are symlinked.
