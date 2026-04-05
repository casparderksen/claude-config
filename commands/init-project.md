# /init-project

Initialises Claude Code for the current project.

Invokes the `init-project` skill, which will:
1. Detect the project type from filesystem signals (pom.xml, angular.json, Dockerfile, etcetera)
2. Confirm the detected type and rule modules with the user before making any changes
3. Copy the relevant rule files from `~/.claude/rules-library/` into `.claude/rules/`
4. Scaffold a minimal `.claude/CLAUDE.md` for this project
5. Ask whether to commit or gitignore the `.claude/` directory

Run this once per project before beginning substantive work.
