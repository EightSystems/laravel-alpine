#!/bin/bash

function keepRunning() {
    while true; do
        sleep 10
    done

    exit 0
}

if [ -z "$START_SCRIPT_CHECK_VARIABLE" -o -z "$START_SCRIPT_EXPECTED_VALUE" ]; then
    echo "You need to set both START_SCRIPT_CHECK_VARIABLE and START_SCRIPT_EXPECTED_VALUE variables"
    exit 1
else
    if [ -z "${!START_SCRIPT_CHECK_VARIABLE}" ]; then
        echo "Not starting $* as the $START_SCRIPT_CHECK_VARIABLE is empty"
        keepRunning
    else
        if [ "${!START_SCRIPT_CHECK_VARIABLE}" = "$START_SCRIPT_EXPECTED_VALUE" ]; then
            sh -c "$*"
            last_exit_code=$?
            exit $?
        else
            echo "Not starting $* as the $START_SCRIPT_CHECK_VARIABLE is not equal to $START_SCRIPT_EXPECTED_VALUE"
            keepRunning
        fi
    fi
fi
