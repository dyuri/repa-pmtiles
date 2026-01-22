#!/bin/bash
set -e

# Script to install Garmin map to a connected device
# Usage: ./scripts/garmin/install-to-device.sh [device-path]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
GMAPSUPP="$PROJECT_DIR/garmin-output/gmapsupp.img"

echo "======================================"
echo "Garmin Map Installation Helper"
echo "======================================"
echo ""

# Check if gmapsupp.img exists
if [ ! -f "$GMAPSUPP" ]; then
    echo "✗ Error: gmapsupp.img not found!"
    echo ""
    echo "Please run ./scripts/generate-garmin.sh first"
    exit 1
fi

echo "Map file found: $GMAPSUPP"
echo "Size: $(ls -lh "$GMAPSUPP" | awk '{print $5}')"
echo ""

# If device path provided as argument, use it
if [ -n "$1" ]; then
    GARMIN_PATH="$1"
    echo "Using provided path: $GARMIN_PATH"
else
    # Try to detect mounted Garmin device
    echo "Detecting Garmin device..."
    GARMIN_PATH=$(mount | grep -i garmin | awk '{print $3}' | head -n1)

    if [ -z "$GARMIN_PATH" ]; then
        echo "✗ No Garmin device detected automatically"
        echo ""
        echo "Manual installation:"
        echo "  1. Connect your Garmin device to computer"
        echo "  2. Locate the device mount point (e.g., /media/GARMIN)"
        echo "  3. Copy the file:"
        echo "     cp \"$GMAPSUPP\" /path/to/device/Garmin/gmapsupp.img"
        echo ""
        echo "Or run with explicit path:"
        echo "  $0 /path/to/device"
        echo ""
        exit 1
    fi

    echo "✓ Found device at: $GARMIN_PATH"
fi

# Verify device path exists
if [ ! -d "$GARMIN_PATH" ]; then
    echo "✗ Error: Path does not exist: $GARMIN_PATH"
    exit 1
fi

# Check for Garmin directory
GARMIN_DIR="$GARMIN_PATH/Garmin"
if [ ! -d "$GARMIN_DIR" ]; then
    echo "Creating Garmin directory..."
    mkdir -p "$GARMIN_DIR"
fi

# Check if gmapsupp.img already exists
DEST_FILE="$GARMIN_DIR/gmapsupp.img"
if [ -f "$DEST_FILE" ]; then
    echo ""
    echo "⚠ Warning: gmapsupp.img already exists on device"
    echo "Existing file: $(ls -lh "$DEST_FILE" | awk '{print $5}')"
    echo ""
    read -p "Overwrite existing map? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi

    # Backup existing map
    BACKUP="$GARMIN_DIR/gmapsupp.img.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Creating backup: $(basename "$BACKUP")"
    cp "$DEST_FILE" "$BACKUP"
fi

echo ""
echo "Installing map to device..."
cp "$GMAPSUPP" "$DEST_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "======================================"
    echo "✓ Installation complete!"
    echo "======================================"
    echo ""
    echo "Installed to: $DEST_FILE"
    echo ""
    echo "Next steps:"
    echo "  1. Safely eject your Garmin device"
    echo "  2. The new map will appear in the device's map list"
    echo "  3. Enable it in: Setup > Map > Map Info"
    echo ""
else
    echo ""
    echo "✗ Error copying file to device"
    exit 1
fi
