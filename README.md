# findings

**Your AI assistant notices things while it works on something else. findings
makes it say so — once, at the end of the reply — and keeps every one of them
until you decide.**

A bug in a file it only read. A config that does not do what it claims. A
production alert that has been firing for a week. An assistant mentions these in
passing — "a separate task, if needed" — in the middle of a long reply, and the
finding is gone by the next screen. On a long task, half of what it found is
never seen.

findings fixes that in three moves: a rule that tells the assistant where to put
a finding, a hook that holds it to that rule, and a ledger that keeps every
finding until you say fix, park or skip.

Claude Code · Codex · Opencode. Tested on Linux; macOS should work and is untested.
Windows: [manual install](README.WIN.md).

[Русская версия](README.RU.md) · [Changelog](CHANGELOG.md)

---

## What it looks like

A reply ends with the section — only the defects new in this reply:

```markdown
Done: the migration runs, tests pass.

## Found along the way

1. [related] `/srv/app/db/migrate.py:88` — the rollback skips the index it created — read the down() method. Fix?
2. [unrelated] `/srv/infra/alerts/coredns.yaml` — 8 rules never deployed: the directory is missing from alert_rule_dirs. Fix?
3. [urgent][unrelated] prod: `KubernetesHPAScalingAbility` firing for 7 days — unverified. Fix?
```

The next reply does not repeat them. They are in the ledger:

```
$ findings list --all
findings: /srv/app
  F12 [related] `/srv/app/db/migrate.py:88` — the rollback skips the index it created …  — 2026-10-01

findings: /srv/infra
  F14 [urgent][unrelated] prod: `KubernetesHPAScalingAbility` firing for 7 days — unverified.  — 2026-10-01
  F13 [unrelated] `/srv/infra/alerts/coredns.yaml` — 8 rules never deployed …  — 2026-10-01
```

You answer in one line, in chat or with the command:

```
fix 12 · park 13 · skip 14
/findings park 13-14
```

## When findings are shown

| Moment | What the reply shows |
|---|---|
| a defect is found | the section, with that defect — once |
| the next replies | nothing about it |
| `[urgent]` — a leaked secret, data loss, a production outage | repeated in every reply until you decide |
| the task is closed (commit, push, "done"), before notes or a handoff | the digest: everything open and parked for the project |
| you ask — `/findings`, "show findings" | the digest, a recommendation per item, a ready answer line |

### This session, or the whole project

`/findings` shows what **this session** found — the summary of the task in
hand, whatever project each finding was filed under — and one line for the
rest:

```
findings: /srv/app
  F12 [related] `/srv/app/db/migrate.py:88` — the rollback skips the index it created …

+3 open in /srv/app from other sessions — /findings project
```

A directory where unrelated tasks run side by side stays readable, and nothing
undecided disappears: the last line counts it. `/findings project` lists the
whole project, `/findings all` every project.

The session id comes from `$CLAUDE_CODE_SESSION_ID` in Claude Code. Codex and
Opencode put none in the shell, so the prompt hook hands it to the model, which
passes `--session <id>`. A shell with no id at all gets the whole project and
a line saying so.

`park` keeps a finding out of the chat and in the ledger. `skip` declines it.
`fix` turns it into work; it is marked `done` once the fix is verified. A finding
that comes back after `done` is recorded again — that is a regression.

## Where a finding is kept

In one file on your machine: `~/.local/state/findings/ledger.jsonl`. Nothing is
written into any repository. Every finding in that file carries a `project`
label, and the label is what `/findings` filters on:

```json
{"op": "add", "id": 13, "project": "/srv/infra", "cwd": "/srv/app", "where": "/srv/infra/alerts/coredns.yaml", "tags": ["unrelated"], "text": "…"}
```

The label is the git repository the finding's path points at. A defect in
`/srv/infra/…` found while working in `/srv/app` is labelled `/srv/infra`: the
next time you work in `/srv/infra`, the last line of `/findings` counts it and
`/findings project` lists it. A finding with no path, or with a path outside any git repository,
gets the repository of the session's directory; a session directory outside
git is its own label. `/findings all` shows the whole file, grouped by label.

## Install

```bash
git clone https://github.com/vadbosh/findings
cd findings
./install.sh --dry-run    # what it would write
./install.sh
```

Then restart the assistant: hooks, rules and plugins are read at start-up.

It installs into every assistant it finds (`~/.claude`, `~/.codex`,
`~/.config/opencode`). `--ide claude` limits it to one, `--no-rule` skips the
rule file. Re-running changes nothing; a file it would overwrite with different
content is backed up to `~/.local/state/findings/backups/` first.

Needs python 3.8+ and, for filing by repository, git. No packages.

## Usage

```bash
/findings                 # this session (Claude Code, Opencode)
/findings project         # the whole project
/findings all             # every project
/findings park 4-9        # also: skip, done, open — ids like 3, F3, 4-9, 3,5
/findings fix 3,5         # take them on as the task

findings list [--scope session|project|all] [--session ID] [--status open,park,skip,done|any] [-p PATH]
findings count [-p PATH]  # one line, for hooks and prompts
findings set park 4-9     # or simply: findings park 4-9

# -p PATH: the project of PATH instead of the current directory
```

Codex has no user slash commands: ask "show findings", or run `findings list`.

## How it is wired

| | Claude Code | Codex | Opencode |
|---|---|---|---|
| the rule — where a finding goes, when the digest is shown | `~/.claude/rules/` | `~/.codex/memories/` + `@` line in `AGENTS.md` | `instructions/` + `opencode.json` |
| record the reply's section in the ledger | Stop hook | Stop hook | plugin, on `session.idle` |
| catch a finding buried in the body | Stop hook | Stop hook | — |
| tell the model what is open and urgent | UserPromptSubmit hook | UserPromptSubmit hook | plugin, system prompt |
| `/findings` | ✓ | — | ✓ |

**Catching a buried finding.** `found-defects-guard` reads the finished reply.
A phrase that defers a defect — "separate task", "also noticed", "out of scope",
"отдельная задача", "попутно нашёл" — in the body, outside code, quotes and the
proposals section, continues the turn once and asks for the section alone, not
the whole reply again. Replayed over every Claude Code reply on the author's
machine on 2026-10-03, it would have fired on 53 of 3236 (1.6%); read one by
one, about seven in ten were a real deferred finding, the rest a debugging
step ("found why the commands failed") or a proposal ("keep layer 3 as a
separate task"). Most of those replies predate the rule; once it was in place,
the three blocks in the live log were all false positives, fixed in 0.4.1 and
0.4.4. A false positive costs a three-line
notice — Claude Code shows the hook's reason under "Stop hook error" — and one
line from the model: `(found-defects-guard: false positive)`. A defect reported
as found and fixed ("нашёл и исправил", "found and fixed") defers nothing and
does not fire it. Opencode cannot block the end of a turn, so there the rule is
the only guard.

**Telling the model.** `findings-hook` adds one line before each prompt — open,
urgent and parked counts for the project, each urgent finding, and the id of
the session. It is silent when nothing is open in the project or the session —
parked findings do not count — so a project without open findings pays
nothing.

## Files

```
bin/findings              the ledger CLI
bin/findings-hook         UserPromptSubmit hook
bin/found-defects-guard   Stop hook
plugins/opencode/findings.ts
rules/found-defects-last.md
commands/findings.md
lib/wire.py               edits settings.json, hooks.json, opencode.json, AGENTS.md
```

The ledger is one JSONL file, `~/.local/state/findings/ledger.jsonl`
(`$FINDINGS_DIR` or `$XDG_STATE_HOME` move it). New findings and decisions are
appended; ids are global — F7 means one finding whatever the project, and an id
is never handed out twice. Concurrent sessions take turns on a lock file
(`flock`; `msvcrt` on Windows).

**The id is in the chat from the start.** Before writing the section the model
runs `findings reserve N` and opens each item with an id it got:
`1. F60: [related] …`. The hook records the item under that id, so the reader
can answer `/findings fix F60` without looking anything up. An id reserved by
another session, or never reserved, is not taken: the item gets the next free
one instead.

**It does not grow without bound.** Once it passes 1 MiB it compacts itself:
one record per finding at its current status, and `done` findings older than
30 days move to `archive.jsonl` next to it. `skip` stays, because that is what
keeps a declined finding from coming back. Measured on 10 000 findings: 6.1 MiB
became 2.1 MiB, and the prompt hook went from 433 ms to 188 ms.

```bash
findings compact            # now, instead of waiting for 1 MiB
findings list --archive     # what went to the archive (--all: every project)
```

The previous ledger is kept as `ledger.jsonl.prev`. Tuning:
`FINDINGS_COMPACT_BYTES` (default 1048576), `FINDINGS_ARCHIVE_DAYS` (default 30).

Switches, the same in all three assistants: `FOUND_DEFECTS_GUARD=off` turns
off the check for buried findings and still records the section;
`FINDINGS_RECORD=off` stops recording.

## Tests

```bash
bash tests/test_findings.sh            # the ledger: parsing, routing, dedupe, statuses
bash tests/test_found_defects_guard.sh # the guard's decisions
bash tests/test_install.sh             # install, re-install, uninstall, in a temporary HOME
```

None of them touch the real configuration or the real ledger.

## Uninstall

```bash
./uninstall.sh --dry-run
./uninstall.sh
```

Removes the hooks, the plugin, the rule, the command and the CLI. The ledger
stays: it is your data.

## License

MIT
