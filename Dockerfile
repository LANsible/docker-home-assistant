# Inspired from https://github.com/seblucas/alpine-homeassistant
ARG ARCHITECTURE
FROM multiarch/alpine:${ARCHITECTURE}-v3.12 as builder

LABEL maintainer="Wilmar den Ouden" \
    description="Homeassistant alpine!"

ARG COMPONENTS="frontend|recorder|http|image|discovery|ssdp|mobile_app|cloud"
ARG OTHER

ENV VERSION="1.0.0b6"

RUN echo "hass:x:1000:1000:hass:/:" > /etc_passwd

# postgres-dev needed for npsycopg2
# zlib-dev needed for Pillow (needed for image)
# jpeg-dev needed for Pillow (needed for image)
RUN apk add --no-cache \
        git \
        python3-dev \
        py3-pip \
        libffi-dev \
        gcc \
        musl-dev \
        libressl-dev \
        make \
        postgresql-dev \
        jpeg-dev \
        zlib-dev

RUN mkdir -p /tmp/homeassistant

# Setup requirements files
# NOTE: add package_constraints in subfolder so the `-c homeassistant/package_constraints.txt` in requirements.txt works
ADD "https://raw.githubusercontent.com/home-assistant/core/${VERSION}/requirements_all.txt" /tmp
ADD "https://raw.githubusercontent.com/home-assistant/core/${VERSION}/requirements.txt" /tmp
ADD "https://raw.githubusercontent.com/home-assistant/core/${VERSION}/homeassistant/package_constraints.txt" /tmp/homeassistant

WORKDIR /tmp

# Strip requirements_all.txt to just what I need for my components
# Prefix all components with component to avoid matching packages containing a component name (yi for example)
# https://stackoverflow.com/a/6744040 < parameter expension does not work, not POSIX
# Match the components in the comment string and select until the newline
# https://stackoverflow.com/a/39729735 && https://stackoverflow.com/a/39384347
# When OTHER is specified grep those and add to requirements
# Finally add home-assistant and postgreslibs to requirements.
# Needed in file since pip install -r requirements.txt home-assistant simply ignores the -r option
RUN export COMPONENTS=$(echo components.${COMPONENTS} | sed --expression='s/|/|components./g') && \
    awk -v RS= '$0~ENVIRON["COMPONENTS"]' requirements_all.txt >> requirements_strip.txt && \
    if [ -n "${OTHER}" ]; then \
      awk -v RS= '$0~ENVIRON["OTHER"]' requirements_all.txt >> requirements_strip.txt; \
    fi; \
    if [ "${VERSION}" = "dev" ]; then \
      echo -e "https://github.com/home-assistant/core/archive/dev.zip\npsycopg2" >> requirements_strip.txt; \
    else \
      echo -e "homeassistant==${VERSION}\npsycopg2" >> requirements_strip.txt; \
    fi;

# Makeflags source: https://math-linux.com/linux/tip-of-the-day/article/speedup-gnu-make-build-and-compilation-process
# Install requirements and Home Assistant
RUN CORES=$(grep -c '^processor' /proc/cpuinfo); \
    export MAKEFLAGS="-j$((CORES+1)) -l${CORES}"; \
    pip3 install \
      --no-cache-dir \
      --user \
      --no-warn-script-location \
      -r requirements.txt \
      -r requirements_strip.txt


FROM multiarch/alpine:${ARCHITECTURE}-v3.12

# Needs seperate otherwise not expanded in next ENV
ENV HOME=/dev/shm

# Set PYTHONPATH where to modules will be copied to
ENV PYTHONPATH=/opt/python3.8/site-packages

# Copy the unprivileged user
COPY --from=builder /etc_passwd /etc/passwd

# Copy Python system modules
COPY --from=builder /usr/lib/python3.8/site-packages/ /usr/lib/python3.8/site-packages/

# Copy Python user modules
COPY --from=builder /root/.local/lib/python3.8/site-packages/ ${PYTHONPATH}

# Copy pip installed binaries
COPY --from=builder /root/.local/bin /usr/local/bin

# Copy needed libs from builder
# libz for image component
COPY --from=builder \
    /lib/libz.so \
    /lib/
# libsas12 need both .so.3
# libjpeg for image component
COPY --from=builder \
    /usr/lib/liblber-2.4.so.2 \
    /usr/lib/libldap_r-2.4.so.2 \
    /usr/lib/libpq.so.5 \
    /usr/lib/libsasl2.so.* \
    /usr/lib/libjpeg.so.8 \
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
