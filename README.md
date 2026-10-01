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

Claude Code · Codex · Opencode. Linux and macOS.

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

`park` keeps a finding out of the chat and in the ledger. `skip` declines it.
`fix` turns it into work; it is marked `done` once the fix is verified. A finding
that comes back after `done` is recorded again — that is a regression.

## Where a finding is filed

Under the git repository its path points at. A defect in `/srv/infra/…` found
while working in `/srv/app` is listed under `/srv/infra`, and shows up there
the next time anyone works in that repository. Without a path, it goes under
the repository of the session's directory.

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
/findings                 # open and parked, this project (Claude Code, Opencode)
/findings all             # every project
/findings park 4-9        # also: skip, done, open — ids like 3, F3, 4-9, 3,5
/findings fix 3,5         # take them on as the task

findings list [--all] [--status open,park,skip,done|any]
findings count            # one line, for hooks and prompts
findings set park 4-9     # or simply: findings park 4-9
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
the whole reply again. Over 1157 real replies it fired on 26 (2.2%), nearly all
of them the very pattern it targets. A false positive costs one short line:
`(found-defects-guard: false positive)`. Opencode cannot block the end of a
turn, so there the rule is the only guard.

**Telling the model.** `findings-hook` adds one line before each prompt — open,
urgent and parked counts for the project, and each urgent finding. It is silent
when the project has none, so a project without findings pays nothing.

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

The ledger is one append-only JSONL file, `~/.local/state/findings/ledger.jsonl`
(`$FINDINGS_DIR` or `$XDG_STATE_HOME` move it). Ids are global — F7 means one
finding whatever the project. Concurrent sessions are serialised with `flock`.

Switches: `FOUND_DEFECTS_GUARD=off` turns the guard off, `FINDINGS_RECORD=off`
stops recording.

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
