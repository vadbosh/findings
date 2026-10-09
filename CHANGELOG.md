# Changelog

## 0.8.7 — 2026-10-09

### Fixed

- **A read-only ledger gives one line, not a traceback.** In the Codex
  `workspace-write` sandbox `~/.local/state` is a read-only file system, and
  `findings reserve` died with `OSError: [Errno 30]` and a Python traceback
  (F195). It now prints `findings: the ledger is not writable here (…) — write
  the items without ids; the Stop hook numbers them` and exits 1, which is
  what the rule already tells the model to do.

## 0.8.6 — 2026-10-09

### Security

- **The prompt hook no longer repeats an urgent finding in full.** It put the
  whole text of every open `[urgent]` finding into the context of every prompt,
  with no length limit. That text can quote a web page or a repository the
  model read, so a planted instruction rode along on every turn until someone
  decided the finding. Each urgent finding is now one line of at most 200
  characters, and a line before the list says it is data, not instructions.
  Found by a security review.

## 0.8.5 — 2026-10-04

### Fixed

- **Both READMEs no longer retell the changelog.** "The three blocks in the
  live log were all false positives, fixed in 0.4.1 and 0.4.4" told the reader
  about versions they do not have; the paragraph keeps the measurement and
  what a false positive looks like.

## 0.8.4 — 2026-10-04

### Fixed

- **macOS: in `install.sh`, `uninstall.sh` and `release.sh`, paths printed as `~/…` came out as `\~/…` under bash 3.2 — the `/bin/bash`
  macOS still ships — because `${x/#$HOME/\~}` keeps the backslash before bash
  4.3. A `tilde` function replaces it; measured in the `bash:3.2` image.**

## 0.8.3 — 2026-10-04

### Fixed

- **README.md:** "Replayed over every Claude Code reply…, it would have fired"
  had a dangling participle — the replies were replayed, not the hook — and ran
  54 words. It is three sentences now. Found by a docs-techwriter review of the
  English READMEs.

## 0.8.2 — 2026-10-04

### Fixed

- **README.RU.md reads as Russian in four places**, found by a docs-techwriter
  review: «хук перед запросом сообщает ID модели» read as "the model's ID"
  where it meant "tells the model the session ID"; an elliptic «То же с…»; a
  dangling «его»; «Бесконечно он не растёт», with a pronoun for the ledger. The
  English README is unchanged.

## 0.8.1 — 2026-10-04

### Fixed

- **A section under another heading is recorded.** "## Найдено по пути"
  matched none of the known headings, so F90–F92 were reserved, shown in the
  chat, and never written; `findings fix F90` then said "no such id". The
  parser now takes "найдено попутно / по ходу / по пути / по дороге /
  заодно", "попутно найдено", "попутные находки", "found along / on the
  way"; the rule names the one heading to use per language.
- **A section written mid-turn is recorded.** The Stop payload carries only
  the last text block; a section followed by AskUserQuestion or more tool
  calls was never seen (F87). In Claude Code the hook now reads every
  assistant text of the turn from the transcript. Codex still gets the last
  block only; the rule asks for the section at the very end of the turn.

## 0.8.0 — 2026-10-04

### Added

- **Several decisions in one line.** `findings skip F80 fix F85` and
  `findings park 4-9 · fix 12` set every status in the line, and print the
  `fix` ids for the assistant to work on; `/findings` takes the same line.
  The mini-help has been suggesting this form since 0.7.0 (`park F10-F13 ·
  fix F18`), and the CLI could not read it.

### Fixed

- **A bad answer no longer crashes the CLI or half-applies.** A word that is
  not an id (`skip F2 fix F1` used to fail on "fix", a stray `-` likewise)
  ended in a Python traceback. Now it is one line naming the word, and every
  id is checked before anything is written: an unknown id anywhere in the
  line changes nothing.

## 0.7.0 — 2026-10-04

### Added

- **The mini-help is under every section, and the hook backs it up.** The
  rule asked for the ready answer and the `fix · park · skip · done · open`
  line only under the closing digest, so a section of new findings came
  without them. Now the rule asks for both under every section; when a
  section names neither `park` nor `skip`, the Stop hook shows the two lines
  under the reply itself, with the section's ids, in the heading's language.

### Changed

- **The notice says what each finding is, not only where.** A line was the
  chat number, the id and the full path; with several findings in one file
  that did not tell them apart. Now it is the chat number, the id, the file
  name and the first ~60 characters of what is wrong:
  `1. F79  2026-10-04.md:33 — сводка memsearch пишет «…`.

## 0.6.0 — 2026-10-04

### Added

- **The hook says which F number each item got, when the reply did not.**
  A session started after 0.5.0 still wrote its items without ids: the rule
  asks the model to run `findings reserve`, and it did not. Now, when an item
  comes without its id, gets a different one, or is already in the ledger,
  the Stop hook shows a notice under the reply — chat number, id and path per
  item, `(already recorded: <status>)` for a duplicate. It does not block the
  reply. Silent when every item carries the id it was recorded under.

## 0.5.1 — 2026-10-03

### Fixed

- **The README's guard figure is measured again, and says how.** "26 of 1157
  replies, nearly all on target" had no recorded method, and the live log
  disagreed (three blocks, all false). Replayed over every Claude Code reply on
  the machine: 53 of 3236 (1.6%), about seven in ten real when read one by
  one, most of them from before the rule.

## 0.5.0 — 2026-10-03

### Added

- **A new finding carries its id in the chat.** `findings reserve N` hands out
  the next N ids before the reply is written; each item of the section opens
  with one (`1. F60: [related] …`), and the hook records the item under it.
  The reader answers `/findings fix F60` straight from the reply. An id
  reserved by another session, or never reserved, is not taken — the item gets
  the next free id, as before. Reservations younger than a day survive
  compaction. The rule asks for the ids; without a shell, items go without
  them and are numbered by the hook.

## 0.4.6 — 2026-10-03

### Changed

- **Every digest ends with the same two lines.** The rule now fixes them: a
  ready answer from the real ids, then a one-line mini-help naming `fix`,
  `park`, `skip`, `done` and `open`. A closing digest had improvised its own
  hint with two verbs only. `/findings` uses the same one-line mini-help in
  place of its five-line list.

## 0.4.5 — 2026-10-02

### Changed

- **A recorded finding is always named by its ledger id.** The rule now says
  that any later mention of a finding carries its `F` number and the ready
  command (`/findings fix F51`), and that the model runs `findings list` for
  the id itself. A reply had sent the reader to look the id up.

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
