ARG IMAGE=python:3.13-alpine

FROM $IMAGE AS builder
SHELL ["/bin/ash", "-o", "pipefail", "-c"]

ARG COMPONENTS
ARG OTHER

ENV \
  # https://github.com/home-assistant/core/releases
  VERSION="2025.7.2" \
  # https://www.home-assistant.io/integrations/default_config/
  # REMOVED: dhcp, bluetooth, zeroconf (makes no sense without hostnetwork/usb)
  # ADDED: tts, ffmpeg
  MINIMAL_COMPONENTS="generic|frontend|assist_pipeline|backup|config|conversation|energy|go2rtc|history|homeassistant_alerts|cloud|image_upload|logbook|media_source|mobile_app|my|ssdp|stream|sun|usb|webhook|isal|otp|tts|ffmpeg" \
  UV_EXTRA_INDEX_URL="https://wheels.home-assistant.io/musllinux-index/"

RUN echo "hass:x:1000:1000:hass:/:" > /etc_passwd

# postgres-dev needed for npsycopg2
# zlib-dev needed for Pillow (generic)
# jpeg-dev needed for Pillow (generic)
# ffmpeg4 required for av (generic)
# openblas-dev requirement for numpy https://github.com/numpy/numpy/issues/24703
# libjpeg-turbo is required for stream
RUN --mount=type=cache,target=/etc/apk/cache \
  apk add \
    g++ \
    autoconf \
    make \
    libffi-dev \
    postgresql-dev \
    jpeg-dev \
    libturbojpeg \
    zlib-dev \
    openblas-dev \
    ffmpeg-dev \
    libjpeg-turbo

# Setup requirements files
# NOTE: add package_constraints in subfolder so the `-c homeassistant/package_constraints.txt` in requirements.txt works
# NOTE: setup the pip.conf from the hass base image so musl compiled wheels are available
WORKDIR /tmp
RUN mkdir -p /tmp/homeassistant && \
    wget -q "https://raw.githubusercontent.com/home-assistant/core/${VERSION}/requirements_all.txt" && \
    wget -q "https://raw.githubusercontent.com/home-assistant/core/${VERSION}/requirements.txt" && \
    wget -qP homeassistant "https://raw.githubusercontent.com/home-assistant/core/${VERSION}/homeassistant/package_constraints.txt" && \
    wget -qP /etc/ "https://raw.githubusercontent.com/home-assistant/docker-base/master/alpine/rootfs/etc/pip.conf"

# Strip requirements_all.txt to just what I need for my components
# Prefix all components with components. and match till newline to avoid matching packages containing a component name (yi for example)
# and matching components starting with the same stream vs. streamlabs for example (match till newline): https://unix.stackexchange.com/a/484307
# Match the components in the comment string and select until the newline
# https://stackoverflow.com/a/39729735 && https://stackoverflow.com/a/39384347
# Finally add home-assistant and postgreslibs to requirements.
# Needed in file since pip install -r requirements.txt home-assistant simply ignores the -r option
RUN export MINIMAL_COMPONENTS=$(echo ${MINIMAL_COMPONENTS} | awk -F '|' -v OFS='|' -vpre="components." -vsuf='\\n' '{ for (i=1;i<=NF;++i) $i = pre $i suf; print }') && \
    awk -v RS= '$0~ENVIRON["MINIMAL_COMPONENTS"]' requirements_all.txt >> requirements_strip.txt && \
    if [ -n "${COMPONENTS}" ]; then \
      export COMPONENTS=$(echo components.${COMPONENTS} | sed --expression='s/|/|components./g') && \
      awk -v RS= '$0~ENVIRON["COMPONENTS"]' requirements_all.txt >> requirements_strip.txt; \
    fi; \
    if [ "${VERSION}" = "dev" ]; then \
      echo -e "https://github.com/home-assistant/core/archive/dev.zip\npsycopg2" >> requirements_strip.txt; \
    else \
      echo -e "homeassistant==${VERSION}\npsycopg2" >> requirements_strip.txt; \
    fi;

# Makeflags source: https://math-linux.com/linux/tip-of-the-day/article/speedup-gnu-make-build-and-compilation-process
# https://github.com/rhasspy/webrtc-noise-gain/issues/9
# Install requirements and Home Assistant
RUN --mount=type=cache,target=/root/.cache \
    CORES=$(grep -c '^processor' /proc/cpuinfo); \
    export MAKEFLAGS="-j$((CORES+1)) -l${CORES}"; \
    pip3 install --root-user-action=ignore uv && \
    uv venv && \
    # link mode is needed since cache is on tmpdir
    uv pip install \
      --link-mode=copy \
      -r requirements.txt \
      -r requirements_strip.txt && \
    # update shebang to global python
    sed -i '1 s|^.*$|#!/usr/local/bin/python3|' /tmp/.venv/bin/hass

#######################################################################################################################
# Final image
#######################################################################################################################
FROM $IMAGE
LABEL org.label-schema.description="Minimal Home Assistant on Alpine"
SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# Set PYTHONPATH where to modules will be copied to
ENV HOME=/dev/shm \
  TMPDIR=/dev/shm

# Copy the unprivileged user
COPY --from=builder /etc_passwd /etc/passwd

# Copy Python user modules
COPY --link --from=builder /tmp/.venv/lib/python3.13/site-packages/ /usr/local/lib/python3.13/site-packages

# Add home-assistant binary
COPY --link --from=builder /tmp/.venv/bin/hass /usr/local/bin/hass

RUN --mount=type=cache,target=/etc/apk/cache \
  apk add \
    libffi \
    # postgres
    libpq \
    # openblas/libgfortran requirement for numpy https://github.com/numpy/numpy/issues/24703
    openblas-dev \
    libgfortran \
    # stream components
    ffmpeg \
    libjpeg-turbo-dev \
    libgcc \
    libstdc++ \
    alsa-lib \
    sdl2

# go2rtc binary check below for version:
# https://github.com/home-assistant/core/blob/dev/Dockerfile#L28C69-L28C74
COPY --link --from=ghcr.io/alexxit/go2rtc:1.9.9 /usr/local/bin/go2rtc /usr/local/bin/go2rtc

# Adds entrypoint
COPY ./entrypoint.sh /entrypoint.sh

USER hass
ENTRYPOINT ["/bin/busybox", "ash", "/entrypoint.sh" ]
CMD ["hass", "--config=/data", "--log-file=/proc/self/fd/1", "--log-no-color", "--skip-pip"]
EXPOSE 8123
