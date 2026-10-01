# Changelog

## 0.1.0 — 2026-10-01

First release as a repository of its own. Until now the same files lived in a
personal config canon.

### Added

- **The rule** (`rules/found-defects-last.md`): a defect noticed along the way
  goes into a final "Found along the way" section, one line each, tagged
  `[related]`/`[unrelated]`, `[urgent]` for a leaked secret, data loss or a
  production outage, ending with an offer to fix. Shown once; only `[urgent]`
  repeats; the digest goes out when the task closes.
- **The ledger** (`bin/findings`): one append-only JSONL log, global ids,
  statuses open/park/skip/done, `flock` on write. A finding is filed under the
  git repository its path points at. A duplicate of an open, parked or skipped
  finding is not added again; a duplicate of a done one is (a regression).
- **The guard** (`bin/found-defects-guard`, Stop hook in Claude Code and Codex):
  records the reply's section, and continues the turn once when a deferring
  phrase sits in the body or the section is not last. 2.2% of 1157 real replies.
- **The prompt hook** (`bin/findings-hook`, UserPromptSubmit): open, urgent and
  parked counts plus each urgent finding; silent for a project with none.
- **The Opencode plugin** (`plugins/opencode/findings.ts`): records on
  `session.idle`, adds the counts to the system prompt (cached 30 s).
- **`/findings`** for Claude Code and Opencode: the digest in the reply itself,
  a recommendation per item and a ready answer line — the tool output is
  collapsed in the terminal, so a reply without the list shows nothing.
- `install.sh`, `uninstall.sh`, `lib/wire.py`, `release.sh`; 70 test cases.
