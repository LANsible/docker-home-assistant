# Home Assistant / HASS in Docker!

# Why not use the official container?

It does not work on Kubernetes with a configmap since it tries to create the deps folder where the config is mounted.
This container allows this setup to work flawlessly!

# Local test

```
docker run -v /home/wilmardo/Development/docker-homeassistant/test/:/config -it hass
``` 