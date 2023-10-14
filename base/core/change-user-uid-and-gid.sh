#!/bin/bash

# Use this script to change an user uid and gid, and also update it's owned files.
# This will also see if there's any other user with a matching id, and invert the IDs

if [ "$(id -u)" -ne 0 ]; then echo "Please run as root." >&2; exit 1; fi

function getTheMaxUidUsed {
    echo "$(grep -v ':65534:' /etc/passwd | grep -v ':65533:' | cut -d: -f3 | sort -n | tail -1)"
}

function getTheMaxGidUsed {
    echo "$(grep -v ':65534:' /etc/group | grep -v ':65533:' | cut -d: -f3 | sort -n | tail -1)"
}

function getUserUid {
    __USER_NAME="$1"

    echo "$(grep "^$__USER_NAME:" /etc/passwd | cut -d: -f3 | sort -n | tail -1)"
}

function getGroupGid {
    __GROUP_NAME="$1"

    echo "$(grep "^$__GROUP_NAME:" /etc/group | cut -d: -f3 | sort -n | tail -1)"
}

function hasUserInDesiredUid {
    __DESIRED_UID="$1"
    __SKIP_USER="$2"
    __MATCHING_USER="$(grep "^.*:.*:$__DESIRED_UID" /etc/passwd | grep -v "^$__SKIP_USER:" | cut -d: -f1 | head -1)"

    if [ ! -z "$__MATCHING_USER" ]; then
        echo $__MATCHING_USER
        return 1
    else
        return 0
    fi
}

function hasGroupInDesiredGid {
    __DESIRED_GID="$1"
    __SKIP_GROUP="$2"
    __MATCHING_GROUP="$(grep "^.*:.*:$__DESIRED_GID" /etc/group | grep -v "^$__SKIP_GROUP:" | cut -d: -f1 | head -1)"

    if [ ! -z "$__MATCHING_GROUP" ]; then
        echo $__MATCHING_GROUP
        return 1
    else
        return 0
    fi
}

function moveGroup {
    __DESTINATION_GID="$1"
    __GROUP_NAME="$2"
    __PREVIOUS_GID="$3"

    groupmod -g "$__DESTINATION_GID" "$__GROUP_NAME"

    find / -group "$__PREVIOUS_GID" -exec chgrp -h "$__GROUP_NAME" {} \;
}

function moveUser {
    __DESTINATION_UID="$1"
    __USER_NAME="$2"
    __PREVIOUS_UID="$3"

    usermod -u "$__DESTINATION_UID" "$__USER_NAME"

    find / -user "$__PREVIOUS_UID" -exec chown -h "$__USER_NAME" {} \;
}

LAST_MAX_UID=$(getTheMaxUidUsed)
TEMPORARY_UID=$(($LAST_MAX_UID+1))
LAST_MAX_GID=$(getTheMaxGidUsed)
TEMPORARY_GID=$(($LAST_MAX_GID+1))

USER_NAME="$1"
GROUP_NAME="$2"
NEW_UID="$3"
NEW_GID="$4"

if [ -z "$USER_NAME" -o -z "$GROUP_NAME" -o -z "$NEW_UID" -o -z "$NEW_GID" ]; then
    echo "You need to call it with the following parameters: change-user-uid-and-gid.sh USER_NAME GROUP_NAME NEW_UID NEW_GID"
    echo ""
    echo "Ex: change-user-uid-and-gid.sh www-data www-data 33 33"

    exit 1
else
    CURRENT_USER_UID=$(getUserUid "$USER_NAME")
    CURRENT_GROUP_GID=$(getGroupGid "$GROUP_NAME")

    MATCHING_USER=$(hasUserInDesiredUid "$NEW_UID" "$USER_NAME")
    HAS_MATCHING_USER=$?

    MATCHING_GROUP=$(hasGroupInDesiredGid "$NEW_GID" "$GROUP_NAME")
    HAS_MATCHING_GROUP=$?

    echo "Moving $USER_NAME (UID $CURRENT_USER_UID) to $NEW_UID, and $GROUP_NAME (GID $CURRENT_GROUP_GID) to $NEW_GID"

    if [ "$HAS_MATCHING_GROUP" = "1" ]; then
        echo "Moving group $MATCHING_GROUP to a temporary new GID ($TEMPORARY_GID) as it's currently using the GID $NEW_GID"

        if [ "$TEMPORARY_GID" -gt "65533" ]; then
            echo "We don't have any temporary GID available, as $TEMPORARY_GID is greater than 65533"
            exit 1
        else
            moveGroup "$TEMPORARY_GID" "$MATCHING_GROUP" "$NEW_GID"
        fi
    fi

    if [ "$HAS_MATCHING_USER" = "1" ]; then
        echo "Moving user $MATCHING_USER to a temporary new UID ($TEMPORARY_UID) as it's currently using the UID $NEW_UID"
        if [ "$TEMPORARY_UID" -gt "65533" ]; then
            echo "We don't have any temporary UID available, as $TEMPORARY_UID is greater than 65533"
            exit 1
        else
            moveUser "$TEMPORARY_UID" "$MATCHING_USER" "$NEW_UID"
        fi
    fi

    if [ "$CURRENT_GROUP_GID" != "$NEW_GID" ]; then
        moveGroup "$NEW_GID" "$GROUP_NAME" "$CURRENT_GROUP_GID"
    else
        echo "Skipping moving group as it's the same GID"
    fi

    if [ "$CURRENT_USER_UID" != "$NEW_UID" ]; then
        moveUser "$NEW_UID" "$USER_NAME" "$CURRENT_USER_UID"
    else
        echo "Skipping moving user as it's the same UID"
    fi

    if [ "$HAS_MATCHING_GROUP" = "1" ]; then
        echo "Moving group $MATCHING_GROUP to a new GID ($CURRENT_GROUP_GID)"

        moveGroup "$CURRENT_GROUP_GID" "$MATCHING_GROUP" "$TEMPORARY_GID"
    fi

    if [ "$HAS_MATCHING_USER" = "1" ]; then
        echo "Moving user $MATCHING_USER to a new UID ($CURRENT_USER_UID)"

        moveUser "$CURRENT_USER_UID" "$MATCHING_USER" "$TEMPORARY_UID"
    fi

    echo "All set! User and groups updated, and all files repermissioned"
fi