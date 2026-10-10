#!/usr/bin/env bash
# Print skills/findings/SKILL.md, the Codex copy of commands/findings.md.
#
# Codex has no user slash commands; a skill is what `$findings` calls there.
# The body is the command's own, with `$ARGUMENTS` replaced by the words the
# user wrote after `$findings`, so the two say the same thing.
# tests/test_install.sh diffs this output against the committed file, and a
# change to the command fails the suite until the skill is rebuilt:
#
#   bash lib/skill.sh > skills/findings/SKILL.md
set -euo pipefail

src="$(cd "$(dirname "$0")/.." && pwd)/commands/findings.md"
desc="$(sed -n 's/^description: //p' "$src" | sed 's#/findings#$findings#g')"

printf -- '---\nname: findings\ndescription: %s\n---\n' "$desc"
awk 'seen >= 2 { print; next } /^---$/ { seen++ }' "$src" \
    | sed -e 's/`findings \$ARGUMENTS`/`findings <those words>`/' \
          -e 's/`\$ARGUMENTS`/the words after `$findings` (none: the empty case)/'
