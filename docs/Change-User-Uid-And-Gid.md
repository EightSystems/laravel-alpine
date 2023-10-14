# Changing users UID and groups GID

There might be cases of when you are connecting to some NFS shared folder, and or any sort of Unix server that requires you to use write and/or read files with an specific UID/GID.

One case is when you are migrating from the usual One Web server serving your application to a fleet of containers, or you are using containers to add more processing power in spikes time.

For that case, you might need to adjust the `www-data` (or any other user for that matter) UID, and it's respective group GID.

That's why we created this `change-user-uid-and-gid.sh` script, it will look for any conflicting user/group with the desired UID and GID, move them to a temporary UID/GID, move the user you need to this desired UID and GID, and then move back the conflicting user/group the your desired user UID/GID.

For example, www-data runs as `82`, and you want to be Debian compatible, which has `www-data` running as `33`, you will notice that we have an user called `xfs` (X Font Server), which has `33` as it's UID/GID, so, in order to be Debian compatible, you can call this script, and it will take care of all the work for swapping these UID/GID.

You can call it as:

```
change-user-uid-and-gid.sh www-data www-data 33 33
```

Where it's: `USER_NAME(www-data) GROUP_NAME(www-data) NEW_UID(33) NEW_GID(33)`
