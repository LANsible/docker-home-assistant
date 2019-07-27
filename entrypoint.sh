#!/bin/sh

# Skip when no config mounted, just run with defaults
if [ -d "/config" ]; then
    for file in /config; do
        ln -sf /dev/shm/$file /config/$file 
    done
fi

# Start home assistant
exec "$@"