# findings on Windows — manual install

[Русская версия](README.WIN.ru.md) · [Main README](README.md)

> **Untested on real Windows.** The steps were run in PowerShell 7 on Linux,
> and the Windows-specific code (file locking, `C:\` paths, the hook format) is
> covered by tests that simulate it. If a step fails for you, please open an
> issue with the command and its output.

`install.sh` is for Linux and macOS. On Windows the same result takes six steps
in PowerShell, as long as Python is installed. Paths are written with `/`:
PowerShell and Python on Windows accept it, and it needs no escaping.

**What works on Windows:** the rule, `/findings`, the `findings` CLI, and in
Claude Code both hooks (recording the section, catching a buried finding, the
session line). Codex hooks are wired the same way but untested on Windows.
**What does not:** the Opencode plugin — it calls the scripts through a POSIX
shell. In Opencode you get the rule and `/findings`, but replies are not
recorded automatically.

## 0. Check the prerequisites

```powershell
python --version     # 3.8 or newer
git --version        # used to file findings by repository
```

If `python` opens the Microsoft Store or is not found, install Python from
python.org with "Add python.exe to PATH" ticked — or use `py` instead of
`python` in every step below.

## 1. Get the repository

```powershell
git clone https://github.com/vadbosh/findings "$HOME/findings"
cd "$HOME/findings"
```

## 2. Install the CLI and the hook scripts

```powershell
$bin = "$HOME/.local/bin"
New-Item -ItemType Directory -Force $bin | Out-Null
Copy-Item bin/findings, bin/findings-hook, bin/found-defects-guard, bin/findings.cmd $bin -Force

$path = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($path -notlike "*$bin*") { [Environment]::SetEnvironmentVariable('Path', "$path;$bin", 'User') }
```

`findings.cmd` is what lets you and the assistant type `findings` — Windows
does not run a file without an extension. Open a **new** terminal (PATH is read
at start) and check:

```powershell
findings list --scope all       # findings: no session id … / findings: nothing open
```

## 3. Copy the rule and the command

For each assistant you use:

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

## 4. Wire the hooks

`lib/wire.py` edits the configuration files and keeps everything already in
them; a second run changes nothing. `--python` makes each hook run through the
interpreter (use `py` if that is what worked in step 0):

```powershell
python lib/wire.py claude   --bin "$HOME/.local/bin" --python python
python lib/wire.py codex    --bin "$HOME/.local/bin" --python python
python lib/wire.py opencode
```

Each prints what it added, or `= already current`. A file it changes is backed
up first to `$HOME/.local/state/findings/backups/`. Run a line only for an
assistant you have — it says `config not found` otherwise, which is harmless.

## 5. Check that a reply gets recorded

```powershell
$env:FINDINGS_DIR = "$env:TEMP/findings-check"
'{"cwd":"C:\\","stop_hook_active":true,"last_assistant_message":"## Found along the way\n\n1. [related] `C:\\x.txt` - check - install. Fix?"}' |
    python "$HOME/.local/bin/found-defects-guard"
findings list --scope all       # shows F1 ... check - install.
Remove-Item -Recurse $env:FINDINGS_DIR; Remove-Item Env:FINDINGS_DIR
```

## 6. Restart the assistant

Hooks, rules and commands are read at start-up. Then: `/findings`.

## Update

```powershell
cd "$HOME/findings"; git pull
```

Then repeat steps 2–4. Copies are overwritten, and `wire.py` adds nothing that
is already there.

## Uninstall

```powershell
cd "$HOME/findings"
python lib/wire.py claude --remove; python lib/wire.py codex --remove; python lib/wire.py opencode --remove
Remove-Item "$HOME/.local/bin/findings*", "$HOME/.local/bin/found-defects-guard" -ErrorAction SilentlyContinue
Remove-Item "$HOME/.claude/rules/found-defects-last.md", "$HOME/.claude/commands/findings.md", `
            "$HOME/.codex/memories/found-defects-last.md", `
            "$HOME/.config/opencode/instructions/found-defects-last.md", `
            "$HOME/.config/opencode/commands/findings.md" -ErrorAction SilentlyContinue
```

The ledger stays: `$HOME/.local/state/findings/` (`ledger.jsonl`, `archive.jsonl`).
