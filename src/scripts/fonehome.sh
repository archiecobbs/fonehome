#!/bin/bash

# Set constants and defaults
NAME='@fonehomename@'
USERNAME='@fonehomeuser@'
CONFIG_FILE='@fonehomeconf@'
KEY_FILE='@fonehomekey@'
RETRY_DELAY='@fonehomeretry@'
KNOWN_HOSTS_FILE='@fonehomehosts@'
FACILITY_PATTERN='^(auth|authpriv|cron|daemon|ftp|lpr|mail|news|security|user|uucp|local[0-7])$'
SYSLOG_TAG='@fonehomename@'
SYSLOG_FACILITY='@fonehomelogfac@'

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
perr()
{
    echo ${NAME}: ${1+"$@"} 1>&2
}

log()
{
    LEVEL="${1}"
    shift
    logger -t "${SYSLOG_TAG}" -p "${SYSLOG_FACILITY}"."${LEVEL}" ${1+"$@"}
    if [ -t 2 ]; then
        perr ${1+"$@"}
    fi
}

# Error function
errout()
{
    perr ${1+"$@"}
    if ! [ -t 2 ]; then
        log err ${1+"$@"}
    fi
    exit 1
}

# Bail on errors
set -e

# Enable job control
set -m

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

# Read config file, which should set configuration variables
if ! [ -r "${CONFIG_FILE}" ]; then
    errout "can't read config file: ${CONFIG_FILE}"
fi
. "${CONFIG_FILE}"

# Verify required fields are set
if [[ -z SERVER ]]; then
    errout "no server(s) configured"
fi
if [[ -z USERNAME ]]; then
    errout "no username(s) configured"
fi
if [[ -z KEY_FILE ]]; then
    errout "no key file(s) configured"
fi

# Sanity check syslog facility name
if ! echo "${SYSLOG_FACILITY}" | grep -qE "${FACILITY_PATTERN}"; then
    errout "invalid syslog facility name \`${SYSLOG_FACILITY}'"
fi

# Make config variables into arrays
declare -a SERVER USERNAME KEY_FILE SSH_FLAGS RETRY_DELAY

# Get number of servers
declare -i NUM_SERVERS="${#SERVER[@]}"
declare -i i

# Extend all arrays, repeating last element as necessary
for ((i=0; $i < "${NUM_SERVERS}"; i++)); do
    if (( "${#USERNAME[@]}" <= $i )); then
        USERNAME[$i]="${USERNAME[$(($i - 1))]}"
    fi
    if (( "${#KEY_FILE[@]}" <= $i )); then
        KEY_FILE[$i]="${KEY_FILE[$(($i - 1))]}"
    fi
    if (( "${#SSH_FLAGS[@]}" <= $i )); then
        SSH_FLAGS[$i]="${SSH_FLAGS[$(($i - 1))]}"
    fi
    if (( "${#RETRY_DELAY[@]}" <= $i )); then
        RETRY_DELAY[$i]="${RETRY_DELAY[$(($i - 1))]}"
    fi
done

# Check required files
if [ -z "${KNOWN_HOSTS_FILE}" ]; then
    errout "no known hosts file configured"
fi
if [ "${INITIALIZE}" = 'yes' ]; then
    KNOWN_HOSTS_DIR=`dirname "${KNOWN_HOSTS_FILE}"`
    if ! [ -w "${KNOWN_HOSTS_DIR}" ]; then
        errout "known hosts file directory \`${KNOWN_HOSTS_DIR}' is unwritable"
    fi
else
    if ! [ -r "${KNOWN_HOSTS_FILE}" ]; then
        errout "known hosts file \`${KNOWN_HOSTS_FILE}' unreadable; did you run once with \`-I' flag?"
    fi
    if ! [ -s "${KNOWN_HOSTS_FILE}" ]; then
        errout "known hosts file \`${KNOWN_HOSTS_FILE}' is empty; did you run once with \`-I' flag for each server?"
    fi
fi
for ((i=0; $i < "${NUM_SERVERS}"; i++)); do
    if ! [ -r "${KEY_FILE[$i]}" ]; then
        errout "key file \`${KEY_FILE[$i]}' for server ${SERVER[$i]} is unreadable"
    fi
done

# Doing initialization?
if [ "${INITIALIZE}" = "yes" ]; then
    for ((i=0; $i < "${NUM_SERVERS}"; i++)); do
        perr "confirming server key for ${SERVER[$i]}"
        ssh -24xaT -oStrictHostKeyChecking=ask -oUserKnownHostsFile="${KNOWN_HOSTS_FILE}" \
          -oVisualHostKey=yes -oCheckHostIP=no -i "${KEY_FILE[$i]}" ${SSH_FLAGS[$i]} "${USERNAME[$i]}"@"${SERVER[$i]}"
    done
    exit 0
fi

# Subshell - there is one of these for each server
subshell()
{
    # Don't die on error
    set +e

    # Which server am I?
    INDEX="${1}"

    # Create temporary file to hold output of ssh(1) command
    OUTPUT_FILE=`mktemp -q /tmp/fonehome.XXXXXXXX`
    if [ $? -ne 0 ]; then
        log error "can't create temporary file"
        OUTPUT_FILE="/dev/null"
    fi

    # Clean up output file on exit
    trap "if [ \"${OUTPUT_FILE}\" != '/dev/null' ]; then rm -f \"${OUTPUT_FILE}\"; fi; exit" INT TERM

    # Connect to server; reconnect if we get disconnected
    while true; do
        log info initiating connection to "${SERVER[$INDEX]}"
        ssh -24xaTnN -oBatchMode=yes -oExitOnForwardFailure=yes \
          -oStrictHostKeyChecking=yes -oUserKnownHostsFile="${KNOWN_HOSTS_FILE}" \
          -oServerAliveInterval=60 -oServerAliveCountMax=5 -oTCPKeepAlive=yes \
          -oCheckHostIP=no -i "${KEY_FILE[$INDEX]}" ${SSH_FLAGS[$INDEX]} "${USERNAME[$INDEX]}"@"${SERVER[$INDEX]}" >"${OUTPUT_FILE}" 2>&1
        if [ -s "${OUTPUT_FILE}" ]; then
            log warn "connection to ${SERVER[$INDEX]} failed: `cat \"${OUTPUT_FILE}\" | tr \\\\n ' '`"
        else
            log warn "connection to ${SERVER[$INDEX]} failed"
        fi
        sleep "${RETRY_DELAY[$INDEX]}"
    done
}

# This function is used to ensure the subshells are killed when this script is killed
killshells()
{
    set +e
    jobs -p | sed 's/^/-/g' | xargs -r kill --
    log info shutting down
    wait
    exit
}

# Clean up subshells on exit
trap killshells INT TERM

# Start the subshells
for ((i=0; $i < "${NUM_SERVERS}"; i++)); do
    subshell $i &
done

# Now we just hang out
wait

