#!/bin/bash

# Build Docker image for AISecurity Profile API
# Usage: ./buildimg.sh [image-name] [tag]

set -e

# Configuration
IMAGE_NAME=${1:-"aisecurity-mgmt-service"}
TAG=${2:-"local-dev"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"  # Go up to AISecurityService/src level
DOCKERFILE_PATH="$SCRIPT_DIR/../pkg/Dockerfile"
BUILD_CONTEXT="$PROJECT_ROOT"

echo "🐳 Building Docker image for AISecurity Profile API..."
echo "📋 Configuration:"
echo "   - Image name: $IMAGE_NAME:$TAG"
echo "   - Dockerfile: $DOCKERFILE_PATH"
echo "   - Build context: $BUILD_CONTEXT"
echo

# Check if Dockerfile exists
if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "❌ Error: Dockerfile not found: $DOCKERFILE_PATH"
    exit 1
fi

# Create requirements.txt in local_env using the correct version
LOCAL_REQUIREMENTS="$SCRIPT_DIR/../pkg/requirements.txt"
CORRECT_REQUIREMENTS="$PROJECT_ROOT/../deployments/DockerImage/aisecurity-mgmt-service/requirements.txt"

if [ -f "$CORRECT_REQUIREMENTS" ]; then
    echo "📝 Copying correct requirements.txt from deployments/DockerImage/aisecurity-mgmt-service..."
    cp "$CORRECT_REQUIREMENTS" "$LOCAL_REQUIREMENTS"
    # Strip corporate Artifactory index URL for local build (use public PyPI instead)
    # ENG-906473 changed requirements.txt to use uv pip compile --emit-index-url which
    # embeds the internal Artifactory URL - unreachable from local Docker build
    sed -i '' '/^--index-url/d' "$LOCAL_REQUIREMENTS"
    echo "✅ requirements.txt copied to local_env/pkg"
else
    echo "⚠️  Correct requirements.txt not found at: $CORRECT_REQUIREMENTS"
    echo "📝 Creating fallback requirements.txt in local_env/pkg for build..."
    cat > "$LOCAL_REQUIREMENTS" << 'EOF'
# Profile Management API Dependencies
fastapi==0.115.12
uvicorn[standard]==0.33.0
pydantic==2.10.6
pydantic_settings==2.9.1
pymongo==4.10.1
urllib3<2.0
grpcio
httpx>=0.24.0
pytest==8.3.5
pytest-asyncio==1.0.0
pytest-cov
EOF
    echo "✅ Fallback requirements.txt created in local_env/pkg"
fi
CLEANUP_REQUIREMENTS=false

# Check if build context is valid (should contain aisecurity-profile-api directory)
if [ ! -d "$BUILD_CONTEXT/aisecurity-profile-api" ]; then
    echo "❌ Error: aisecurity-profile-api directory not found in build context"
    echo "   Build context: $BUILD_CONTEXT"
    echo "   Expected: $BUILD_CONTEXT/aisecurity-profile-api"
    exit 1
fi

# Check if static directory exists in local area, create if needed
LOCAL_STATIC="$SCRIPT_DIR/../pkg/static"
if [ ! -d "$LOCAL_STATIC" ]; then
    echo "📁 Creating static directory in local_env/pkg..."
    mkdir -p "$LOCAL_STATIC"
fi

# No symlinks or modifications outside local_env needed

# Build the Docker image with local development settings
echo "🔨 Building Docker image for local development..."
echo "   - Using public PyPI (python:3.10-slim base image)"
echo "   - nsmongo will be skipped (automatic fallback to GeneralDbAdapter)"
docker build \
    -f "$DOCKERFILE_PATH" \
    -t "$IMAGE_NAME:$TAG" \
    --build-arg BASE_IMAGE=python:3.10-slim \
    "$BUILD_CONTEXT"

# No cleanup needed as we only create files in local_env

echo
echo "✅ Docker image built successfully!"
echo "🏷️  Image: $IMAGE_NAME:$TAG"
echo
echo "🚀 Next steps:"
echo "   - Run locally: docker run -p 8000:8000 $IMAGE_NAME:$TAG"
echo "   - Tag for registry: docker tag $IMAGE_NAME:$TAG k3d-local-img:5555/$IMAGE_NAME:$TAG"
echo "   - Push to local registry: docker push k3d-local-img:5555/$IMAGE_NAME:$TAG"
echo "   - Deploy to k3d: kubectl apply -f ../pkg/"