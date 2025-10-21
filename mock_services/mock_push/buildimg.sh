#!/bin/bash

# Build and push Mock Push Service Docker image to k3d local registry
# Usage: ./buildimg.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="mock-push"
IMAGE_TAG="latest"
REGISTRY="k3d-local-img:5555"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "🔨 Building Mock Push Service Docker image..."
echo "📦 Image: ${FULL_IMAGE}"
echo

# Build the Docker image
cd "$SCRIPT_DIR"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

# Tag the image for the local registry
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${FULL_IMAGE}"

# Push to k3d local registry
echo "📤 Pushing image to k3d local registry..."
docker push "${FULL_IMAGE}"

echo "✅ Mock Push Service image built and pushed successfully!"
echo "   Image: ${FULL_IMAGE}"
