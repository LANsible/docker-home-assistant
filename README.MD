# Home Assistant / HASS in Docker!

## Why not use the official container?

It does not work on Kubernetes with a configmap since it tries to create the deps folder where the config is mounted.
This container allows this setup to work flawlessly!

## Test container with docker-compose

```
cd examples/compose
docker-compose up
```

## Expand the container with your own plugins

This container only includes plugins which I use ;)

### Forking the repository

You can easily add plugins to the container by forking the repository and running your own build.

* Change are the `DOCKER_NAMESPACE` and `PLUGINS` variables in the .travis.yml file.
* Enable the repository on travis.org
* Add `DOCKER_USERNAME` and `DOCKER_PASSWORD` to the environment variables on travis.org

### Building the container locally

You could build the container locally to add plugins. It works like this:

```bash
docker build . \
      --build-arg ARCH=amd64 \
      --build-arg VERSION=0.90.2 \
      --build-arg PLUGINS="frontend|sqlalchemy|buienradar|dsmr_reader" \
      --tag lansible/home-assistant:0.90.2
```
The arguments are:

| Build argument | Description                                    | Example                 |
|----------------|------------------------------------------------|-------------------------|
| `ARCH`         | Architecture to build (amd64, arm64, i386)     | `amd64`                 |
| `VERSION`      | Version of Home Assistant                      | `0.90.2`                |
| `PLUGINS`      | List of pip plugins separated by a pipe symbol | `"frontend|sqlalchemy"` |

To speed up the build the builder part of the Dockerfile is available to use the cache from:

```bash
docker build . \
      --build-arg ARCH=amd64
      --build-arg VERSION=0.90.2
      --build-arg PLUGINS="buienradar|dsmr_reader"
      --cache-from lansibledump/homeassistant:0.90.2-amd64-builder
      --tag lansibledump/homeassistant:0.90.2
```