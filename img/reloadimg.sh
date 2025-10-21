#!/bin/bash

# Renew Docker image in local k3d registry
# Usage: ./reloadimg.sh [image-name] [tag]
# This script builds, tags, and pushes image to k3d-local-img registry
# If image exists in registry, it removes the old one first

set -e

# Configuration
IMAGE_NAME=${1:-"aisecurity-mgmt-service"}
TAG=${2:-"local-dev"}
LOCAL_REGISTRY="k3d-local-img:5555"
REGISTRY_IMAGE="$LOCAL_REGISTRY/$IMAGE_NAME:$TAG"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_SCRIPT="$SCRIPT_DIR/buildimg.sh"

echo "🔄 Renewing AISecurity Profile API Docker image in k3d local registry..."
echo "📋 Configuration:"
echo "   - Image name: $IMAGE_NAME:$TAG"
echo "   - Registry: $LOCAL_REGISTRY"
echo "   - Registry image: $REGISTRY_IMAGE"
echo

# Check if build script exists
if [ ! -f "$BUILD_SCRIPT" ]; then
    echo "❌ Error: Build script not found: $BUILD_SCRIPT"
    exit 1
fi

# Check if docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Step 1: Build the image
echo "🔨 Step 1: Building Docker image..."
"$BUILD_SCRIPT" "$IMAGE_NAME" "$TAG"

# Step 2: Check if image exists in registry and remove if it does
echo
echo "🔍 Step 2: Checking for existing image in registry..."
if docker images | grep -q "$LOCAL_REGISTRY/$IMAGE_NAME.*$TAG"; then
    echo "🗑️  Removing existing image: $REGISTRY_IMAGE"
    docker rmi "$REGISTRY_IMAGE" 2>/dev/null || true
else
    echo "ℹ️  No existing image found in registry"
fi

# Step 3: Tag image for local registry
echo
echo "🏷️  Step 3: Tagging image for local registry..."
docker tag "$IMAGE_NAME:$TAG" "$REGISTRY_IMAGE"

# Step 4: Push to local registry
echo
echo "📤 Step 4: Pushing image to local registry..."
if docker push "$REGISTRY_IMAGE"; then
    echo "✅ Image successfully pushed to registry!"
else
    echo "❌ Failed to push image to registry"
    echo "💡 Make sure k3d local registry is running:"
    echo "   - Check registry: docker ps | grep k3d-local-img"
    echo "   - Setup cluster: ../../devtools/local-env/setup-k3d-cluster.sh"
    exit 1
fi

echo
echo "🎉 Image renewal completed successfully!"
echo "📊 Registry image: $REGISTRY_IMAGE"
echo
echo "🚀 Next steps:"
echo "   - Deploy to k3d: kubectl apply -f ../pkg/"
echo "   - Check registry: docker images | grep $LOCAL_REGISTRY"
echo "   - Remove local image: docker rmi $IMAGE_NAME:$TAG"