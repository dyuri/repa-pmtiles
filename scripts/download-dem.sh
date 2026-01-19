#!/bin/bash
set -e

# Script to download Digital Elevation Model (DEM) data for Hungary
# Usage: ./scripts/download-dem.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEM_DIR="$PROJECT_DIR/data/dem"

echo "======================================"
echo "Downloading DEM Data for Hungary"
echo "======================================"
echo ""

# Create DEM directory
mkdir -p "$DEM_DIR"
cd "$DEM_DIR"

echo "Downloading SRTM (Shuttle Radar Topography Mission) tiles..."
echo "Hungary is covered by tiles: N45-N49, E16-E23"
echo ""

# SRTM tiles covering Hungary (approximately)
# Format: SRTM_[hemisphere][latitude][hemisphere][longitude].hgt.zip
# We'll download from OpenTopography or CGIAR

# Using CGIAR SRTM v4.1 (90m resolution)
# Alternative source: https://srtm.csi.cgiar.org/wp-content/uploads/files/srtm_5x5/TIFF/

BASE_URL="https://srtm.csi.cgiar.org/wp-content/uploads/files/srtm_5x5/TIFF"

# Hungary coverage: approximately srtm_39_03 and srtm_40_03
# These 5x5 degree tiles cover the Hungarian region
TILES=(
    "srtm_39_03"
    "srtm_40_03"
)

echo "Downloading SRTM tiles (5x5 degree coverage)..."
echo "This may take 10-15 minutes (tiles are ~30-50MB each)"
echo ""

for tile in "${TILES[@]}"; do
    if [ -f "${tile}.tif" ]; then
        echo "✓ ${tile}.tif already exists, skipping..."
        continue
    fi

    echo "Downloading ${tile}.zip..."
    wget -c "${BASE_URL}/${tile}.zip" -O "${tile}.zip" || {
        echo "Warning: Failed to download ${tile}, trying alternative source..."
        # Alternative: OpenTopography API (requires free account)
        echo "Note: You may need to manually download SRTM data from:"
        echo "  - https://www.opentopodata.org/"
        echo "  - https://srtm.csi.cgiar.org/"
        continue
    }

    echo "Extracting ${tile}.tif..."
    unzip -o "${tile}.zip"
    rm "${tile}.zip"
done

echo ""
echo "Merging tiles into single Hungary DEM..."

# Check if we have any tif files
if ls *.tif 1> /dev/null 2>&1; then
    echo "Merging and clipping to Hungary bounds..."
    echo ""
    echo "Files in current directory:"
    ls -lh *.tif
    echo ""

    # Build list of input files
    INPUT_FILES=""
    for tif in *.tif; do
        if [ -f "$tif" ]; then
            INPUT_FILES="$INPUT_FILES /data/$tif"
        fi
    done

    if [ -z "$INPUT_FILES" ]; then
        echo "Error: No .tif files found to merge"
        exit 1
    fi

    echo "Container will see these paths:"
    echo "$INPUT_FILES"
    echo ""
    echo "Mounting $DEM_DIR as /data in container"
    echo ""

    # Hungary approximate bounds: [16.1, 45.7, 22.9, 48.6] (minlon, minlat, maxlon, maxlat)
    # We'll use podman with GDAL image to merge and clip

    podman run --rm \
        -v "$DEM_DIR:/data" \
        ghcr.io/osgeo/gdal:alpine-small-latest \
        sh -c "gdalwarp -te 16.0 45.5 23.0 48.7 \
        -tr 0.0008333333 0.0008333333 \
        -r cubic \
        -co COMPRESS=DEFLATE \
        -co TILED=YES \
        $INPUT_FILES /data/hungary-dem.tif"

    # Clean up individual tiles
    for tile in "${TILES[@]}"; do
        rm -f "${tile}.tif"
    done

    echo ""
    echo "======================================"
    echo "DEM Download Complete!"
    echo "======================================"
    echo ""
    echo "DEM file: $DEM_DIR/hungary-dem.tif"
    echo ""
    ls -lh "$DEM_DIR/hungary-dem.tif"
    echo ""
    echo "Next step: Run ./scripts/generate-contours.sh"
else
    echo ""
    echo "======================================"
    echo "Manual Download Required"
    echo "======================================"
    echo ""
    echo "Automatic download failed. Please manually download SRTM data:"
    echo ""
    echo "1. Go to: https://srtm.csi.cgiar.org/srtmdata/"
    echo "2. Download tiles covering Hungary (approximately 39_03 and 40_03)"
    echo "3. Extract .tif files to: $DEM_DIR/"
    echo "4. Run this script again to merge them"
    echo ""
    exit 1
fi
