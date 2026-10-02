---
description: Digest of defects found along the way (ledger of rules/found-defects-last.md), and decisions on them. Usage — /findings (this session) | /findings project | /findings all | /findings park|skip|done|open <ids> | /findings fix <ids>. Ids are ledger ids (F12, 12, 4-9, 3,5).
---
Dispatch on `$ARGUMENTS`:

- empty → run `findings list` — this session's findings plus a line counting
  what else is open in the project. Where the shell carries no session id
  (Codex, Opencode), add `--session <id>` from the "This session (<id>)" line
  the findings hook put in your context
- `project` → run `findings list --scope project`
- `all` → run `findings list --scope all`
- `park <ids>`, `skip <ids>`, `done <ids>`, `open <ids>` → run `findings $ARGUMENTS`, then `findings list`
- `fix <ids>` → run `findings list --status open,park`, take those ids as the task, and start fixing them. Mark each one with `findings done <id>` only after its fix is verified

Then reply with the list itself. The tool output is collapsed in the user's terminal and they do not see it, so a reply that only says "8 open" shows them nothing:

1. the `findings list` output, verbatim, in a fenced code block
2. for each open item, one short line: your recommendation — fix, park or skip — and why
3. one ready-to-send answer line, e.g. `fix 6,7,9 · park 8,10-12 · skip 13`
4. one line with every decision the user can send instead, each with what it does, in the language of the session — the user should not have to remember the verbs:
   `fix <ids>` fix now, marked done once verified · `park <ids>` defer, stays in the ledger, out of the chat · `skip <ids>` decline, never shown again · `done <ids>` already fixed · `open <ids>` back to open

On an error, state it in one line instead.
