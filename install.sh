#!/usr/bin/env bash
# Install findings — Linux / macOS.
#
#   ./install.sh                 install into every assistant found
#   ./install.sh --dry-run       print what would happen, change nothing
#   ./install.sh --ide NAME      only claude, codex or opencode
#   ./install.sh --no-rule       hooks, plugin and command only, no rule file
#
# What goes where:
#   ~/.local/bin/                      findings, findings-hook, found-defects-guard
#   ~/.claude/rules/  ~/.codex/memories/  ~/.config/opencode/instructions/
#                                      found-defects-last.md, the rule
#   ~/.claude/commands/  ~/.config/opencode/commands/
#                                      findings.md, the /findings command
#   ~/.codex/skills/findings/          SKILL.md, the same command as `$findings`
#                                      (Codex has no user slash commands)
#   ~/.config/opencode/plugins/        findings.ts
#   settings.json, hooks.json, opencode.json, AGENTS.md
#                                      wired by lib/wire.py
#
# Idempotent: a second run changes nothing. A file it would overwrite with
# different content is backed up to ~/.local/state/findings/backups/ first —
# outside every directory an assistant reads, so a backup never loads as a
# second rule. The ledger itself (~/.local/state/findings/ledger.jsonl) is
# never touched. Nothing outside $HOME is written.
set -euo pipefail

# Not ${1/#$HOME/\~}: bash 3.2, the one macOS ships, keeps the backslash and
# prints \~/.claude — measured in the bash:3.2 image.
tilde() { case "$1" in "$HOME"*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }


SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/findings"
DRY_RUN=0
WITH_RULE=1
ONLY_IDE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --no-rule) WITH_RULE=0 ;;
        --ide)     ONLY_IDE="${2:-}"; shift ;;
        -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}" | sed -e 's/^# //' -e 's/^#$//'; exit 0 ;;
        *)         echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

say() { printf '%s\n' "$*"; }
bad() { printf '%s\n' "$*" >&2; }

command -v python3 >/dev/null 2>&1 || { bad "findings needs python3 (3.8 or newer)"; exit 1; }
python3 -c 'import sys; sys.exit(sys.version_info < (3, 8))' || { bad "findings needs python 3.8 or newer"; exit 1; }
command -v git >/dev/null 2>&1 || say "note: git not found — findings will file everything under the session's directory"

STAMP="$(date +%Y%m%d-%H%M%S)"

# install_file SRC DST [MODE] — copy if missing or different; back up what it replaces.
install_file() {
    local src="$1" dst="$2" mode="${3:-644}"
    if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then
        say "    = $(tilde "$dst")"; return
    fi
    if [ "$DRY_RUN" -eq 1 ]; then say "    would write $(tilde "$dst")"; return; fi
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ -f "$dst" ] && [ ! -L "$dst" ]; then
            mkdir -p "$STATE/backups" && chmod 700 "$STATE" "$STATE/backups"
            cp -p "$dst" "$STATE/backups/$(basename "$dst").bak.$STAMP"
        fi
        rm -f "$dst"
        say "    ~ $(tilde "$dst")"
    else
        say "    + $(tilde "$dst")"
    fi
    cp "$src" "$dst"
    chmod "$mode" "$dst"
}

wire() { # wire IDE — exit code: 0 ok, 3 not set up, 1 failed
    local args=("$1" --bin "$BIN_DIR")
    [ "$WITH_RULE" -eq 1 ] || args+=(--no-rule)
    [ "$DRY_RUN" -eq 1 ] && args+=(--dry-run)
    set +e
    PYTHONDONTWRITEBYTECODE=1 python3 "$SRC/lib/wire.py" "${args[@]}"
    local rc=$?
    set -e
    return $rc
}

detect_ides() {
    if [ -n "$ONLY_IDE" ]; then printf '%s\n' "$ONLY_IDE"; return; fi
    [ -d "$HOME/.claude" ]          && printf 'claude\n'
    [ -d "$HOME/.codex" ]           && printf 'codex\n'
    [ -d "$HOME/.config/opencode" ] && printf 'opencode\n'
    return 0
}

say "── commands ──"
for f in findings findings-hook found-defects-guard; do
    install_file "$SRC/bin/$f" "$BIN_DIR/$f" 755
done
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) say "note: $BIN_DIR is not on PATH — the hooks use full paths, but add it to run findings by hand" ;; esac

unwired=""
found=0
while IFS= read -r ide; do
    [ -n "$ide" ] || continue
    found=1
    say "── $ide ──"
    case "$ide" in
        claude)
            [ "$WITH_RULE" -eq 1 ] && install_file "$SRC/rules/found-defects-last.md" "$HOME/.claude/rules/found-defects-last.md"
            install_file "$SRC/commands/findings.md" "$HOME/.claude/commands/findings.md" ;;
        codex)
            [ "$WITH_RULE" -eq 1 ] && install_file "$SRC/rules/found-defects-last.md" "$HOME/.codex/memories/found-defects-last.md"
            install_file "$SRC/skills/findings/SKILL.md" "$HOME/.codex/skills/findings/SKILL.md" ;;
        opencode)
            [ "$WITH_RULE" -eq 1 ] && install_file "$SRC/rules/found-defects-last.md" "$HOME/.config/opencode/instructions/found-defects-last.md"
            install_file "$SRC/commands/findings.md" "$HOME/.config/opencode/commands/findings.md"
            install_file "$SRC/plugins/opencode/findings.ts" "$HOME/.config/opencode/plugins/findings.ts" ;;
        *) bad "    unknown assistant: $ide"; exit 2 ;;
    esac
    rc=0; wire "$ide" || rc=$?
    case "$rc" in
        0) ;;
        3) say "    (no configuration file yet — start $ide once, then re-run)" ;;
        *) bad "    $ide was NOT wired — see the message above"; unwired="$unwired $ide" ;;
    esac
done < <(detect_ides)

[ "$found" -eq 1 ] || { bad "No assistant found (~/.claude, ~/.codex, ~/.config/opencode). Use --ide to force one."; exit 1; }

say "── verify ──"
if [ "$DRY_RUN" -eq 1 ]; then say "  dry run — nothing was installed"; exit 0; fi
tmp="$(mktemp -d)"; trap 'rm -r "$tmp"' EXIT
python3 - "$tmp" > "$tmp/payload.json" <<'PY'
import json, sys
reply = "Done.\n\n## Found along the way\n\n1. [related] `/tmp/x` — check — install verification. Fix?"
print(json.dumps({"cwd": sys.argv[1], "stop_hook_active": True, "last_assistant_message": reply}))
PY
FINDINGS_DIR="$tmp/state" PYTHONDONTWRITEBYTECODE=1 "$BIN_DIR/found-defects-guard" < "$tmp/payload.json"
if FINDINGS_DIR="$tmp/state" "$BIN_DIR/findings" list --all | grep -q 'install verification'; then
    say "  ok — a reply's section is recorded in the ledger"
else
    bad "  FAIL — the guard did not record the section"; exit 1
fi
if [ -n "$unwired" ]; then bad "Not wired:$unwired"; exit 1; fi
say ""
say "Restart your assistant: hooks, rules and plugins are read at start-up."
say "Then: /findings (Claude Code, Opencode) or \`findings list\` (any shell)."
