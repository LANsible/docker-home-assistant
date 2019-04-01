#!/bin/bash
echo "Deploying ${DOCKER_NAMESPACE}/${CONTAINER_NAME}:${HOMEASSISTANT_VERSION}-${ARCH}"
echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
docker push ${DOCKER_NAMESPACE}/${CONTAINER_NAME}

echo "Install manifest-tool"
wget https://github.com/estesp/manifest-tool/releases/download/v1.0.0-rc2/manifest-tool-linux-amd64 -O manifest-tool
chmod +x manifest-tool

echo "Deploying manifest"
./manifest-tool push from-spec manifests/manifest-${HOMEASSISTANT_VERSION}.yml