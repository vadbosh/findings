#!/usr/bin/env bash
# release.sh — keep the changelog, the tag and the installed copies in agreement.
#
#   ./release.sh check     say whether they agree; exit 3 if they do not
#   ./release.sh tag       create the missing annotated tag for the current version
#
# The newest numbered heading in CHANGELOG.md (`## 0.1.0 — 2026-10-01`) is the
# version; there is no version string anywhere else. A release is: rename
# `## Unreleased` to the number and date, commit, `./release.sh tag`, push with
# --follow-tags, ./install.sh. `check` says which of those steps is missing,
# including the last one: an installed copy that is behind is the copy that runs.
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SRC" || exit 2

version() {
    sed -n 's/^## \([0-9][0-9.]*\) — .*/\1/p' CHANGELOG.md | head -1
}

# Installed path for each shipped file, as install.sh writes it.
installed() {
    cat <<EOF
bin/findings $HOME/.local/bin/findings
bin/findings-hook $HOME/.local/bin/findings-hook
bin/found-defects-guard $HOME/.local/bin/found-defects-guard
rules/found-defects-last.md $HOME/.claude/rules/found-defects-last.md
rules/found-defects-last.md $HOME/.codex/memories/found-defects-last.md
rules/found-defects-last.md $HOME/.config/opencode/instructions/found-defects-last.md
commands/findings.md $HOME/.claude/commands/findings.md
commands/findings.md $HOME/.config/opencode/commands/findings.md
plugins/opencode/findings.ts $HOME/.config/opencode/plugins/findings.ts
EOF
}

check() {
    local v bad=0 n=0 stale=0
    v="$(version)"
    if [ -z "$v" ]; then echo "  version:      none — no '## X.Y.Z — date' heading in CHANGELOG.md"; return 3; fi
    echo "  version:      $v (CHANGELOG.md)"
    if git rev-parse -q --verify "refs/tags/v$v" >/dev/null; then
        echo "  git tag:      v$v exists"
        local since
        since="$(git rev-list --count "v$v..HEAD")"
        if [ "$since" -eq 0 ]; then
            echo "  unreleased:   nothing since v$v"
        else
            echo "  unreleased:   $since commit(s) since v$v"
            grep -q '^## Unreleased' CHANGELOG.md || { echo "                and no '## Unreleased' section describes them"; bad=1; }
        fi
    else
        echo "  git tag:      v$v MISSING — ./release.sh tag"; bad=1
    fi
    [ -z "$(git status --porcelain)" ] || { echo "  working tree: uncommitted changes"; bad=1; }
    while read -r src dst; do
        [ -e "$dst" ] || continue
        n=$((n + 1))
        if ! cmp -s "$src" "$dst"; then echo "  installed:    ${dst/#$HOME/\~} differs from $src — ./install.sh"; stale=1; fi
    done < <(installed)
    [ "$stale" -eq 0 ] && echo "  installed:    $n cop(ies), all identical to this checkout"
    [ "$stale" -eq 0 ] || bad=1
    if [ "$bad" -eq 0 ]; then echo "  everything agrees on $v"; return 0; fi
    return 3
}

make_tag() {
    local v
    v="$(version)"
    [ -n "$v" ] || { echo "no version in CHANGELOG.md" >&2; return 2; }
    if git rev-parse -q --verify "refs/tags/v$v" >/dev/null; then echo "v$v already exists"; return 0; fi
    [ -z "$(git status --porcelain)" ] || { echo "commit first: the tag must point at what CHANGELOG.md describes" >&2; return 2; }
    git tag -a "v$v" -m "findings $v"
    echo "created v$v at $(git rev-parse --short HEAD)"
    echo "push it with:  git push --follow-tags"
}

case "${1:-check}" in
    check) check ;;
    tag)   make_tag ;;
    *)     sed -n '2,11p' "$0" | sed 's/^# \?//'; exit 2 ;;
esac
