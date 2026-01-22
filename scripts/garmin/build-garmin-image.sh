#!/bin/bash
set -e

# Script to build the Garmin builder Docker image
# Usage: ./scripts/garmin/build-garmin-image.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
DOCKER_DIR="$PROJECT_DIR/docker/garmin"

echo "======================================"
echo "Building Garmin Builder Image"
echo "======================================"
echo ""

if [ ! -f "$DOCKER_DIR/Dockerfile" ]; then
    echo "Error: Dockerfile not found at $DOCKER_DIR/Dockerfile"
    exit 1
fi

echo "Building image: garmin-builder:latest"
echo "This will download mkgmap, splitter, and dependencies (~300MB)"
echo ""

cd "$DOCKER_DIR"
podman build -t garmin-builder:latest .

if [ $? -eq 0 ]; then
    echo ""
    echo "======================================"
    echo "✓ Image built successfully!"
    echo "======================================"
    echo ""
    echo "Image: garmin-builder:latest"
    echo ""
    echo "Test the image:"
    echo "  podman run --rm garmin-builder:latest mkgmap --version"
    echo "  podman run --rm garmin-builder:latest splitter --version"
    echo ""
    echo "Next step:"
    echo "  ./scripts/generate-garmin.sh"
    echo ""
else
    echo ""
    echo "✗ Error building image"
    exit 1
fi
