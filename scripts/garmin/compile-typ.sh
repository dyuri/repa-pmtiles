#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="$PROJECT_DIR/config/garmin"

echo "======================================"
echo "Compiling TYP File"
echo "======================================"
echo ""

# Check if TYP text file exists
if [ ! -f "$CONFIG_DIR/hiking.txt" ]; then
    echo "Error: hiking.txt not found in $CONFIG_DIR"
    exit 1
fi

echo "Input:  $CONFIG_DIR/hiking.txt"
echo "Output: $CONFIG_DIR/hiking.typ"
echo ""

# Compile TYP file using mkgmap (it has built-in TYP compiler)
podman run --rm \
  -v "$CONFIG_DIR:/config" \
  garmin-builder:latest \
  mkgmap \
    --family-id=7777 \
    --product-id=1 \
    --output-dir=/config \
    /config/hiking.txt

# Check if compilation succeeded
if [ -f "$CONFIG_DIR/hiking.typ" ]; then
    echo ""
    echo "✓ TYP file compiled successfully!"
    echo ""
    ls -lh "$CONFIG_DIR/hiking.typ"
else
    echo ""
    echo "✗ Error: TYP file was not created"
    exit 1
fi
