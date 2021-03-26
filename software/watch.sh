#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if ! command -v inotifywait >/dev/null 2>&1; then
    echo "inotifywait missing. Try \"apt-get install inotify-tools\"" 1>&2
    exit 1
fi

PROJECT="${1:-skeleton}"
FILES="${FILES:-$PROJECT third_party build.sh .env .env_shared}"
FLASH="${FLASH:-false}"
MONITOR="${MONITOR:-false}"

source ./env.sh 2>/dev/null

TTY_BAUD=${TTY_BAUD:-115200}

MONITOR_JOB=""

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

while true; do
    if [ "$MONITOR_JOB" != "" ]; then
        kill $MONITOR_JOB
        MONITOR_JOB=""
    fi

    set +o errexit
    ./build.sh "$PROJECT"
    RC=$?

    if [ "$RC" == "0" ] && [ "$MONITOR" == "true" ]; then
        SERIAL_PORT=`./find_port.sh 2>/dev/null`
        echo $SERIAL_PORT
        if [ "$SERIAL_PORT" == "" ]; then
            echo "Failed to find a serial port" >&2
        else
            stty -F $SERIAL_PORT raw speed $TTY_BAUD
            cat $SERIAL_PORT &
            MONITOR_JOB="$!"
        fi
    fi

    set -o errexit

    inotifywait -q -e close_write -r $FILES
done