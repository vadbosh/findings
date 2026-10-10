#!/usr/bin/env bash
# tests/test_install.sh — install.sh, lib/wire.py and uninstall.sh.
#
#   bash tests/test_install.sh       every case, then a summary
#   bash tests/test_install.sh -q    failures and the summary only
#
# HOME is a temporary directory for every case: nothing here touches the real
# configuration or the real ledger. An installer bug is invisible on the run
# that introduces it and obvious on the second, so most cases run it three
# times and compare.

set -uo pipefail
# The session this suite runs in must not leak into its cases.
unset CLAUDE_CODE_SESSION_ID FINDINGS_SESSION

SRC="$(cd "$(dirname "$0")/.." && pwd)"
QUIET=0
[ "${1:-}" = "-q" ] && QUIET=1
TMP="$(mktemp -d)"
trap 'rm -r "$TMP"' EXIT
export PYTHONDONTWRITEBYTECODE=1

pass=0
fail=0
ok() { pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || printf '  ok    %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  FAIL  %s — %s\n' "$1" "$2"; }

H="$TMP/home"
fresh() {
    [ -d "$H" ] && rm -r "$H"
    mkdir -p "$H/.claude" "$H/.codex" "$H/.config/opencode" "$H/.local/bin"
    printf '{}\n' > "$H/.claude/settings.json"
    printf '{}\n' > "$H/.codex/hooks.json"
    printf '{\n  "plugin": ["./plugins/other.ts"]\n}\n' > "$H/.config/opencode/opencode.json"
}
inst()   { HOME="$H" XDG_STATE_HOME= bash "$SRC/install.sh" "$@" > "$TMP/out" 2>&1; }
uninst() { HOME="$H" XDG_STATE_HOME= bash "$SRC/uninstall.sh" "$@" > "$TMP/out" 2>&1; }

# Every hook command per event, sorted — duplication and rewrites both show.
shape() {
    python3 - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print("\n".join(sorted(f"{ev}\t{h.get('command')}" for ev, es in d.get("hooks", {}).items()
                       for e in es for h in e.get("hooks", []))))
PY
}
state() { # everything install.sh writes, as one comparable blob
    shape "$H/.claude/settings.json"; shape "$H/.codex/hooks.json"
    cat "$H/.config/opencode/opencode.json" "$H/.codex/AGENTS.md" 2>/dev/null
    (cd "$H" && find . -type f -not -path './.local/state/*' | sort)
}

fresh
if inst; then ok "first run over empty configs finishes"; else no "first run" "$(tail -5 "$TMP/out")"; fi
first="$(state)"
inst; inst
if [ "$first" = "$(state)" ]; then ok "three runs leave the same state"; else no "three runs leave the same state" "$(diff <(echo "$first") <(state) | head)"; fi

for f in .local/bin/findings .local/bin/findings-hook .local/bin/found-defects-guard \
         .claude/rules/found-defects-last.md .claude/commands/findings.md \
         .codex/memories/found-defects-last.md .codex/skills/findings/SKILL.md \
         .config/opencode/instructions/found-defects-last.md .config/opencode/commands/findings.md \
         .config/opencode/plugins/findings.ts; do
    [ -f "$H/$f" ] && ok "installed $f" || no "installed $f" "missing"
done
# The Codex skill is the command rebuilt by lib/skill.sh; a command edited
# without rebuilding it would ship two different instructions.
if diff <(bash "$SRC/lib/skill.sh") "$SRC/skills/findings/SKILL.md" >/dev/null; then
    ok "skills/findings/SKILL.md is what lib/skill.sh builds from the command"
else
    no "the Codex skill is stale" "run: bash lib/skill.sh > skills/findings/SKILL.md"
fi
grep -q '^name: findings$' "$H/.codex/skills/findings/SKILL.md" && ok "codex: the skill is named findings" || no "codex skill name" "$(head -3 "$H/.codex/skills/findings/SKILL.md")"
# Codex reads the same rule, and every example in it says `/findings` (F218).
grep -qF 'In Codex write `$findings`' "$H/.codex/memories/found-defects-last.md" \
    && ok "codex: the rule tells it to write \$findings" || no "codex rule" "no \$findings note in the installed rule"
[ -x "$H/.local/bin/findings" ] && ok "the CLI is executable" || no "the CLI is executable" "mode $(stat -c %a "$H/.local/bin/findings")"

claude="$(shape "$H/.claude/settings.json")"
[[ "$claude" == *"Stop	$H/.local/bin/found-defects-guard"* ]] && ok "claude: Stop hook wired" || no "claude: Stop hook" "$claude"
[[ "$claude" == *"UserPromptSubmit	$H/.local/bin/findings-hook"* ]] && ok "claude: UserPromptSubmit hook wired" || no "claude: UserPromptSubmit" "$claude"
[ "$(shape "$H/.codex/hooks.json" | wc -l)" -eq 2 ] && ok "codex: two hooks, once each" || no "codex: two hooks" "$(shape "$H/.codex/hooks.json")"
[ "$(grep -c 'found-defects-last.md$' "$H/.codex/AGENTS.md")" = 1 ] && ok "codex: AGENTS.md names the rule once" || no "codex: AGENTS.md" "$(cat "$H/.codex/AGENTS.md")"
oc="$(cat "$H/.config/opencode/opencode.json")"
[[ "$oc" == *'instructions/found-defects-last.md'* && "$oc" == *'other.ts'* ]] && ok "opencode: rule listed, foreign plugin kept" || no "opencode.json" "$oc"
grep -q 'install verification' "$TMP/out" && no "verification left no trace in the real ledger" "printed?" || true
[ ! -e "$H/.local/state/findings/ledger.jsonl" ] && ok "install verification used a throwaway ledger" || no "verification wrote the ledger" "$(cat "$H/.local/state/findings/ledger.jsonl")"

# A foreign hook on the same event is kept; a hand-made entry for ours is not doubled.
fresh
python3 - "$H/.claude/settings.json" <<'PY'
import json, sys
json.dump({"hooks": {"Stop": [{"matcher": "", "hooks": [
    {"type": "command", "command": "/opt/other/stop.sh"},
    {"type": "command", "command": "/somewhere/else/found-defects-guard"}]}]},
    "model": "x"}, open(sys.argv[1], "w"))
PY
inst
claude="$(shape "$H/.claude/settings.json")"
[ "$(grep -c found-defects-guard <<< "$claude")" = 1 ] && ok "a hand-made entry for the guard is not doubled" || no "hand-made entry doubled" "$claude"
uninst
claude="$(shape "$H/.claude/settings.json")"
[[ "$claude" == *"/opt/other/stop.sh"* && "$claude" != *found-defects-guard* && "$claude" != *findings-hook* ]] \
    && ok "uninstall removes ours and keeps the foreign hook" || no "uninstall" "$claude"
grep -q '"model": "x"' "$H/.claude/settings.json" && ok "uninstall keeps unrelated keys" || no "unrelated keys" "$(cat "$H/.claude/settings.json")"
[ ! -e "$H/.local/bin/findings" ] && [ ! -e "$H/.claude/rules/found-defects-last.md" ] && ok "uninstall removes the files" || no "uninstall files" "$(ls -R "$H" | head)"
[ ! -e "$H/.codex/skills/findings" ] && ok "uninstall removes the Codex skill and its directory" || no "codex skill left" "$(ls -R "$H/.codex/skills" 2>&1 | head)"

# --dry-run writes nothing; --no-rule installs no rule.
fresh
before="$(state)"
inst --dry-run
[ "$before" = "$(state)" ] && ok "--dry-run changes nothing" || no "--dry-run" "$(diff <(echo "$before") <(state) | head)"
inst --no-rule
[ ! -e "$H/.claude/rules/found-defects-last.md" ] && [ ! -e "$H/.codex/AGENTS.md" ] && ok "--no-rule installs no rule" || no "--no-rule" "rule present"
[ -e "$H/.claude/commands/findings.md" ] && ok "--no-rule still installs the command" || no "--no-rule command" "missing"

# A symlink left by an earlier, different install is replaced by a file.
fresh
ln -s /nonexistent/findings "$H/.local/bin/findings"
inst
[ -f "$H/.local/bin/findings" ] && [ ! -L "$H/.local/bin/findings" ] && ok "a stale symlink is replaced by the file" || no "stale symlink" "$(ls -l "$H/.local/bin/findings")"

# A configuration that is not plain JSON is left alone, and the run says so.
fresh
printf '{ // comment\n}\n' > "$H/.claude/settings.json"
inst --ide claude; rc=$?
[ "$rc" -ne 0 ] && grep -q 'NOT wired' "$TMP/out" && ok "JSON with comments: left untouched, reported" || no "jsonc" "rc=$rc $(tail -3 "$TMP/out")"
grep -q '// comment' "$H/.claude/settings.json" && ok "JSON with comments: content intact" || no "jsonc content" "$(cat "$H/.claude/settings.json")"

# Windows wiring (README.WIN.md): hooks run through an interpreter. Claude Code
# gets the exec form (command + args), Codex a command string; both must be
# recognised as ours on the next run and on --remove.
fresh
w() { HOME="$H" python3 "$SRC/lib/wire.py" "$@" >/dev/null 2>&1; }
for i in 1 2 3; do w claude --bin 'C:\Users\me\.local\bin' --python python; w codex --bin 'C:\Users\me\.local\bin' --python python; done
c="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps(d["hooks"]["Stop"]))' "$H/.claude/settings.json" 2>&1)"
[[ "$c" == *'"command": "python", "args": ['* ]] && [ "$(grep -o found-defects-guard <<< "$c" | wc -l)" = 1 ] \
    && ok "--python: claude gets the exec form, once after three runs" || no "--python claude" "$c"
x="$(cat "$H/.codex/hooks.json")"
[ "$(grep -o 'python \\"C:' <<< "$x" | wc -l)" = 2 ] && ok "--python: codex gets 'python \"script\"', once per hook" || no "--python codex" "$x"
w claude --remove; w codex --remove
! grep -q 'found-defects-guard\|findings-hook' "$H/.claude/settings.json" "$H/.codex/hooks.json" \
    && ok "--python: --remove recognises both forms" || no "--python remove" "$(cat "$H/.claude/settings.json" "$H/.codex/hooks.json")"

echo "install: passed $pass, failed $fail"
[ "$fail" -eq 0 ]
