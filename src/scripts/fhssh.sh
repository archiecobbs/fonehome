#!/bin/bash

# Constants
PORTSFILE="@fonehomeports@"
NAME=`basename "${0}"`
PAT='^([0-9]+)[[:space:]]+([^[:space:]]+)([[:space:]]+([^[:space:]](.*[^[:space:]])?))?[[:space:]]*$'

# Bail on error
set -e

# Log functions
log()
{
    echo ${NAME}: ${1+"$@"} 1>&2
}

# Find machine in ports file
find_machine()
{
    for ARG in ${PARAMETERS[@]}; do
        for MACHINE in ${@}; do
            PATTERN="^([^@]+@)?${MACHINE/./\.}(:.*)?$"
            if [[ "${ARG}" =~ ${PATTERN} ]]; then
                return 0
            fi
        done
    done
    return 1
}

# Bail on errors
set -e

# Verify ports file exists
if ! [ -r "${PORTSFILE}" ]; then
    echo "${NAME}: ports file \`${PORTSFILE}' is unreadable" 1>&2
    exit 1
fi

# Copy command line parameters
PARAMETERS=("$@")

# Get the list of valid machine names
MACHINES=`grep -E "${PAT}" "${PORTSFILE}" | awk '{ print $2 }'`

# Verify a valid machine is specified somewhere on the command line
if ! find_machine ${MACHINES}; then
    echo "${NAME}: client machine not found" 1>&2
    echo "${NAME}: valid machine names are:" 1>&2
    echo ${MACHINES} | tr ' ' '\n' | sort -u | sed -r 's/^/    /g' 1>&2
    exit 1
fi

# Get the matching machine's reverse-tunnelled SSH port; assume the first match is it
PORT=`grep -E "${PAT}" "${PORTSFILE}" | awk '{ if ( $2 == "'"${MACHINE}"'" ) { print $1; exit; } }'`

# Edit parameters
I=0
for ARG in ${PARAMETERS[@]}; do
    PATTERN="^([^@]+@)?${MACHINE/./\.}(:.*)?$"
    if [[ "${ARG}" =~ ${PATTERN} ]]; then
        PARAMETERS[$I]="${ARG/${MACHINE}/127.0.0.1}"
        break
    fi
    I=`expr $I + 1`
done

# Forward keys by default for ssh
ADD_ARGS=""
if [ "${NAME:2}" = "ssh" ]; then
    ADD_ARGS="${ADD_ARGS} -A"
fi

# Enable compression by default for scp
if [ "${NAME:2}" = "scp" ]; then
    ADD_ARGS="${ADD_ARGS} -C"
fi

# Go
exec "${NAME:2}" ${ADD_ARGS} \
  -oPort="${PORT}" \
  -oProtocol=2 \
  "${PARAMETERS[@]}"

