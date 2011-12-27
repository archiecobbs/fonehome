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

# Map fonehome port to client name
port2client()
{
    if ! [ -r "${PORTSFILE}" ]; then
        return
    fi
    PAT='[[:space:]]+([^[:space:]]+)([[:space:]]+([^[:space:]](.*[^[:space:]])?))?[[:space:]]*$'
    sed -rn 's/^'"${1}${PAT}"'/\1/gp' "${PORTSFILE}" | head -1
}

# Map fonehome port to purpose of port
port2purpose()
{
    if ! [ -r "${PORTSFILE}" ]; then
        return
    fi
    PAT='[[:space:]]+([^[:space:]]+)([[:space:]]+([^[:space:]](.*[^[:space:]])?))?[[:space:]]*$'
    sed -rn 's/^'"${1}${PAT}"'/\3/gp' "${PORTSFILE}" | head -1
}

# Must be root
if [ `id -u` -ne 0 ]; then
    echo "${NAME}: you must be root" 1>&2
    exit 1
fi

# Find all sshd's running as fonehome user
CHILDREN=`ps augxwww | grep -E '^'"${FONEHOMEUSER}"'.*sshd' | awk '{print $2}'`
for CHILD in ${CHILDREN}; do

	# Find child's parent's PID
	PARENT=`sed -rn 's/^'"${CHILD}"' \([^)]+\) . ([0-9]+).*$/\1/gp' /proc/"${CHILD}"/stat`

	# Get originating IP:port of parent
	PAT='^tcp[[:space:]]+([^[:space:]]+[[:space:]]+){3}([^[:space:]]+)[[:space:]]+ESTABLISHED[[:space:]]+'"${PARENT}"'/sshd:.*$'
	SRC=`netstat -nap | sed -rn 's%'"${PAT}"'%\2%gp'`

	# Display connection info
	printf 'Fonehome SSHD %s from %s:\n' "${PARENT}" "${SRC}"

	# Display each TCP port reverse-forwarded by the child
	PAT='^tcp[[:space:]]+([^[:space:]]+[[:space:]]+){2}[0-9:.]+:([0-9]+)[[:space:]]+([^[:space:]]+)[[:space:]]+LISTEN[[:space:]]+'"${CHILD}"'/sshd:.*$'
	netstat -nap | sed -rn 's%'"${PAT}"'%\2%gp' | while read PORT; do
		CLIENT=`port2client "${PORT}"`
        if [ -n "${CLIENT}" ]; then
            PURPOSE=`port2purpose "${PORT}"`
        else
            CLIENT="(Unknown)"
            PURPOSE=''
        fi
		printf '    Port %5s:  %s' "${PORT}" "${CLIENT}"
        if [ -n "${PURPOSE}" ]; then
            printf ': %s' "${PURPOSE}"
        fi
		printf '\n'
	done
done

