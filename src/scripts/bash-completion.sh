# fhssh(1)/fhscp(1) bash completion script

_read_fonehome_hosts()
{
    if [ -r @fonehomeports@ ]; then
        cat @fonehomeports@ \
          | sed -rn 's/^[0-9]+[[:space:]]+([^[:space:]]+).*$/\1'"${1}"'/gp' \
          | sort -u
    fi
}

_fhssh()
{
    local cur="${COMP_WORDS[COMP_CWORD]}"
    case "${COMP_CWORD}" in
    2)
        COMPREPLY=( $( compgen -o default -c -- "${cur}" ) )
        ;;
    1)
        COMPREPLY=( $( compgen -o default -W "`_read_fonehome_hosts`" -- "${cur}" ) )
        ;;
    *)
        COMPREPLY=()
        ;;
    esac
}

_fhscp()
{
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local hostpat='^('"`_read_fonehome_hosts | tr \\n \|`"'):'
    case "${COMP_CWORD}" in
    2)
        local prev="${COMP_WORDS[${COMP_CWORD} - 1]}"
        if [[ "${prev}" =~ ${hostpat} ]]; then
            COMPREPLY=()
        else
            compopt -o nospace
            COMPREPLY=( $( compgen -W "`_read_fonehome_hosts :`" -- "${cur}" ) )
        fi
        ;;
    1)
        if [[ "${cur}" =~ ${hostpat} ]]; then
            COMPREPLY=()
        elif ! [[ "${cur}" =~ / ]]; then
            compopt -o nospace
            COMPREPLY=( $( compgen -W "`_read_fonehome_hosts :`" -- "${cur}" ) )
        else
            COMPREPLY=()
        fi
        ;;
    *)
        COMPREPLY=()
        ;;
    esac
}

complete -F _fhssh -o default fhssh
complete -F _fhscp -o default fhscp
