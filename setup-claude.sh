#!/usr/bin/env zsh
# setup-claude.sh — Idempotent installer for claude-config.
# Symlinks global Claude Code configuration into ~/.claude/.

set -euo pipefail

### Helpers

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

info()    { echo -e "${BOLD}${GREEN}▶ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()   { echo -e "${RED}✖ $*${RESET}" >&2; exit 1; }

### Determine directories

REPO_DIR="${0:A:h}"
CLAUDE_DIR="${HOME}/.claude"

info "Installing claude-config from ${REPO_DIR}"

### Ensure ~/.claude exists

mkdir -p "${CLAUDE_DIR}"

### Symlink top-level artefacts

info "Linking files..."

symlink() {
  local src="${REPO_DIR}/${1}"
  local dst="${CLAUDE_DIR}/${2:-${1}}"

  if [[ -L "${dst}" ]]; then
    echo "↺ Updating symlink: ${dst}"
    ln -sf "${src}" "${dst}"
  elif [[ -e "${dst}" ]]; then
    warn "${dst} exists and is not a symlink — skipping. Remove it manually to proceed."
  else
    echo "✔ Linking: ${dst} → ${src}"
    ln -s "${src}" "${dst}"
  fi
}

symlink "CLAUDE.md"
symlink "settings.json"
symlink "skills"
symlink "commands"
symlink "agents"
symlink "rules" "rules-library"

### Done

echo ""
echo "${BOLD}${GREEN}✔ Claude Code config installed!!${RESET}"
echo ""
echo "   Next steps:"
echo "   • Open a project and run: /init-project"
echo "   • Or invoke the skill directly: 'run the init-project skill'"
