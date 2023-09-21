#!/bin/bash

echo "Running As: $(whoami):$(id -gn)"

sudo -u root -- crond -f -d 0