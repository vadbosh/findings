---
description: Digest of defects found along the way (ledger of rules/found-defects-last.md), and decisions on them. Usage — /findings (open + parked, this project) | /findings all | /findings park|skip|done|open <ids> | /findings fix <ids>. Ids are ledger ids (F12, 12, 4-9, 3,5).
---
Dispatch on `$ARGUMENTS`:

- empty → run `findings list`
- `all` → run `findings list --all`
- `park <ids>`, `skip <ids>`, `done <ids>`, `open <ids>` → run `findings $ARGUMENTS`, then `findings list`
- `fix <ids>` → run `findings list --status open,park`, take those ids as the task, and start fixing them. Mark each one with `findings done <id>` only after its fix is verified

Then reply with the list itself. The tool output is collapsed in the user's terminal and they do not see it, so a reply that only says "8 open" shows them nothing:

1. the `findings list` output, verbatim, in a fenced code block
2. for each open item, one short line: your recommendation — fix, park or skip — and why
3. one ready-to-send answer line, e.g. `fix 6,7,9 · park 8,10-12 · skip 13`

On an error, state it in one line instead.
