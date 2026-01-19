#!/bin/bash
set -e

# Script to build a local tippecanoe container image
# Usage: ./scripts/build-tippecanoe.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "======================================"
echo "Building Tippecanoe Container"
echo "======================================"
echo ""

# Create a temporary directory for the Dockerfile
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Create Dockerfile
cat > Dockerfile <<'EOF'
FROM alpine:latest

RUN apk add --no-cache \
    git \
    bash \
    build-base \
    sqlite-dev \
    zlib-dev

WORKDIR /build

RUN git clone https://github.com/felt/tippecanoe.git . && \
    make -j$(nproc) && \
    make install

WORKDIR /data

ENTRYPOINT ["tippecanoe"]
EOF

echo "Building container image..."
echo "This will take 5-10 minutes..."
echo ""

podman build -t localhost/tippecanoe:latest .

cd "$PROJECT_DIR"
rm -rf "$TEMP_DIR"

echo ""
echo "======================================"
echo "Tippecanoe Build Complete!"
echo "======================================"
echo ""
echo "Image: localhost/tippecanoe:latest"
echo ""
echo "You can now run generate-contours.sh"
