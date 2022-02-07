# Home Assistant / HASS in Docker!

[![Build Status](https://gitlab.com/lansible1/docker-home-assistant/badges/master/pipeline.svg)](https://gitlab.com/lansible1/docker-home-assistant/pipelines)
[![Docker Pulls](https://img.shields.io/docker/pulls/lansible/home-assistant.svg)](https://hub.docker.com/r/lansible/home-assistant)
[![Docker Version](https://img.shields.io/docker/v/lansible/home-assistant?sort=date)](https://hub.docker.com/r/lansible/home-assistant)
[![Docker Image Size](https://img.shields.io/docker/image-size/lansible/home-assistant?sort=date)](https://hub.docker.com/r/lansible/home-assistant)

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
      --build-arg COMPONENTS="frontend|mqtt"
      --build-arg OTHER="auth.mfa_modules.totp"
      --tag lansible/home-assistant:0.90.2
```
The arguments are:

| Build argument | Description                                    | Example                   |
|----------------|------------------------------------------------|---------------------------|
| `COMPONENTS`   | List of components to install plugins for      | `"frontend|mqtt"`         |
| `OTHER`        | List of other (not component) parts to install | `"auth.mfa_modules.totp"` |

## Credits

* [home-assistant/home-assistant](https://github.com/home-assistant/home-assistant)
