# Home Assistant / HASS in Docker!

[![Build Status](https://github.com/LANsible/docker-home-assistant/actions/workflows/docker.yml/badge.svg)](https://github.com/LANsible/docker-home-assistant/actions/workflows/docker.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/lansible/home-assistant.svg)](https://hub.docker.com/r/lansible/home-assistant)
[![Docker Version](https://img.shields.io/docker/v/lansible/home-assistant.svg?sort=semver)](https://hub.docker.com/r/lansible/home-assistant)
[![Docker Size/Layers](https://img.shields.io/docker/image-size/lansible/home-assistant.svg?sort=semver)](https://hub.docker.com/r/lansible/home-assistant)

## Why not use the official container?

It does not work on Kubernetes with a configmap since it tries to create the deps folder where the config is mounted.
This container allows this setup to work flawlessly!

## Test container with docker-compose

```
cd examples/compose
docker-compose up
```

### Building the container locally

You could build the container locally to add plugins. It works like this:

```bash
docker build . \
      --build-arg COMPONENTS="mqtt"
      --build-arg OTHER="auth.mfa_modules.totp"
      --tag lansible/home-assistant:0.90.2
```
The arguments are:

| Build argument | Description                                    | Example                   |
|----------------|------------------------------------------------|---------------------------|
| `COMPONENTS`   | List of extra components to install plugins for      | `"mqtt"`         |

## Credits

* [home-assistant/home-assistant](https://github.com/home-assistant/home-assistant)
