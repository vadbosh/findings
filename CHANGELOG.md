# Changelog

## 0.4.4 — 2026-10-02

### Fixed

- **"попутно нашёл и исправил" no longer fires the guard.** A defect found and
  already fixed defers nothing; the pattern now skips a find followed by
  "и исправил / починил / поправил / устранил", and "found and fixed" in
  English. All three blocks in the tuning log were false positives, this one
  the third.

### Changed

- **The guard's reason is three lines, not eight.** Claude Code shows it to
  the user as "Stop hook error", so it now holds the quoted phrase and one
  instruction; the section format is left to the rule file the model already
  has. The quoted context around the phrase is 60 characters each side, down
  from 100.

## 0.4.3 — 2026-10-02

### Changed

- **`/findings` answers from the ledger alone.** A reply had cross-checked a
  finding's status against a memsearch note and reported the disagreement.
  The command now says the `findings` CLI is the only source, and that memory
  notes, transcripts and other stores are neither consulted nor mentioned.

## 0.4.2 — 2026-10-02

### Changed

- **`/findings` lists every decision, not only the recommended one.** Under
  the ready-to-send answer it now prints one line with `fix`, `park`, `skip`,
  `done` and `open`, each with what it does, so the verbs need not be
  remembered.

## 0.4.1 — 2026-10-02

### Fixed

- **"отдельные вопросы" no longer reads as a deferral.** The pattern for
  "отдельная задача / отдельный вопрос" matched any form of the adjective, so
  a reply that counted questions ("записаны как отдельные вопросы") was sent
  back for a section it already had. It now matches the singular forms only.
  Both blocks in the tuning log were this case.
- **A continuation numbers on from the section already printed.** When the
  reply already ended with a found-defects section of N items, the guard still
  asked for "the final section", and the model printed a second one numbered
  from 1 — two lists both holding an item 2. The reason now says the section
  exists and asks for the missing items only, numbered from N+1.

## 0.4.0 — 2026-10-01

### Added

- **The ledger compacts itself.** Past `FINDINGS_COMPACT_BYTES` (1 MiB) it is
  rewritten to one record per finding at its current status, and `done`
  findings older than `FINDINGS_ARCHIVE_DAYS` (30) move to `archive.jsonl`.
  `skip` stays, so a declined finding still does not come back. On 10 000
  findings: 6.1 MiB to 2.1 MiB, the prompt hook 433 ms to 188 ms.
  `findings compact` runs it now; `findings list --archive` shows the
  archive; `findings set` on an archived id says where it went. Ids are never
  reused: the highest one handed out is kept in the ledger's first line.

### Changed

- **Writers lock `ledger.lock`, not the ledger.** Compaction replaces the
  ledger; a writer that had waited on the old file would have appended to a
  file no longer there.
- **The prompt hook reads the ledger once,** not twice.

### Fixed

- **Windows: every file is opened as UTF-8.** Without it Python uses the ANSI
  code page there, and the first Cyrillic finding would have failed to record —
  silently, since the guard never blocks on a ledger error.

## 0.3.1 — 2026-10-01

### Fixed

- **The Windows check in step 5 is plain ASCII.** Windows PowerShell 5.1 pipes
  text to a native program in ASCII, so the dashes in the sample reply would
  have reached Python as `?`. The record still worked; the sample no longer
  depends on the console encoding.

## 0.3.0 — 2026-10-01

### Added

- **Windows, by hand.** README.WIN.md and README.WIN.ru.md: six PowerShell
  steps, no shell scripts. Every command in them was run verbatim in
  PowerShell 7 against a temporary HOME; real Windows is untested and the
  files say so. The Opencode plugin is not available there (it needs a POSIX
  shell).
- **`lib/wire.py --python EXE`** runs the hooks through an interpreter:
  Claude Code gets the exec form (`"command": "python", "args": [script]`, no
  shell, no quoting), Codex `python "script"`. Both forms are recognised as
  ours on the next run and on --remove.
- **`bin/findings.cmd`** so `findings` can be typed on Windows.

### Fixed

- **`bin/findings` no longer needs `fcntl`**, which Windows does not have; it
  locks with `msvcrt.locking` there.
- **A Windows path routes a finding** (`C:\x\y.py`, `C:/x/y.py`), not only
  `/…` and `~/…`.
- **wire.py backups on Windows** would have been written to the root of the
  drive: the name was built by replacing `/` in a path made of `\`.

## 0.2.0 — 2026-10-01

### Changed

- **`/findings` shows this session by default.** A directory where unrelated
  tasks run side by side gave every session everyone's findings. The default
  is now what this session found — every project it filed them under — plus
  one line counting what else is open in the project, so nothing undecided
  drops out of sight. `/findings project` and `/findings all` give the wider
  views; `findings list --scope session|project|all`, `--session ID` (a prefix
  is enough).
- **The session id reaches every assistant.** Claude Code sets
  `$CLAUDE_CODE_SESSION_ID` in the shell; Codex and Opencode do not, so the
  prompt hook now names the session to the model, and the Opencode plugin
  passes its `sessionID` to the hook (cached per session). With no id at all,
  `list` shows the whole project and says so.

## 0.1.1 — 2026-10-01

### Fixed

- **`FOUND_DEFECTS_GUARD=off` no longer stops the ledger.** Recording sat
  inside the guard after the switch, so turning off the check for buried
  findings silently turned off recording as well. The section is recorded
  first now; `FINDINGS_RECORD=off` is the switch for that.
- **`FINDINGS_RECORD=off` works in Opencode.** Only the Stop hook read it; the
  Opencode plugin calls `findings record`, which ignored it. The CLI checks it
  itself now, so the switch means the same in every assistant.
- **`--help` of install.sh and release.sh** used `\?` in sed, a GNU extension.
- **The README described the ledger as written into repositories.** It is one
  file; the repository is a `project` label `/findings` filters on. Also
  corrected: the prompt hook is silent when nothing is *open* (parked findings
  do not count); `-p PATH` is documented; macOS is untested, not supported.
- **The rule said Opencode cannot record.** Its plugin does; it only cannot
  block the end of a turn.

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
