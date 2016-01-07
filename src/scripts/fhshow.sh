#!/bin/sh

#
# Reads @portsfile@ to determine which machines are fonehome'd in to the server.
#

# Constants
FONEHOMEUSER="@fonehomeuser@"
PORTSFILE="@fonehomeports@"
NAME=`basename "${0}"`

# Bail on error
set -e

# Emit warning
warn()
{
    echo "${NAME}": ${1+"$@"}
}

# Convert hex address from /proc/net/foo back to normal
unhexaddr()
{
    HEX="$1"
    case "${#HEX}" in
        8)
            dc -e "16i${HEX:0:2}[.]${HEX:2:2}[.]${HEX:4:2}[.]${HEX:6:2}nnnnnnn"
            ;;
        32)
            # ipv6 - todo
            echo "${HEX}"
            ;;
        *)
            echo "${HEX}"
            ;;
    esac
}

# Must be root
if [ `id -u` -ne 0 ]; then
    echo "${NAME}: you must be root" 1>&2
    exit 1
fi

# Iterate over configured ports
SPACE='[[:space:]]+'
WORD='[^[:space:]]+'
LAST_PROCESS=""
grep -vE '^[[:space:]]*(#.*|)$' "${PORTSFILE}" | while read PORT CLIENT DESCRIPTION; do

    # Determine if any process is listening on this port (TCP or UDP)
    PORT16=`dc -e "16o${PORT}n"`
    PAT="^[[:space:]]*${WORD}${SPACE}[0-9A-F]+:${PORT16}${SPACE}${WORD}${SPACE}0A${SPACE}(${WORD}${SPACE}){5}(${WORD}).*$"
    INODES=`cat /proc/net/tcp* | sed -rn 's%'"${PAT}"'%\2%gp'`
    PAT="^[[:space:]]*${WORD}${SPACE}[0-9A-F]+:${PORT16}${SPACE}(${WORD}${SPACE}){7}(${WORD}).*$"
    INODES=`echo "${INODES}" && cat /proc/net/udp* | sed -rn 's%'"${PAT}"'%\2%gp'`
    if [ -z "${INODES}" ]; then
        continue
    fi

    # Find the process owning the listening socket(s)
    LNAMES=""
    DELIM="("
    for INODE in ${INODES}; do
        LNAMES="${LNAMES} ${DELIM} -lname socket:\[${INODE}\]"
        DELIM="-o"
    done
    LNAMES="${LNAMES} )"
    PROCFILE=`find /proc -mindepth 3 -maxdepth 3 -path '/proc/*/fd/*' ${LNAMES} 2>/dev/null || true`
    if [ -z "${PROCFILE}" ]; then
        warn could not determine process listening on port ${PORT} \(socket: ${INODES}\)
        continue
    fi
    CHILD_ID=`echo "${PROCFILE}" | sed -rn 's|^/proc/([^/]+)/fd/[^/]+$|\1|gp' | sort -u`
    if ! [[ "${CHILD_ID}" =~ ^[0-9]+$ ]]; then
        warn multiple processes listening on port ${PORT} \(${CHILD_ID}\)
        continue
    fi
    PROCESS="${CHILD_ID} `cat /proc/"${CHILD_ID}"/cmdline`"

    # Find parent process
    PARENT_ID=`sed -rn "s|^${WORD}${SPACE}\([^)]*\)${SPACE}${WORD}${SPACE}(${WORD}).*$|\1|gp" /proc/${CHILD_ID}/stat`

    # Find who parent is connected to
    DELIM='('
    PAT="^[[:space:]]*${WORD}${SPACE}${WORD}${SPACE}([0-9A-F]+:[0-9A-F]+)${SPACE}01(${SPACE}${WORD}){5}${SPACE}"
    for INODE in `find /proc/"${PARENT_ID}"/fd -lname 'socket:*' 2>/dev/null \
      | xargs -r readlink | sed -rn 's/^socket:\[([^]]+)\]$/\1/gp'`; do
        PAT="${PAT}${DELIM}${INODE}"
        DELIM='|'
    done
    PAT="${PAT}).*$"
    REMOTE_ADDR=`cat /proc/net/tcp* | sed -rn 's%'"${PAT}"'%\1%gp' | head -n 1`
    if [ -n "${REMOTE_ADDR}" ]; then
        REMOTE_IP=`echo "${REMOTE_ADDR}" | sed -rn 's/:.*$//gp'`
        REMOTE_IP=`unhexaddr "${REMOTE_IP}"`
        REMOTE_PORT=`echo "${REMOTE_ADDR}" | sed -rn 's/^.*://gp'`
        REMOTE_PORT=`dc -e "16i${REMOTE_PORT}n"`
        PROCESS="[${REMOTE_IP}:${REMOTE_PORT}] ${PROCESS}"
    fi

    # Show process (if changed)
    if [ "${PROCESS}" != "${LAST_PROCESS}" ]; then
        echo "${PROCESS}:"
        LAST_PROCESS="${PROCESS}"
    fi

    # Show port
    printf '    Port %5s:  %s' "${PORT}" "${CLIENT}"
    if [ -n "${DESCRIPTION}" ]; then
        printf ': %s' "${DESCRIPTION}"
    fi
    printf '\n'
done
