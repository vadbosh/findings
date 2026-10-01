# findings на Windows — установка вручную

[English version](README.WIN.md) · [Основной README](README.RU.md)

> **На настоящей Windows не проверялось.** Шаги прогнаны в PowerShell 7 на
> Linux, а код, который на Windows ведёт себя иначе (блокировка файла, пути
> `C:\`, формат хуков), покрыт тестами, имитирующими Windows. Если какой-то шаг
> не сработал, заведите issue с командой и её выводом.

`install.sh` — для Linux и macOS. На Windows тот же результат дают шесть шагов в
PowerShell, если установлен Python. Пути записаны через `/`: PowerShell и Python
на Windows его понимают, и экранировать ничего не нужно.

**Что работает на Windows:** правило, `/findings`, CLI `findings`, а в Claude Code
— оба хука (запись секции, поиск спрятанной находки, строка про сессию). Хуки
Codex подключаются так же, но на Windows не проверялись.
**Что не работает:** плагин Opencode — он вызывает скрипты через POSIX-шелл. В
Opencode будут правило и `/findings`, но ответы не будут записываться в журнал
автоматически.

## 0. Проверить, что всё нужное есть

```powershell
python --version     # 3.8 or newer
git --version        # used to file findings by repository
```

Если `python` открывает Microsoft Store или не находится, установите Python с
python.org с отмеченным «Add python.exe to PATH» — или пишите `py` вместо
`python` во всех шагах ниже.

## 1. Скачать репозиторий

```powershell
git clone https://github.com/vadbosh/findings "$HOME/findings"
cd "$HOME/findings"
```

## 2. Поставить CLI и скрипты хуков

```powershell
$bin = "$HOME/.local/bin"
New-Item -ItemType Directory -Force $bin | Out-Null
Copy-Item bin/findings, bin/findings-hook, bin/found-defects-guard, bin/findings.cmd $bin -Force

$path = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($path -notlike "*$bin*") { [Environment]::SetEnvironmentVariable('Path', "$path;$bin", 'User') }
```

`findings.cmd` нужен, чтобы вы и ассистент могли набирать просто `findings`:
файл без расширения Windows не запускает. Откройте **новый** терминал (PATH
читается при старте) и проверьте:

```powershell
findings list --scope all       # findings: no session id … / findings: nothing open
```

## 3. Скопировать правило и команду

Для каждого ассистента, которым пользуетесь:

```powershell
# Claude Code
New-Item -ItemType Directory -Force "$HOME/.claude/rules", "$HOME/.claude/commands" | Out-Null
Copy-Item rules/found-defects-last.md "$HOME/.claude/rules/" -Force
Copy-Item commands/findings.md "$HOME/.claude/commands/" -Force

# Codex
New-Item -ItemType Directory -Force "$HOME/.codex/memories" | Out-Null
Copy-Item rules/found-defects-last.md "$HOME/.codex/memories/" -Force

# Opencode
New-Item -ItemType Directory -Force "$HOME/.config/opencode/instructions", "$HOME/.config/opencode/commands" | Out-Null
Copy-Item rules/found-defects-last.md "$HOME/.config/opencode/instructions/" -Force
Copy-Item commands/findings.md "$HOME/.config/opencode/commands/" -Force
```

## 4. Подключить хуки

`lib/wire.py` правит файлы настроек и сохраняет всё, что в них уже есть;
повторный запуск ничего не меняет. `--python` запускает каждый хук через
интерпретатор (пишите `py`, если в шаге 0 сработал он):

```powershell
python lib/wire.py claude   --bin "$HOME/.local/bin" --python python
python lib/wire.py codex    --bin "$HOME/.local/bin" --python python
python lib/wire.py opencode
```

Каждая строка печатает, что добавила, или `= already current`. Файл, который
меняется, сначала копируется в `$HOME/.local/state/findings/backups/`. Запускайте
только строки для своих ассистентов; для отсутствующего будет `config not found`
— это не ошибка.

## 5. Проверить, что ответ записывается

```powershell
$env:FINDINGS_DIR = "$env:TEMP/findings-check"
'{"cwd":"C:\\","stop_hook_active":true,"last_assistant_message":"## Found along the way\n\n1. [related] `C:\\x.txt` — check — install. Fix?"}' |
    python "$HOME/.local/bin/found-defects-guard"
findings list --scope all       # shows F1 … check — install.
Remove-Item -Recurse $env:FINDINGS_DIR; Remove-Item Env:FINDINGS_DIR
```

## 6. Перезапустить ассистента

Хуки, правила и команды читаются при старте. Дальше — `/findings`.

## Обновление

```powershell
cd "$HOME/findings"; git pull
```

Затем повторите шаги 2–4. Копии перезапишутся, а `wire.py` не добавит то, что
уже есть.

## Удаление

```powershell
cd "$HOME/findings"
python lib/wire.py claude --remove; python lib/wire.py codex --remove; python lib/wire.py opencode --remove
Remove-Item "$HOME/.local/bin/findings*", "$HOME/.local/bin/found-defects-guard" -ErrorAction SilentlyContinue
Remove-Item "$HOME/.claude/rules/found-defects-last.md", "$HOME/.claude/commands/findings.md", `
            "$HOME/.codex/memories/found-defects-last.md", `
            "$HOME/.config/opencode/instructions/found-defects-last.md", `
            "$HOME/.config/opencode/commands/findings.md" -ErrorAction SilentlyContinue
```

Журнал остаётся: `$HOME/.local/state/findings/ledger.jsonl`.
