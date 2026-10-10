#!/usr/bin/env bash
# Uninstall findings — the reverse of install.sh.
#
#   ./uninstall.sh              unwire and remove from every assistant found
#   ./uninstall.sh --dry-run    print what would happen, change nothing
#
# The ledger (~/.local/state/findings/ledger.jsonl) is kept: it is your data,
# and installing again picks it up where it was. Delete it by hand if you mean to.
set -euo pipefail

# Not ${1/#$HOME/\~}: bash 3.2, the one macOS ships, keeps the backslash and
# prints \~/.claude — measured in the bash:3.2 image.
tilde() { case "$1" in "$HOME"*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }


SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

say() { printf '%s\n' "$*"; }
remove_file() {
    [ -e "$1" ] || [ -L "$1" ] || return 0
    if [ "$DRY_RUN" -eq 1 ]; then say "    would remove $(tilde "$1")"; return; fi
    rm -f "$1"; say "    - $(tilde "$1")"
}

for ide in claude codex opencode; do
    case "$ide" in
        claude)   [ -d "$HOME/.claude" ] || continue ;;
        codex)    [ -d "$HOME/.codex" ] || continue ;;
        opencode) [ -d "$HOME/.config/opencode" ] || continue ;;
    esac
    say "── $ide ──"
    args=("$ide" --remove); [ "$DRY_RUN" -eq 1 ] && args+=(--dry-run)
    PYTHONDONTWRITEBYTECODE=1 python3 "$SRC/lib/wire.py" "${args[@]}" || true
    case "$ide" in
        claude)   remove_file "$HOME/.claude/rules/found-defects-last.md"
                  remove_file "$HOME/.claude/commands/findings.md" ;;
        codex)    remove_file "$HOME/.codex/memories/found-defects-last.md"
                  remove_file "$HOME/.codex/skills/findings/SKILL.md"
                  rmdir "$HOME/.codex/skills/findings" 2>/dev/null || true ;;
        opencode) remove_file "$HOME/.config/opencode/instructions/found-defects-last.md"
                  remove_file "$HOME/.config/opencode/commands/findings.md"
                  remove_file "$HOME/.config/opencode/plugins/findings.ts" ;;
    esac
done

say "── commands ──"
for f in findings findings-hook found-defects-guard; do remove_file "$BIN_DIR/$f"; done
say "The ledger stays: ${XDG_STATE_HOME:-$HOME/.local/state}/findings/"
