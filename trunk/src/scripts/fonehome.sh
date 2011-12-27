#!/bin/bash
# $Id$

# Set constants and defaults
NAME='@fonehomename@'
USERNAME='@fonehomeuser@'
CONFIG_FILE='@fonehomeconf@'
KEY_FILE='@fonehomekey@'
RETRY_DELAY="@fonehomeretry@"
KNOWN_HOSTS_FILE="@fonehomehosts@"

# Usage message
usage()
{
    echo "Usage:" 1>&2
    echo "    ${NAME} [-I] [-f conf-file]" 1>&2
    echo "Options:" 1>&2
    echo "    -f    Specify alternate config file (default ${CONFIG_FILE})" 1>&2
    echo "    -I    Initialize: record server's public key (required on first connect)" 1>&2
}

# Log functions
log()
{
    echo ${NAME}: ${1+"$@"} 1>&2
}

# Error function
errout()
{
    log ${1+"$@"}
    exit 1
}

# Bail on errors
set -e

# Parse flags passed in on the command line
INITIALIZE="no"
while [ ${#} -gt 0 ]; do
    case "$1" in
        -f)
            shift
            CONFIG_FILE="$1"
            shift
            ;;
        -I)
            shift
            INITIALIZE="yes"
            ;;
        -h|--help)
            usage
            exit
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "${NAME}: unrecognized flag \`${1}'" 1>&2
            usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done
case "${#}" in
    0)
        ;;
    *)
        usage
        exit 1
        ;;
esac

# Read config file, which should set ${SSH_FLAGS}
if ! [ -r "${CONFIG_FILE}" ]; then
    errout "can't read config file: ${CONFIG_FILE}"
fi
. "${CONFIG_FILE}"

# Verify required fields are set
if [ -z "${SERVER}" ]; then
    errout "no server configured"
fi
if [ -z "${USERNAME}" ]; then
    errout "no username configured"
fi
if [ -z "${KEY_FILE}" -o ! -r "${KEY_FILE}" ]; then
    errout "key file \`${KEY_FILE}' unreadable"
fi
if [ -z "${KNOWN_HOSTS_FILE}" ]; then
    errout "no known hosts file configured"
fi
if [ "${INITIALIZE}" != 'yes' ]; then
    if ! [ -r "${KNOWN_HOSTS_FILE}" ]; then
        errout "known hosts file \`${KNOWN_HOSTS_FILE}' unreadable; did you run once with \`-I' flag?"
    fi
    if ! [ -s "${KNOWN_HOSTS_FILE}" ]; then
        errout "known hosts file \`${KNOWN_HOSTS_FILE}' is empty; did you run once with \`-I' flag?"
    fi
fi

# Doing initialization?
if [ "${INITIALIZE}" = "yes" ]; then
    exec ssh -24xaT -oStrictHostKeyChecking=ask -oUserKnownHostsFile="${KNOWN_HOSTS_FILE}" \
      -oVisualHostKey=yes -oCheckHostIP=no -i "${KEY_FILE}" ${SSH_FLAGS} "${USERNAME}"@"${SERVER}"
fi

# Ensure background process is killed when this script is killed
set -m
trap killchild TERM INT
killchild()
{
    kill %% >/dev/null 2>&1
    exit
}

# Main loop
while true; do
    ssh -24xaTnN -oBatchMode=yes -oExitOnForwardFailure=yes \
      -oStrictHostKeyChecking=yes -oUserKnownHostsFile="${KNOWN_HOSTS_FILE}" \
      -oServerAliveInterval=60 -oServerAliveCountMax=5 -oTCPKeepAlive=yes \
      -oCheckHostIP=no -i "${KEY_FILE}" ${SSH_FLAGS} "${USERNAME}"@"${SERVER}" >/dev/null 2>&1 &
    wait
    sleep ${RETRY_DELAY}
done

