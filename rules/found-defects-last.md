# Defects found along the way: always reported, always last

**MANDATORY — no discretion.** While working on the task, anything wrong you
notice outside the change itself — a bug, a false report, a broken path, a
stale doc or comment, dead code, a security gap, a config that does not do
what it claims — gets reported. Related to the task or not. Big or small.

Three things are forbidden:

- **leaving it out**, because it is off-topic, minor, or "not asked"
- **fixing it silently** — that is scope creep (`scope-discipline.md`)
- **burying it in the body** — one sentence mid-reply is a finding the reader
  misses

## Format: the last section of the reply

After the body, and after `## Proposals` if there is one. Nothing comes after
it.

**Write the section in the language of the session**, like the rest of the
reply. This file is in English; the output is not. The heading, the tags, the
offer to fix and every item are translated — a Russian session gets a Russian
section. The example below shows the shape, not the words.

```markdown
## Found along the way

1. [related] `path:line` — <what is wrong> — <evidence>. Fix?
2. [unrelated] `/abs/path/in/other/repo` — <what is wrong> — unverified, suspicion. Fix?
3. [urgent][unrelated] <prod alert or leaked secret> — <evidence>. Fix?
```

- **one line per defect**: where, what is wrong, the evidence — the command
  or the line that shows it. A suspicion you did not check says "unverified"
- **tag** each item `[related]` or `[unrelated]`, so the reader sees at once
  whether it touches the current work
- **add `[urgent]`** only for a security gap, a leaked secret, data loss or a
  production outage — the things that cannot wait for the digest
- **where comes first, in backticks, as an absolute path** when the defect is
  in a file: that path decides which project the ledger files it under
- **every item ends with an offer to fix**: "Fix?"
- **no ceiling** on the count, and no merging into the proposals list — the
  three-item limit of `proposals-at-the-end.md` does not apply here
- **nothing found → no section.** Never invent an item to fill it

## Shown once; the ledger keeps it

A finding appears in the chat **once**, in the reply where it was found. The
Stop hook records that section in the ledger — one file on this machine,
`~/.local/state/findings/ledger.jsonl` — labelled with the repository the
finding's path points at. From then on:

- **do not repeat open findings** in later replies. A reply carries only the
  findings new to it
- **`[urgent]` is the exception**: repeat it in every reply until the reader
  decides. The UserPromptSubmit hook lists the open urgent ones for you
- **the digest is shown at closure points**: when the task is closed (commit,
  push, "done"), before notes or a handoff are written, and when the reader asks.
  Run `findings list` — this session's findings, whatever project they went
  to — and put its output in the section, instead of new items that are
  already in it. Where the shell has no session id (Codex, Opencode), pass
  `--session <id>` from the hook's "This session (<id>)" line
- **the reader decides in one line**: "fix 3", "park 4-9", "skip 2", in chat
  numbers or ledger ids (`F12`). Map chat numbers to ledger ids with
  `findings list`, then run `findings set <park|skip|done|open> <ids>`.
  "Fix" makes it work; mark it `done` once the fix is verified. `park` keeps a
  finding out of the chat and in the ledger

`/findings` shows this session's digest, `/findings project` the whole project,
`/findings all` everything; `/findings park 4-9` and the like change it.

## Enforcement

`bin/found-defects-guard`, a Stop hook in Claude Code and Codex, reads the
finished reply and records its section in the ledger. A deferring phrase in the
body — "separate task", "also noticed", "отдельная задача", "попутно нашёл" —
outside code, quotes and the proposals section, or this section not being last,
continues the turn once with an instruction to append the section.
`bin/findings-hook` (UserPromptSubmit) tells the model how many findings are
open in the project, which are urgent, and the id of its own session; it is
silent when neither the project nor the session has an open finding.
In Opencode a plugin records the section and adds the counts, but it cannot
block the end of a turn: a finding buried in the body is not caught there.

## Why

Measured 2026-10-01: during a plugin upgrade, a false-positive check in a
configuration tool — it reported a dead Opencode plugin as installed —
came out as one sentence in the middle of a reply, phrased "a separate task, if
needed". The reader caught it only on a second read and said they often miss
such lines. The finding had cost a full investigation to produce; placed where
it was, it nearly cost nothing to lose.

The first version of this rule repeated every undecided finding in every
reply. On a long session that became nine lines of unrelated production
findings under every answer; the reader asked for a digest instead. Hence the
ledger: shown once, kept until decided, summarised when the task closes.
