#!/usr/bin/env python3
"""Wire findings into one assistant's configuration, or unwire it.

  wire.py <claude|codex|opencode> --bin DIR [--no-rule] [--remove] [--dry-run]

What each assistant gets — files are copied by install.sh, this writes only
the configuration that makes them load:

  claude    ~/.claude/settings.json   hooks.Stop             found-defects-guard
                                      hooks.UserPromptSubmit findings-hook
  codex     ~/.codex/hooks.json       the same two hooks
            ~/.codex/AGENTS.md        an @-line naming the rule file — Codex
                                      reads a memory only when this file names it
  opencode  ~/.config/opencode/opencode.json
                                      the rule file listed in "instructions";
                                      the plugin needs no entry, Opencode loads
                                      every top-level file in plugins/

An entry counts as ours when its command's program is one of our two hooks,
whatever directory it is in: an entry made by hand is kept and never doubled,
and --remove takes out only ours. Every other key, entry and line is left as it
was. A configuration file is backed up before it is written, outside every
directory an assistant reads (~/.local/state/findings/backups/).

Exit codes: 0 done or already current, 3 no configuration file (the assistant
is not set up — not an error), 1 the file could not be read or written.
"""
import argparse
import json
import os
import shutil
import sys
import time

HOME = os.path.expanduser("~")
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local", "state"), "findings")
BACKUPS = os.path.join(STATE, "backups")

CONFIG = {
    "claude": os.path.join(HOME, ".claude", "settings.json"),
    "codex": os.path.join(HOME, ".codex", "hooks.json"),
    "opencode": os.path.join(HOME, ".config", "opencode", "opencode.json"),
}
HOOKS = {  # event -> program
    "Stop": "found-defects-guard",
    "UserPromptSubmit": "findings-hook",
}
STATUS = {"found-defects-guard": "found-defects-guard...", "findings-hook": "findings..."}
RULE = "found-defects-last.md"
OPENCODE_ENTRY = f"~/.config/opencode/instructions/{RULE}"
CODEX_AGENTS = os.path.join(HOME, ".codex", "AGENTS.md")
CODEX_RULE = os.path.join(HOME, ".codex", "memories", RULE)


def program(cmd):
    parts = (cmd or "").split()
    return os.path.basename(parts[0]) if parts else ""


def wire_hooks(ide, data, bindir, remove):
    changed = []
    hooks = data.setdefault("hooks", {})
    for event, name in HOOKS.items():
        entries = hooks.get(event, [])
        ours = [e for e in entries
                if any(program(h.get("command")) == name for h in e.get("hooks", []))]
        if remove:
            if not ours:
                continue
            kept = []
            for e in entries:
                rest = [h for h in e.get("hooks", []) if program(h.get("command")) != name]
                if rest:
                    kept.append(dict(e, hooks=rest))
                elif e not in ours:
                    kept.append(e)
            if kept:
                hooks[event] = kept
            else:
                hooks.pop(event, None)
            changed.append(f"{event} hook removed ({name})")
            continue
        if ours:
            continue
        hook = {"type": "command", "command": os.path.join(bindir, name), "timeout": 10}
        if ide == "codex":
            hook["statusMessage"] = STATUS[name]
        hooks.setdefault(event, []).append({"matcher": "", "hooks": [hook]})
        changed.append(f"{event} hook added ({name})")
    if not hooks:
        data.pop("hooks", None)
    return changed


def wire_opencode(data, with_rule, remove):
    arr = data.get("instructions", [])
    if not remove and not with_rule:
        return []           # --no-rule skips the rule; it does not take one away
    if remove:
        if OPENCODE_ENTRY in arr:
            arr.remove(OPENCODE_ENTRY)
            if not arr:
                data.pop("instructions", None)
            return ["rule unlisted from instructions"]
        return []
    if OPENCODE_ENTRY in arr:
        return []
    data.setdefault("instructions", []).append(OPENCODE_ENTRY)
    return ["rule listed in instructions"]


def wire_codex_agents(with_rule, remove, dry_run):
    """Matched by file name: an @-line naming the rule elsewhere counts."""
    try:
        body = open(CODEX_AGENTS, encoding="utf-8").read()
    except FileNotFoundError:
        body = ""
    lines = body.splitlines()
    ours = [ln for ln in lines if ln.startswith("@") and ln.rstrip().rsplit("/", 1)[-1] == RULE]
    if not remove and not with_rule:
        return []
    if remove:
        if not ours:
            return []
        if not dry_run:
            backup(CODEX_AGENTS)
            keep = [ln for ln in lines if ln not in ours]
            atomic_write(CODEX_AGENTS, "\n".join(keep) + ("\n" if keep else ""))
        return ["rule reference removed from AGENTS.md"]
    if ours:
        return []
    if not dry_run:
        os.makedirs(os.path.dirname(CODEX_AGENTS), exist_ok=True)
        if body:
            backup(CODEX_AGENTS)
        sep = "\n" if body and not body.endswith("\n") else ""
        atomic_write(CODEX_AGENTS, body + sep + f"@{CODEX_RULE}\n")
    return ["rule referenced from AGENTS.md"]


def backup(path):
    if not os.path.isfile(path):
        return
    os.makedirs(BACKUPS, mode=0o700, exist_ok=True)
    tag = path.replace(HOME, "").strip("/").replace("/.", "/").lstrip(".").replace("/", "-")
    shutil.copy2(path, os.path.join(BACKUPS, f"{tag}.bak.{int(time.time())}"))


def atomic_write(path, text):
    tmp = f"{path}.findings-tmp.{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(text)
    if os.path.exists(path):
        shutil.copymode(path, tmp)
    os.replace(tmp, path)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("ide", choices=sorted(CONFIG))
    ap.add_argument("--bin", default=os.path.join(HOME, ".local", "bin"))
    ap.add_argument("--no-rule", action="store_true")
    ap.add_argument("--remove", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args(argv)
    with_rule = not a.no_rule

    path = CONFIG[a.ide]
    if not os.path.exists(path):
        print(f"    config not found: {path}", file=sys.stderr)
        return 3
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except ValueError as exc:
        print(f"    {path} is not plain JSON ({exc}) — left untouched; "
              f"run `{sys.argv[0]} {a.ide} --dry-run` to see what to add by hand", file=sys.stderr)
        return 1
    if not isinstance(data, dict):
        print(f"    {path} is not a JSON object — left untouched", file=sys.stderr)
        return 1

    if a.ide == "opencode":
        changed = wire_opencode(data, with_rule, a.remove)
    else:
        changed = wire_hooks(a.ide, data, a.bin, a.remove)
    other = wire_codex_agents(with_rule, a.remove, a.dry_run) if a.ide == "codex" else []

    if changed and not a.dry_run:
        backup(path)
        atomic_write(path, json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    prefix = "    would " if a.dry_run else "    "
    for line in changed + other:
        print(prefix + line)
    if not changed and not other:
        print("    = already current")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
