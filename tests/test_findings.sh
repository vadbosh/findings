#!/usr/bin/env bash
# tests/test_findings.sh — the ledger of rules/found-defects-last.md.
#
#   bash tests/test_findings.sh       every case, then a summary
#   bash tests/test_findings.sh -q    failures and the summary only (sync.sh)
#
# Covers bin/findings (record, routing, dedupe, set, list, count), the ledger
# write in bin/found-defects-guard, and bin/findings-hook. Everything runs in a
# temporary FINDINGS_DIR and two throwaway git repositories; the real ledger in
# ~/.local/state/findings is never touched.

set -uo pipefail
# The session this suite runs in must not leak into its cases.
unset CLAUDE_CODE_SESSION_ID FINDINGS_SESSION

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HERE/../bin"
QUIET=0
[ "${1:-}" = "-q" ] && QUIET=1

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export FINDINGS_DIR="$TMP/state" FOUND_DEFECTS_GUARD_LOG="$TMP/guard.log"
export PYTHONDONTWRITEBYTECODE=1
A="$TMP/repo-a" B="$TMP/repo-b"
for r in "$A" "$B"; do mkdir -p "$r/sub" && git -C "$r" init -q && touch "$r/sub/file.txt"; done

pass=0
fail=0
check() { # what, expected substring, actual
    if [[ "$3" == *"$2"* ]]; then
        pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || printf '  ok    %s\n' "$1"
    else
        fail=$((fail + 1)); printf '  FAIL  %s\n        want: %s\n        got:  %s\n' "$1" "$2" "$3"
    fi
}
absent() { # what, unexpected substring, actual
    if [[ "$3" != *"$2"* ]]; then
        pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || printf '  ok    %s\n' "$1"
    else
        fail=$((fail + 1)); printf '  FAIL  %s\n        must not contain: %s\n        got: %s\n' "$1" "$2" "$3"
    fi
}
f() { "$BIN/findings" "$@" 2>&1; }

NL=$'\n'
REPLY="Готово.${NL}${NL}## Найдено по ходу${NL}${NL}"
REPLY+="1. [связано] \`$A/sub/file.txt:3\` — устаревший комментарий — строка 3. Исправить?${NL}"
REPLY+="2. [не связано] \`$B/sub/file.txt\` — два владельца — diff. Исправить?${NL}"
REPLY+="3. [срочно][не связано] prod: алерт горит 7 дней — не проверено. Исправить?"

out="$(printf '%s' "$REPLY" | f record --cwd "$A/sub" --session s1)"
check "records three items"                 "added F3" "$out"
check "a path in repo B is filed under B"   "added F2 — $B" "$out"
check "no path: filed under the cwd repo"   "added F3 — $A" "$out"

out="$(printf '%s' "$REPLY" | f record --cwd "$A/sub" --session s2)"
check "the same section again adds nothing" "" "$out"
[ -z "$out" ] && { pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    dedupe is silent"; } \
              || { fail=$((fail + 1)); echo "  FAIL  dedupe printed: $out"; }

out="$(f list --scope project -p "$A")"
check "list shows the urgent one first"     "  F3 [urgent][unrelated]" "$(printf '%s' "$out" | sed -n 2p)"
check "tags are normalised from Russian"    "F1 [related]" "$out"
absent "list of A hides B's finding"        "два владельца" "$out"
check "list --all shows B too"              "два владельца" "$(f list --all)"

check "count line"                          "2 open, 1 urgent, 0 parked" "$(f count -p "$A")"
check "park via shorthand, a range"         "park: F1, F2" "$(f park 1-2)"
check "parked stays in the digest"          "(park)" "$(f list -p "$A")"
check "skip hides it from the digest"       "skip: F1" "$(f skip F1)"
absent "skipped is not listed"              "устаревший" "$(f list -p "$A")"
check "unknown id is refused"               "no such id: F99" "$(f set done 99)"
f set done 3 >/dev/null
out="$(printf '%s' "$REPLY" | f record --cwd "$A/sub" --session s3)"
check "a done finding found again is a regression: new id" "added F4" "$out"

# The guard writes the ledger on every stop, the continuation included.
G="$BIN/found-defects-guard"
SECOND="## Found along the way${NL}${NL}1. [related] \`$A/sub/file.txt:9\` — new bug — checked. Fix?"
jq -nc --arg m "$SECOND" --arg c "$A" '{stop_hook_active:true,cwd:$c,session_id:"g",last_assistant_message:$m}' | "$G" >/dev/null
check "guard records on the second stop"    "new bug" "$(f list -p "$A")"
out="$(jq -nc --arg m "$SECOND" --arg c "$A" '{stop_hook_active:false,cwd:$c,last_assistant_message:$m}' | FINDINGS_RECORD=off "$G")"
[ -z "$out" ] && { pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    a clean reply still passes the guard"; } \
              || { fail=$((fail + 1)); echo "  FAIL  guard output: $out"; }

# Session scope: what this session found, wherever it was filed, plus a count of the rest.
out="$(FINDINGS_SESSION=s1 f list -p "$A")"
check "session: its parked finding in another project is shown" "два владельца" "$out"
absent "session: another session's finding is not listed"       "new bug" "$out"
check "session: one line counts the rest of the project"        "+2 open in $A from other sessions" "$out"
check "session: an id prefix is enough"                          "new bug" "$(f list --session g -p "$A")"
out="$(f list -p "$A")"
check "no session id: whole project, and says so"                "no session id" "$out"
check "no session id: the project is listed"                     "new bug" "$out"
out="$(FINDINGS_SESSION=s1 f list --scope project -p "$A")"
check "--scope project ignores the session"                      "new bug" "$out"
f list --scope session -p "$A" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && { pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    --scope session without an id is refused"; } \
               || { fail=$((fail + 1)); echo "  FAIL  --scope session without an id: rc=$rc"; }
out="$(jq -nc --arg c "$TMP" '{cwd:$c,session_id:"g"}' | "$BIN/findings-hook" | jq -r .hookSpecificOutput.additionalContext)"
check "hook names the session even where the project is empty"  "This session (g): 1 open" "$out"

# The prompt hook: urgent ones listed, silence when nothing is open.
out="$(jq -nc --arg c "$A/sub" '{cwd:$c}' | "$BIN/findings-hook")"
check "hook reports the open count"         "open, 1 urgent" "$(printf '%s' "$out" | jq -r .hookSpecificOutput.additionalContext)"
check "hook lists the urgent finding"       "URGENT F4" "$(printf '%s' "$out" | jq -r .hookSpecificOutput.additionalContext)"
out="$(jq -nc --arg c "$TMP" '{cwd:$c}' | "$BIN/findings-hook")"
[ -z "$out" ] && { pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    hook is silent for a project without findings"; } \
              || { fail=$((fail + 1)); echo "  FAIL  hook spoke for an empty project: $out"; }

# The switches mean the same in every assistant.
THIRD="## Found along the way${NL}${NL}1. [related] \`$B/sub/file.txt:5\` — switch test — checked. Fix?"
jq -nc --arg m "$THIRD" --arg c "$B" '{stop_hook_active:false,cwd:$c,last_assistant_message:$m}' \
    | FOUND_DEFECTS_GUARD=off "$G" >/dev/null
check "FOUND_DEFECTS_GUARD=off still records" "switch test" "$(f list -p "$B")"
FOURTH="## Found along the way${NL}${NL}1. [related] \`$B/sub/file.txt:6\` — must not be recorded — checked. Fix?"
out="$(printf '%s' "$FOURTH" | FINDINGS_RECORD=off f record --cwd "$B")"
absent "FINDINGS_RECORD=off: findings record writes nothing (the Opencode path)" "must not be recorded" "$(f list -p "$B") $out"

# Parked only: nothing open, so the hook stays silent.
f set park 2 >/dev/null; f set done 5 >/dev/null
for i in $(f list -p "$B" --status open | sed -n 's/^  F\([0-9]*\).*/\1/p'); do f set park "$i" >/dev/null; done
out="$(jq -nc --arg c "$B" '{cwd:$c}' | "$BIN/findings-hook")"
[ -z "$out" ] && { pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    hook is silent when only parked findings remain"; } \
              || { fail=$((fail + 1)); echo "  FAIL  hook spoke with nothing open: $out"; }

# ── Compaction and the archive, on a ledger of their own ────────────────────
export FINDINGS_DIR="$TMP/compact"
printf '%s' "$REPLY" | f record --cwd "$A/sub" --session c1 >/dev/null     # F1 A, F2 B, F3 A urgent
f skip 1 >/dev/null; f done 3 >/dev/null; f park 2 >/dev/null
before="$(f list --scope all --status any)"
out="$(f compact)"
check "compact reports what it did"              "compacted: 3 findings — 3 kept, 0 archived" "$out"
[ "$before" = "$(f list --scope all --status any)" ] && { pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    compact loses nothing: same view before and after"; } \
    || { fail=$((fail + 1)); echo "  FAIL  compact changed the view"; diff <(echo "$before") <(f list --scope all --status any); }
! grep -q '"op": "set"' "$FINDINGS_DIR/ledger.jsonl" && { pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    compact folds every set into its record"; } \
    || { fail=$((fail + 1)); echo "  FAIL  set events left after compact"; }

out="$(FINDINGS_ARCHIVE_DAYS=0 f compact)"
check "done findings go to the archive"          "2 kept, 1 archived" "$out"
check "list --archive shows them"                "(done)" "$(f list --archive --all)"
absent "the ledger no longer lists them"         "алерт горит" "$(f list --scope all --status any)"
check "set on an archived id says where it went" "archived (done): F3" "$(f set open 3)"
out="$(printf '%s' "$REPLY" | f record --cwd "$A/sub" --session c2)"
absent "a skipped finding does not come back"    "устаревший" "$(f list --scope all --status open)"
check "an archived done finding found again is new, with a fresh id" "added F4" "$out"

export FINDINGS_COMPACT_BYTES=1
printf '%s' "## Found along the way${NL}${NL}1. [related] \`$A/sub/file.txt:7\` — auto — x. Fix?" | f record --cwd "$A" --session c3 >/dev/null
unset FINDINGS_COMPACT_BYTES
head -1 "$FINDINGS_DIR/ledger.jsonl" | grep -q '"op": "meta"' && { pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    compaction runs by itself past FINDINGS_COMPACT_BYTES"; } \
    || { fail=$((fail + 1)); echo "  FAIL  no automatic compaction: $(head -1 "$FINDINGS_DIR/ledger.jsonl")"; }
check "ids continue after compaction and archiving" "F5" "$(f list --scope all --status any)"
[ -e "$FINDINGS_DIR/ledger.jsonl.prev" ] && { pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    the previous ledger is kept as ledger.jsonl.prev"; } \
    || { fail=$((fail + 1)); echo "  FAIL  no ledger.jsonl.prev"; }

echo "findings: passed $pass, failed $fail"
[ "$fail" -eq 0 ]
