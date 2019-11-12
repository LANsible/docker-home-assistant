#!/bin/sh

# NOTE: Create everything in /dev/shm and run entrypoint script to symlink to config
# Needed for:
# https://github.com/OpenZWave/python-openzwave/blob/cdae95f601fef9a935903906eb02e1d9e4f702d1/src-lib/libopenzwave/libopenzwave.pyx#L703
# Home Assistant sets it to:
# https://github.com/home-assistant/home-assistant/blob/8ec75cf88371253c87ff2973856dbe31819c6134/homeassistant/components/zwave/__init__.py#L288

# Also hass makes /deps dir, HA_VERSION file and onboarding file

# Create aliases to busybox
alias basename="/bin/busybox basename"
alias ln="/bin/busybox ln"
alias mkdir="/bin/busybox mkdir"

# Create symlinks when config mounted, else exit
if [ ! -d "/data" ]; then
  echo "No /data found, please data volume to container"
  exit 1
fi

if [ -d "/config" ]; then
  # For each config file create a symlink
  for file in /config/*; do
    filename=$(basename "$file")
    # Create symlink when it does not exist yet
    if [ ! -L "/data/$filename" ]; then
      echo "Creating symlink from /config/$filename to /data/$filename"
      ln -sf "/config/$filename" "/data/$filename"
    fi
  done
else 
  # Print warning when no config was found, could be intentional
  echo "No /config found, no symlink will be created"
fi

# Start docker CMD
exec "$@"
