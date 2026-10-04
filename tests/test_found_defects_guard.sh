#!/usr/bin/env bash
# tests/test_found_defects_guard.sh — the decisions of bin/found-defects-guard.
#
#   bash tests/test_found_defects_guard.sh       every case, then a summary
#   bash tests/test_found_defects_guard.sh -q    failures and the summary only (sync.sh)
#
# The guard reads a Stop payload on stdin and answers in one of two ways:
#   exit 0, no output           pass — the reply may end
#   exit 0 + decision:block     the reply continues once to add the section
# Each case states which one it expects. The log goes to a temp file.

set -uo pipefail
# The session this suite runs in must not leak into its cases.
unset CLAUDE_CODE_SESSION_ID FINDINGS_SESSION

HERE="$(cd "$(dirname "$0")" && pwd)"
GUARD="${FOUND_DEFECTS_GUARD_BIN:-$HERE/../bin/found-defects-guard}"
QUIET=0
[ "${1:-}" = "-q" ] && QUIET=1
FOUND_DEFECTS_GUARD_LOG="$(mktemp)"
# The guard also records each reply's section in the findings ledger. These
# replies are fixtures: they go to a throwaway ledger, never the real one.
FINDINGS_DIR="$(mktemp -d)"
export FOUND_DEFECTS_GUARD_LOG FINDINGS_DIR PYTHONDONTWRITEBYTECODE=1
trap 'rm -rf "$FOUND_DEFECTS_GUARD_LOG" "$FINDINGS_DIR"' EXIT

pass=0
fail=0

run() { # reply, [stop_hook_active]
    jq -nc --arg m "$1" --argjson a "${2:-false}" \
        '{hook_event_name:"Stop",session_id:"t",cwd:"/tmp",stop_hook_active:$a,last_assistant_message:$m}' \
        | "$GUARD"
}

expect() { # pass|block, what, reply, [stop_hook_active]
    local out got
    out="$(run "$3" "${4:-false}")"
    # A notice alone (systemMessage, no decision) still lets the reply end.
    if [ -z "$out" ] || printf '%s' "$out" | jq -e 'has("decision") | not' >/dev/null 2>&1; then got=pass
    elif printf '%s' "$out" | jq -e '.decision == "block"' >/dev/null 2>&1; then got=block
    else got="unexpected: $out"; fi
    if [ "$got" = "$1" ]; then
        pass=$((pass + 1))
        [ "$QUIET" -eq 1 ] || printf '  ok    %-6s %s\n' "$1" "$2"
    else
        fail=$((fail + 1))
        printf '  FAIL  %s  (expected %s, got %s)\n' "$2" "$1" "$got"
    fi
}

NL=$'\n'

expect pass  "plain report"            "Готово: тесты прошли.${NL}${NL}## Предлагаю${NL}1. Запушить."
expect block "the case that made it"   "Сделал X.${NL}${NL}Ещё нашёл ошибку в каноне: lib/x.py считает лишнее. Отдельная задача, если нужна."
expect block "исправить отдельно"      "Сделал X. Баг в парсере можно исправить отдельно."
expect block "попутно заметил"         "Сделал X. Попутно заметил, что README устарел."
expect block "en: also noticed"        "Done. I also noticed the cache key is wrong."
expect block "en: out of scope"        "Done. The flaky test is out of scope here."
expect block "en: separate task"       "Done. Renaming the module is a separate task."
expect pass  "defect in final section" "Сделал X.${NL}${NL}## Предлагаю${NL}1. Запушить.${NL}${NL}## Найдено попутно${NL}1. [не связано] \`lib/x.py:41\` — отдельная задача — проверено. Исправить?"
expect pass  "en final section"        "Done.${NL}${NL}## Found along the way${NL}1. [unrelated] \`a.py\` — out of scope bug — unverified. Fix?"
expect block "section not last"        "Сделал X.${NL}${NL}## Найдено попутно${NL}1. [связано] a — b — c. Исправить?${NL}${NL}## Предлагаю${NL}1. Запушить."
expect block "phrase before section"   "Ещё нашёл баг в y.${NL}${NL}## Найдено попутно${NL}1. [связано] x — z — c. Исправить?"
expect pass  "phrase in code block"    "Пример:${NL}\`\`\`${NL}Отдельная задача, если нужна.${NL}\`\`\`${NL}Готово."
expect pass  "phrase in inline code"   "Ищем \`out of scope\` в логах. Готово."
expect pass  "phrase in «quotes»"      "Правило запрещает фразы вроде «отдельная задача, если нужна». Готово."
expect pass  "phrase in blockquote"    "Было так:${NL}> Ещё нашёл ошибку. Отдельная задача.${NL}Теперь правило это ловит."
expect pass  "deferral inside proposals" "Готово.${NL}${NL}## Предлагаю${NL}1. Сделать слой 6 отдельной задачей."
expect pass  "Out of scope as a name"  "В тикете обновил раздел Out of scope: осталось одно закрепление."
expect pass  "отдельные вопросы (count)" "Обе строки записаны как отдельные вопросы. Готово."
expect pass  "отдельных вопросах"      "На отдельных вопросах разброс от −56% до +21%."
expect block "отдельной задачей"       "Сделал X. Баг в парсере — отдельной задачей."
expect pass  "нашёл и исправил"        "По итогам поправил формулировку и попутно нашёл и исправил ложное срабатывание хука C."
expect pass  "en: found and fixed"     "Done. I also found and fixed a stale cache key."
expect block "нашёл, но не исправил"   "Сделал X. Попутно нашёл ошибку в парсере, её стоит посмотреть."
expect pass  "second stop passes"     "Ещё нашёл ошибку. Отдельная задача." true
expect pass  "empty reply"             ""

# A section already printed: the continuation numbers on from it, not from 1.
reason_has() { # what, needle, reply
    if run "$3" | jq -r '.reason // ""' | grep -qF -- "$2"; then
        pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || printf '  ok    reason %s\n' "$1"
    else
        fail=$((fail + 1)); printf '  FAIL  reason %s  (no "%s")\n' "$1" "$2"
    fi
}
reason_has "numbers on after 3 items" "numbered from 4" \
    "Ещё нашёл баг в y.${NL}${NL}## Найдено попутно${NL}1. [связано] a — b. Исправить?${NL}2. [связано] c — d. Исправить?${NL}3. [связано] e — f. Исправить?"
# Claude Code shows the reason to the user: it stays at three lines.
n="$(run "Ещё нашёл баг в y." | jq -r '.reason' | wc -l)"
if [ "$n" -le 3 ]; then pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    reason fits in 3 lines"
else fail=$((fail + 1)); echo "  FAIL  reason is $n lines"; fi
out="$(run "Ещё нашёл баг в y." | jq -r '.reason')"
if ! printf '%s' "$out" | grep -qF "numbered from"; then pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    reason no section, no numbering hint"
else fail=$((fail + 1)); echo "  FAIL  reason no section: numbering hint present"; fi

# The notice: which F number each item got, when the reply did not say.
notice() { run "$1" | jq -r '.systemMessage // ""'; }
msg="$(notice "Готово.${NL}${NL}## Найдено попутно${NL}1. [связано] \`/tmp/n1.txt:3\` — без номера — x. Исправить?")"
if printf '%s' "$msg" | grep -qE '^  1\. F[0-9]+  /tmp/n1\.txt:3$'; then pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    notice maps chat number to id and path"
else fail=$((fail + 1)); echo "  FAIL  notice: $msg"; fi
msg="$(notice "Готово.${NL}${NL}## Найдено попутно${NL}1. [связано] \`/tmp/n1.txt:3\` — без номера — x. Исправить?")"
if printf '%s' "$msg" | grep -q '(already recorded: open)'; then pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    notice marks an item already in the ledger"
else fail=$((fail + 1)); echo "  FAIL  duplicate notice: $msg"; fi
id="$(FINDINGS_DIR="$FINDINGS_DIR" "$HERE/../bin/findings" reserve --session t)"
msg="$(notice "Готово.${NL}${NL}## Найдено попутно${NL}1. $id: [связано] \`/tmp/n2.txt:4\` — с номером — x. Исправить?")"
if [ -z "$msg" ]; then pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    no notice when every item carries its id"
else fail=$((fail + 1)); echo "  FAIL  notice despite ids: $msg"; fi

# Disabled by env, and fails open on garbage input.
out="$(FOUND_DEFECTS_GUARD=off run "Ещё нашёл ошибку. Отдельная задача.")"
if [ -z "$out" ]; then pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    pass   FOUND_DEFECTS_GUARD=off"
else fail=$((fail + 1)); echo "  FAIL  FOUND_DEFECTS_GUARD=off"; fi
out="$(printf 'not json' | "$GUARD")"; rc=$?
if [ -z "$out" ] && [ "$rc" -eq 0 ]; then pass=$((pass + 1)); [ "$QUIET" -eq 1 ] || echo "  ok    pass   unparsable input fails open"
else fail=$((fail + 1)); echo "  FAIL  unparsable input (rc=$rc, out=$out)"; fi

echo "found-defects-guard: passed $pass, failed $fail"
[ "$fail" -eq 0 ]
