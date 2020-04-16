# Inspired from https://github.com/seblucas/alpine-homeassistant
ARG ARCHITECTURE
FROM multiarch/alpine:${ARCHITECTURE}-v3.11 as builder

LABEL maintainer="Wilmar den Ouden" \
    description="Homeassistant alpine!"

ARG COMPONENTS="frontend|recorder|http"
ARG OTHER

ENV VERSION="0.108.5"
# Run all make job simultaneously
ENV MAKEFLAGS=-j

RUN echo "hass:x:1000:1000:hass:/:" > /etc_passwd

RUN apk add --no-cache \
        git \
        python3-dev \
        libffi-dev \
        gcc \
        musl-dev \
        libressl-dev \
        make \
        postgresql-dev

# Setup requirements files
ADD "https://raw.githubusercontent.com/home-assistant/core/${VERSION}/requirements_all.txt" /tmp

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
    if [ "${VERSION}" = "dev" ]; then \
      echo -e "https://github.com/home-assistant/core/archive/dev.zip\npsycopg2" >> /tmp/requirements.txt; \
    else \
      echo -e "homeassistant==${VERSION}\npsycopg2" >> /tmp/requirements.txt; \
    fi;

# Install requirements and Home Assistant
RUN pip3 install \
      --no-cache-dir \
      --user \
      --no-warn-script-location \
      -r /tmp/requirements.txt

FROM multiarch/alpine:${ARCHITECTURE}-v3.11

# Needs seperate otherwise not expanded in next ENV
ENV HOME=/dev/shm

# Set PYTHONPATH where to modules will be copied to
ENV PYTHONPATH=/opt/python3.8/site-packages

# Copy the unprivileged user
COPY --from=builder /etc_passwd /etc/passwd

# Copy Python modules
COPY --from=builder /root/.local/lib/python3.8/site-packages/ ${PYTHONPATH}

# Copy pip installed binaries
COPY --from=builder /root/.local/bin /usr/local/bin

# Copy needed libs from builder
# libsas12 need both .so.3
COPY --from=builder \
    /usr/lib/liblber-2.4.so.2 \
    /usr/lib/libldap_r-2.4.so.2 \
    /usr/lib/libpq.so.5 \
    /usr/lib/libsasl2.so.* \
    /usr/lib/

# Add python3
RUN apk add --no-cache \
    python3

# Adds entrypoint
COPY ./entrypoint.sh /entrypoint.sh

USER hass
ENTRYPOINT ["/bin/busybox", "ash", "/entrypoint.sh" ]
CMD ["hass", "--config=/data", "--log-file=/proc/self/fd/1", "--skip-pip", "--runner"]
EXPOSE 8123
