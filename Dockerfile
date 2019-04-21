# Inspired from https://github.com/seblucas/alpine-homeassistant
ARG ARCH=amd64
FROM multiarch/alpine:${ARCH}-v3.9 as builder

LABEL maintainer="Wilmar den Ouden" \
    description="Homeassistant alpine!"

ARG VERSION
ARG PLUGINS="frontend|sqlalchemy|aiohttp_cors"

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
        make

# Setup requirements files
ADD "https://raw.githubusercontent.com/home-assistant/home-assistant/${VERSION}/requirements_all.txt" /tmp
RUN sed '/^$/q' /tmp/requirements_all.txt > /tmp/requirements_core.txt && \
    sed '1,/^$/d' /tmp/requirements_all.txt > /requirements_plugins.txt && \
    egrep -e "${PLUGINS}" /requirements_plugins.txt | grep -v '#' > /tmp/requirements_plugins_filtered.txt

# Install requirements and Home Assistant
RUN pip3 install --upgrade --user --no-cache-dir pip && \
    pip3 install --no-cache-dir --user --no-warn-script-location -r /tmp/requirements_core.txt -r /tmp/requirements_plugins_filtered.txt && \
    pip3 install --no-cache-dir --user --no-warn-script-location homeassistant=="${VERSION}" psycopg2

# Tricks to allow readonly container
# Create deps directory so HA does not
# Create symlink to place where config should be mounted
RUN mkdir -p /home/hass/deps && \
    echo ${VERSION} >> /home/hass/.HA_VERSION && \
    mkdir /config && \
    ln -sf /config/configuration.yaml /home/hass/configuration.yaml

FROM multiarch/alpine:${ARCH}-v3.9

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
COPY --from=builder --chown=8123:8123 /root/.local/lib/python3.6/site-packages/ ${HOME}/.local/lib/python3.6/site-packages/

# Copy pip installed binaries
COPY --from=builder --chown=8123:8123 /root/.local/bin ${HOME}/.local/bin

# Copy config setup
COPY --from=builder --chown=8123:8123 /home/hass /home/hass

# Copy needed libs from builder
COPY --from=builder \
    /usr/lib/libssl.so.45 \
    /usr/lib/libcrypto.so.43 \
    /lib/

RUN apk add --no-cache \
    python3

USER hass
ENTRYPOINT ["hass"]
CMD ["--config=/home/hass/", "--log-file=/proc/self/fd/1", "--skip-pip"]