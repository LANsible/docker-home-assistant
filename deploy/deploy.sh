#!/bin/bash
echo "Deploying ${DOCKER_NAMESPACE}/${CONTAINER_NAME}:${HOMEASSISTANT_VERSION}-${ARCH}"
echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
docker push ${DOCKER_NAMESPACE}/${CONTAINER_NAME}

echo "Install manifest-tool"
wget https://github.com/estesp/manifest-tool/releases/download/v1.0.0-rc2/manifest-tool-linux-amd64 -O manifest-tool
chmod +x manifest-tool

echo "Deploying manifest for ${HOMEASSISTANT_VERSION}"
./manifest-tool push from-args \
    --platforms linux/amd64,linux/arm64,linux/386 \
    --template lansible/home-assistant:${HOMEASSISTANT_VERSION}-ARCH \
    --target lansible/home-assistant:${HOMEASSISTANT_VERSION}

echo "Deploying manifest for latest"
./manifest-tool push from-args \
    --platforms linux/amd64,linux/arm64,linux/386 \
    --template lansible/home-assistant:${HOMEASSISTANT_VERSION}-ARCH \
    --target lansible/home-assistant:latest
