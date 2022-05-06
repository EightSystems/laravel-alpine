# Supervisord Implementation

In order to decrease the image size, we use a Golang port of Supervisord [ochinchina/supervisord](https://github.com/ochinchina/supervisord).
This port works just fine with our needed settings as it implements most (if not all) of Supervisord settings available.

But, in the spirit of keeping you aware of what this image contains, keep in mind in case some setting you are trying to use in your custom supervisor config don't work.

## SupervisorCTL

We added a supervisorctl wrapper to `/usr/local/bin/supervisorctl`, if you call this, it will call `supervisord ctl` under the hood, so it will be "retro-compatible"
