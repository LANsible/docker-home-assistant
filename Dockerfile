# Inspired from https://github.com/seblucas/alpine-homeassistant
FROM alpine:3.10 as builder

LABEL maintainer="Wilmar den Ouden" \
    description="Homeassistant alpine!"

ARG VERSION="master"
ARG COMPONENTS="frontend|recorder|http"
ARG OTHER

# Run all make job simultaneously
ENV MAKEFLAGS=-j

RUN addgroup -S -g 8123 hass 2>/dev/null && \
    adduser -S -u 8123 -D -H -h /dev/shm -s /sbin/nologin -G hass -g hass hass 2>/dev/null && \
    addgroup hass dialout

RUN apk add --no-cache \
        git \
        python3-dev \
        libffi-dev \
        gcc \
        musl-dev \
        libressl-dev \
        make \
        postgresql-dev \
        g++ \
        openzwave-dev

# Setup requirements files
ADD "https://raw.githubusercontent.com/home-assistant/home-assistant/${VERSION}/requirements_all.txt" /tmp
# First filter core requirements from a file by selecting comment header until empty line
# Prefix all components with component to avoid matching packages containing a component name (yi for example)
# https://stackoverflow.com/a/6744040 < parameter expension does not work, not POSIX
# Match the components in the comment string and select until the newline
# https://stackoverflow.com/a/39729735 && https://stackoverflow.com/a/39384347
# When OTHER is specified grep those and add to requirements
# Finally add home-assistant and postgreslibs to requirements.
# Needed in file since pip install -r /tmp/requirements.txt home-assistant simply ignores the -r option
RUN awk -v RS= '/# Home Assistant core/' /tmp/requirements_all.txt > /tmp/requirements.txt && \
    export COMPONENTS=$(echo components.${COMPONENTS} | sed --expression='s/|/|components./g') && \
    awk -v RS= '$0~ENVIRON["COMPONENTS"]' /tmp/requirements_all.txt >> /tmp/requirements.txt && \
    if [ -n "${OTHER}" ]; then \
      awk -v RS= '$0~ENVIRON["OTHER"]' /tmp/requirements_all.txt >> /tmp/requirements.txt; \
    fi; \
    if [ "${VERSION}" == "master" ]; then \
      echo -e "https://github.com/home-assistant/home-assistant/archive/master.zip\npsycopg2" >> /tmp/requirements.txt; \
    else \
      echo -e "homeassistant==${VERSION}\npsycopg2" >> /tmp/requirements.txt; \
    fi;

# Install requirements and Home Assistant
RUN pip3 install --upgrade --user --no-cache-dir pip && \
    pip3 install \
      --no-cache-dir \
      --user \
      --no-warn-script-location \
      -r /tmp/requirements.txt

# FROM multiarch/alpine:${ARCH}-v3.9
FROM alpine:3.10

# Needs seperate otherwise not expanded in next ENV
ENV HOME=/dev/shm
# Adds user owned .local/bin to PATH
ENV PYTHONPATH=/opt/python3.7/site-packages

# Copy users from builder
COPY --from=builder \
    /etc/passwd \
    /etc/group \
    /etc/

# Copy Python modules
COPY --from=builder --chown=8123:8123 \
    /root/.local/lib/python3.7/site-packages/ ${PYTHONPATH}

# Copy pip installed binaries
COPY --from=builder --chown=8123:8123 /root/.local/bin /usr/local/bin

# Copy needed libs from builder
COPY --from=builder \
    /usr/lib/libcrypto.so.43 \
    /usr/lib/liblber-2.4.so.2 \
    /usr/lib/libldap_r-2.4.so.2 \
    /usr/lib/libpq.so.5 \
    /usr/lib/libsasl2.so.3 \
    /usr/lib/libssl.so.45 \
    /usr/lib/libudev.so.1 \
    "/usr/lib/libstdc++.so.6" \
    /usr/lib/libgcc_s.so.1 \
    /lib/

# Add python3
RUN apk add --no-cache \
    python3

# Adds entrypoint
COPY ./entrypoint.sh /entrypoint.sh

USER hass
ENTRYPOINT ["/entrypoint.sh"]
CMD ["hass", "--config=/dev/shm", "--log-file=/proc/self/fd/1", "--skip-pip"]
