---
title: где в коде что лежит и откуда sessions берёт данные
kind: reference
updated: 2026-11-06
---

# где в коде что лежит и откуда sessions берёт данные

## Где это живёт

Один CLI на stdlib — `bin/findings` (Python 3.8+), два хука рядом
(`bin/found-defects-guard` — Stop, `bin/findings-hook` — UserPromptSubmit),
плагин opencode — `plugins/opencode/findings.ts`. Журнал один на машину:
`~/.local/state/findings/ledger.jsonl` (`$FINDINGS_DIR` переносит). Что куда
ставится — шапка `install.sh`; что сверяется — функция `installed()` в
`release.sh`.

Внутри `bin/findings` (искать по имени, номера строк плывут):

| Что | Где |
|---|---|
| чтение журнала, статусы | `read()`, `load()` |
| к какому проекту запись / чтение | `route()`, `project_of()` / `reading_project()` |
| раздел ответа → записи | `parse_section()`, `record_items()` |
| сессии IDE | `session_info()`: `_claude`, `_codex`, `_opencode`; `ide_of()` по форме id |
| строки resume / fresh | `RESUME`, `fresh_cmd()`, `run_in()`, `brief_arg()` |
| цвета | `COLORS`, `paint()`, `color_on()`, `help_paint()` |
| справка | `HELP_HEAD`, `HELP_TOPICS`, `HELP_ALIASES`, `help_text()` |
| парсер | `build_parser()`, `filter_parser()`, `run()` |
| слова для Tab | `complete()`: `findings __complete` с `commands`, `ids`, `sessions`, `projects`, `flags CMD` |

## Откуда `sessions` берёт данные

Журнал хранит только id сессии и cwd. Остальное — из файлов самих IDE, только
чтение:

- Claude Code: `~/.claude/projects/*/<id>.jsonl` (`CLAUDE_CONFIG_DIR`); каталог
  для `--resume` — первый `cwd` транскрипта, заголовок — `custom-title`/`ai-title`
- Codex: `~/.codex/sessions/YYYY/MM/DD/rollout-*-<id>.jsonl` (`CODEX_HOME`),
  заголовок — `thread_name` в `~/.codex/session_index.jsonl`
- opencode: таблица `session` в `opencode.db` (`OPENCODE_DB`,
  `XDG_DATA_HOME/opencode`, `OPENCODE_DATA_DIR`, по умолчанию
  `~/.local/share/opencode`)

Транскрипт удалён → IDE определяется по форме id (`ses_` / UUID v7 / v4),
строки `resume` нет, `fresh` остаётся.

## Два читателя одного вывода

`findings list` читает и человек, и скилл `/findings` (через Bash, то есть
через pipe). Всё, что добавлено для человека — цвет, вторая строка `--long`,
строка `fix` с командой IDE, — включается только когда stdout — терминал
(`sys.stdout.isatty()`), или по явному флагу. Почему так — заметка-решение в этом kb.
