---
title: ловушки и проверки перед выпуском
kind: recipe
updated: 2026-11-06
---

# ловушки и проверки перед выпуском

## Что ломается без ошибки

- **Вариадический `--mcp-config` у claude.** Обёртка вида
  `claude() { command claude --mcp-config F "$@"; }` съедает промпт как второй
  файл (`Invalid MCP configuration … ENAMETOOLONG`). Поэтому строки `fresh`
  ставят `--` перед промптом. Воспроизводится только под псевдотерминалом
  (`script -qc …`), в pipe — нет.
- **Python 3.8.** README обещает 3.8+. Вложенные одинаковые кавычки в f-строке
  (`f"{', '.join(f'F{x}' …)}"` с одинаковыми) — только 3.12+; здесь стоит
  3.14, и ошибку не увидеть. Поиск перед коммитом — команда ниже.
- **bash 3.2 (macOS).** В `bin/findings-completion.bash` нет `mapfile`, только
  цикл `read`; `compopt` вызывается с `2>/dev/null`.
- **Тест установки и настоящий HOME.** `inst()`/`uninst()` в
  `tests/test_install.sh` обнуляют `XDG_STATE_HOME`, `XDG_DATA_HOME`,
  `BASH_COMPLETION_USER_DIR`; без этого файл автодополнения ушёл бы в
  настоящий каталог.
- **Присваивания перед командой — слева направо.**
  `A='' B="$A/x" cmd` получает пустой `$A` в `B` (тест `OPENCODE_DB` однажды
  падал из-за этого).
- **Дедупликация в тестах.** Две находки с одним `where` и похожим текстом
  склеиваются; в тестовых данных давать разные пути и слова.
- **Escape-коды в проверках «в терминале».** Под `script` вывод цветной;
  сравнивать подстроку — с `NO_COLOR=1`, цвета проверять отдельно через
  `FINDINGS_COLOR=always`.

## Проверки (только чтение)

```bash
cd /home/repos/findings
for t in tests/*.sh; do bash "$t" -q | tail -1; done      # failed 0
shellcheck bin/findings-completion.bash                    # пусто
rg -n 'f"[^"]*\{[^}"]*"[^}]*\}' bin/findings bin/found-defects-guard   # пусто: нет f-строк только для 3.12+
findings sessions | head -1                                # первая строка говорит, что показано
findings list | cat                                        # в pipe: без цвета и без второй строки
./release.sh check                                         # everything agrees on …
```

Сравнение предупреждений shellcheck с прошлым коммитом, а не с нулём:
`shellcheck -f gcc FILE | wc -l` против `git show HEAD:FILE | shellcheck -f gcc - | wc -l`.
