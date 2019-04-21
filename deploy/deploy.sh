#!/bin/bash
echo "Deploying ${DOCKER_NAMESPACE}/${CONTAINER_NAME}:${VERSION}-${ARCH}"
echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
docker push ${DOCKER_NAMESPACE}/${CONTAINER_NAME}

echo "Install manifest-tool"
wget https://github.com/estesp/manifest-tool/releases/download/v1.0.0-rc2/manifest-tool-linux-amd64 -O manifest-tool
chmod +x manifest-tool

echo "Deploying manifest for ${VERSION}"
./manifest-tool push from-args \
    --ignore-missing \
    --platforms linux/amd64,linux/arm64,linux/386 \
    --template ${DOCKER_NAMESPACE}/${CONTAINER_NAME}:${VERSION}-ARCH \
    --target ${DOCKER_NAMESPACE}/${CONTAINER_NAME}:${VERSION}

echo "Deploying manifest for latest"
./manifest-tool push from-args \
    --ignore-missing \
    --platforms linux/amd64,linux/arm64,linux/386 \
    --template ${DOCKER_NAMESPACE}/${CONTAINER_NAME}:${VERSION}-ARCH \
    --target ${DOCKER_NAMESPACE}/${CONTAINER_NAME}:latest
