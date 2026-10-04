---
description: Digest of defects found along the way (ledger of rules/found-defects-last.md), and decisions on them. Usage — /findings (this session) | /findings project | /findings all | /findings park|skip|done|open|fix <ids> — several in one line too (skip F80 fix F85). Ids are ledger ids (F12, 12, 4-9, 3,5).
---
Dispatch on `$ARGUMENTS`:

- empty → run `findings list` — this session's findings plus a line counting
  what else is open in the project. Where the shell carries no session id
  (Codex, Opencode), add `--session <id>` from the "This session (<id>)" line
  the findings hook put in your context
- `project` → run `findings list --scope project`
- `all` → run `findings list --scope all`
- starts with `park`, `skip`, `done`, `open` or `fix` — one decision or several in one line (`skip F80 fix F85`, `park 4-9 · fix 12`) → run `findings $ARGUMENTS` once. It sets every status in the line, or changes nothing and says why. Then:
  - its output has a `fix: F…` line → those ids are the task: start fixing them, and mark each one with `findings done <id>` only after its fix is verified
  - otherwise → run `findings list`

The `findings` CLI is the only source. The status of a finding is what `findings list` says, nothing else: do not consult, cite or reconcile memory notes, transcripts, Qdrant, memsearch or any other store, and do not mention them in the reply.

Then reply with the list itself. The tool output is collapsed in the user's terminal and they do not see it, so a reply that only says "8 open" shows them nothing:

1. the `findings list` output, verbatim, in a fenced code block
2. for each open item, one short line: your recommendation — fix, park or skip — and why
3. one ready-to-send answer line, e.g. `fix 6,7,9 · park 8,10-12 · skip 13`
4. the mini-help, one line, translated into the language of the session — the same line the rule puts under the digest, so the user should not have to remember the verbs:
   `fix — fix now · park — defer · skip — decline · done — already fixed · open — reopen`

On an error, state it in one line instead.
