# shellcheck shell=bash
# Bash completion for findings: Tab after "findings" offers the commands, then
# the ids of the findings, the options and their values.
#
# ./install.sh puts this file into ~/.local/share/bash-completion/completions/findings,
# where bash-completion loads it the first time Tab is pressed after "findings".
# Without the bash-completion package, source it from ~/.bashrc instead.
#
# Ids are those of the project of the current directory, as `findings list`
# finds it, or all of them when it has none.
#
# The words come from `findings __complete`, which reads the ledger only — not
# the IDE transcripts `findings sessions` reads — so a Tab stays quick. The
# command list comes from there too, so this file cannot fall behind the CLI.

_findings_words() {   # what [arg] — one word per line from the CLI itself
    command findings __complete "$@" 2>/dev/null
}

# A loop, not mapfile: mapfile is bash 4, and macOS ships bash 3.2.
_findings_fill() {    # reads lines into COMPREPLY
    local w
    COMPREPLY=()
    while IFS= read -r w; do [ -n "$w" ] && COMPREPLY+=("$w"); done
}

_findings_reply() {   # words — the ones that start with the current word
    local IFS=$'\n'
    _findings_fill < <(compgen -W "$1" -- "$cur")
    # In the order given: ids by number, sessions newest first. bash 4.4+;
    # older ones sort alphabetically, F10 before F8.
    compopt -o nosort 2>/dev/null || true
}

_findings_dirs() {    # directories, plus the projects the ledger knows
    local IFS=$'\n'
    _findings_fill < <({ compgen -d -- "$cur"; compgen -W "$(_findings_words projects)" -- "$cur"; } | sort -u)
    compopt -o filenames 2>/dev/null || true   # bash 4: escape spaces, add the /
}

_findings_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}" prev="${COMP_WORDS[COMP_CWORD-1]}"
    local cmd="${COMP_WORDS[1]:-}" flags=""
    COMPREPLY=()

    if [ "$COMP_CWORD" -eq 1 ]; then
        if [[ $cur == -* ]]; then _findings_reply $'--help\n-h'
        else _findings_reply "$(_findings_words commands)"; fi
        return 0
    fi

    case "$prev" in
        --ide)              _findings_reply $'claude\ncodex\nopencode'; return 0 ;;
        --status)           _findings_reply $'open\npark\nskip\ndone\nany\nopen,park'; return 0 ;;
        --session)          _findings_reply "$(_findings_words sessions)"; return 0 ;;
        -p|--project|--cwd) _findings_dirs; return 0 ;;
        --scope)
            if [[ $cur == [/~.]* ]]; then _findings_dirs
            else _findings_reply $'session\nproject\nall'; fi
            return 0 ;;
        --tag)              _findings_reply $'related\nunrelated\nurgent'; return 0 ;;
    esac

    # Every option of the command, from its parser: `findings __complete flags CMD`.
    if [[ $cur == -* ]]; then
        flags="$(_findings_words flags "$cmd")"
        _findings_reply "$flags"
        return 0
    fi

    case "$cmd" in
        done|skip|park|fix|brief) _findings_reply "$(_findings_words ids)" ;;
        open)          _findings_reply "$(_findings_words ids closed)" ;;
        set)
            if [ "$COMP_CWORD" -eq 2 ]; then _findings_reply $'open\npark\nskip\ndone'
            elif [ "${COMP_WORDS[2]}" = open ]; then _findings_reply "$(_findings_words ids closed)"
            else _findings_reply "$(_findings_words ids)"; fi ;;
        list|sessions) _findings_dirs ;;
    esac
    return 0
}

complete -F _findings_complete findings
