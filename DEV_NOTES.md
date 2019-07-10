## Debugging awk

### Bootstrapping env
```
docker run -it alpine
export COMPONENTS='frontend|recorder|http|discovery|mqtt|zwave|buienradar|denonavr|plex'; export OTHER='auth.mfa_modules.totp'; wget https://raw.githubusercontent.com/home-assistant/home-assistant/master/requirements_all.txt; mv requirements_all.txt /tmp
```

### Split core

```
awk -v RS= '/# Home Assistant core/' /tmp/requirements_all.txt > /tmp/requirements.txt && \
cat /tmp/requirements.txt
```

### Components

```
echo $COMPONENTS && \
export COMPONENTS=$(echo components.${COMPONENTS} | sed --expression='s/|/|components./g') && \
echo $COMPONENTS
```

```
awk -v RS= '$0~ENVIRON["COMPONENTS"]' /tmp/requirements_all.txt >> /tmp/requirements.txt && \
cat /tmp/requirements.txt
```

### Other

```
echo $OTHER; \
if [ -n "${OTHER}" ]; then \
  awk -v RS= '$0~ENVIRON["OTHER"]' /tmp/requirements_all.txt >> /tmp/requirements.txt; \
fi; && \
cat /tmp/requirements.txt
```