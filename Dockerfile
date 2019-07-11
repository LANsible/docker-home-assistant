# Inspired from https://github.com/seblucas/alpine-homeassistant
# ARG ARCH=amd64
# FROM multiarch/alpine:${ARCH}-v3.9 as builder
FROM alpine:3.10

LABEL maintainer="Wilmar den Ouden" \
    description="Homeassistant alpine!"

ARG VERSION="0.91.4"
ARG COMPONENTS="frontend|recorder|http"
ARG OTHER

# Run all make job simultaneously
ENV MAKEFLAGS=-j

RUN addgroup -S -g 8123 hass 2>/dev/null && \
    adduser -S -u 8123 -D -H -h /home/hass -s /sbin/nologin -G hass -g hass hass 2>/dev/null

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
    echo -e "homeassistant==${VERSION}\npsycopg2" >> /tmp/requirements.txt

# Install requirements and Home Assistant
RUN pip3 install --upgrade --user --no-cache-dir pip && \
    pip3 install \
      --no-cache-dir \
      --user \
      --no-warn-script-location \
      -r /tmp/requirements.txt

# Tricks to allow readonly container
# Create deps directory so HA does not
# Create symlink to place where config should be mounted
RUN mkdir -p /home/hass/deps && \
    echo ${VERSION} >> /home/hass/.HA_VERSION && \
    mkdir /config && \
    ln -sf /config/configuration.yaml /home/hass/configuration.yaml && \
    ln -sf /dev/shm /home/hass/.storage

# FROM multiarch/alpine:${ARCH}-v3.9
FROM alpine:3.10

# Needs seperate otherwise not expanded in next ENV
ENV HOME=/home/hass
# Adds user owned .local/bin to PATH
ENV PATH=${HOME}/.local/bin:$PATH

# Copy users from builder
COPY --from=builder \
    /etc/passwd \
    /etc/group \
    /etc/

# Copy Python modules
COPY --from=builder --chown=8123:8123 \
    /root/.local/lib/python3.6/site-packages/ ${HOME}/.local/lib/python3.6/site-packages/

# Copy pip installed binaries
COPY --from=builder --chown=8123:8123 /root/.local/bin ${HOME}/.local/bin

# Copy config setup
COPY --from=builder --chown=8123:8123 /home/hass /home/hass

# Copy needed libs from builder
COPY --from=builder \
    /usr/lib/libssl.so.45 \
    /usr/lib/libcrypto.so.43 \
    /usr/lib/libpq.so.5 \
    /usr/lib/libldap_r-2.4.so.2 \
    /usr/lib/liblber-2.4.so.2 \
    /usr/lib/libsasl2.so.3 \
    /usr/lib/libudev.so.1 \
    /lib/

RUN apk add --no-cache \
    python3

USER hass
ENTRYPOINT ["hass"]
CMD ["--config=/home/hass/", "--log-file=/proc/self/fd/1", "--skip-pip"]
