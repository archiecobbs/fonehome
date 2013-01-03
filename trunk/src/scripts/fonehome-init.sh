#!/bin/bash
# $Id$

### BEGIN INIT INFO
# Provides:             @fonehomename@
# Required-Start:       $network $syslog $remote_fs
# Default-Start:        3 5
# Required-Stop:        $syslog $remote_fs
# Default-Stop:         0 1 2 6
# Short-Description:    Fonehome client
# Description:          Remote access to machines behind firewalls
### END INIT INFO

# Source LSB function library.
if [ -r /lib/lsb/init-functions ]; then
    . /lib/lsb/init-functions
else
    exit 1
fi

rc_reset

# Constants
NAME="@fonehomename@"
CONFIG_FILE='@fonehomeconf@'
SCRIPT='@fonehomescript@'

# start
function start() {
    echo -n "Starting ${NAME}: "
    if ! [ -r "${CONFIG_FILE}" ]; then
        echo -n " ERROR: can't read ${CONFIG_FILE}!"
        rc_status -s
    else
        startproc -q -s -t 1 "${SCRIPT}"
        rc_status -v
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        echo -n "Stopping ${NAME}: "
        killproc -G "${SCRIPT}"
        rc_status -v
        ;;
    restart)
        $0 stop
        $0 start
        ;;
    status)
        echo -n "Checking ${NAME}: "
        checkproc "${SCRIPT}"
        rc_status -v
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
esac

rc_exit

