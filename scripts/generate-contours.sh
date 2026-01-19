#!/bin/bash
set -e

# Script to generate contour lines from DEM data
# Usage: ./scripts/generate-contours.sh [interval]
# Example: ./scripts/generate-contours.sh 20  (20 meter contours)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEM_DIR="$PROJECT_DIR/data/dem"
DATA_DIR="$PROJECT_DIR/data"
TILES_DIR="$PROJECT_DIR/tiles"

# Contour interval in meters (default 20m)
INTERVAL="${1:-20}"

echo "======================================"
echo "Generating Contour Lines"
echo "======================================"
echo ""

# Check if DEM exists
if [ ! -f "$DEM_DIR/hungary-dem.tif" ]; then
    echo "Error: hungary-dem.tif not found!"
    echo "Please run ./scripts/download-dem.sh first"
    exit 1
fi

echo "Contour interval: ${INTERVAL}m"
echo "Input DEM: $DEM_DIR/hungary-dem.tif"
echo ""

mkdir -p "$DATA_DIR"

echo "Step 1: Generating contour lines from DEM..."
echo "This may take 5-15 minutes depending on your system"
echo ""

# Generate contours using GDAL in Docker
podman run --rm \
    -v "$DEM_DIR:/dem" \
    -v "$DATA_DIR:/output" \
    ghcr.io/osgeo/gdal:alpine-small-latest \
    gdal_contour -a elevation -i $INTERVAL \
    -f GeoJSON \
    /dem/hungary-dem.tif /output/hungary-contours.geojson

echo ""
echo "Step 2: Simplifying contours (reducing file size)..."
echo ""

# Simplify contours to reduce size while keeping important detail
# Using ogr2ogr with simplification
podman run --rm \
    -v "$DATA_DIR:/data" \
    ghcr.io/osgeo/gdal:alpine-small-latest \
    ogr2ogr -f GeoJSON \
    -simplify 0.0001 \
    /data/hungary-contours-simplified.geojson \
    /data/hungary-contours.geojson

# Use the simplified version
mv "$DATA_DIR/hungary-contours-simplified.geojson" "$DATA_DIR/hungary-contours.geojson"

echo ""
echo "Step 3: Converting to PMTiles format..."
echo ""

# Check file size
echo "GeoJSON size:"
ls -lh "$DATA_DIR/hungary-contours.geojson"
echo ""

# Convert to PMTiles using tippecanoe
# Try different image sources in order
echo "Attempting to use tippecanoe..."

TIPPECANOE_SUCCESS=false

# Try local build first
if podman image exists localhost/tippecanoe:latest 2>/dev/null; then
    echo "Using locally built tippecanoe..."
    if podman run --rm \
        -v "$DATA_DIR:/data" \
        -v "$TILES_DIR:/output" \
        localhost/tippecanoe:latest \
        -o /output/hungary-contours.pmtiles \
        -Z8 -z14 \
        --drop-densest-as-needed \
        --extend-zooms-if-still-dropping \
        --force \
        -l contour \
        /data/hungary-contours.geojson; then
        TIPPECANOE_SUCCESS=true
    fi
fi

# Try Docker Hub as fallback
if [ "$TIPPECANOE_SUCCESS" = false ]; then
    echo "Trying Docker Hub image..."
    if podman run --rm \
        -v "$DATA_DIR:/data" \
        -v "$TILES_DIR:/output" \
        docker.io/jimutt/tippecanoe:latest \
        tippecanoe \
        -o /output/hungary-contours.pmtiles \
        -Z8 -z14 \
        --drop-densest-as-needed \
        --extend-zooms-if-still-dropping \
        --force \
        -l contour \
        /data/hungary-contours.geojson 2>/dev/null; then
        TIPPECANOE_SUCCESS=true
    fi
fi

if [ "$TIPPECANOE_SUCCESS" = false ]; then
    echo ""
    echo "======================================"
    echo "Tippecanoe Not Available"
    echo "======================================"
    echo ""
    echo "No tippecanoe image could be found or pulled."
    echo "Building tippecanoe locally..."
    echo ""

    # Try to build locally
    "$SCRIPT_DIR/build-tippecanoe.sh"

    echo ""
    echo "Now trying with locally built image..."
    if podman run --rm \
        -v "$DATA_DIR:/data" \
        -v "$TILES_DIR:/output" \
        localhost/tippecanoe:latest \
        -o /output/hungary-contours.pmtiles \
        -Z8 -z14 \
        --drop-densest-as-needed \
        --extend-zooms-if-still-dropping \
        --force \
        -l contour \
        /data/hungary-contours.geojson; then
        TIPPECANOE_SUCCESS=true
    else
        echo ""
        echo "ERROR: Failed to generate PMTiles"
        echo ""
        echo "Your GeoJSON contours are available at:"
        echo "  $DATA_DIR/hungary-contours.geojson"
        echo ""
        echo "You can manually convert using tippecanoe from AUR:"
        echo "  yay -S tippecanoe"
        echo "  tippecanoe -o tiles/hungary-contours.pmtiles \\"
        echo "    -Z8 -z14 --force -l contour \\"
        echo "    data/hungary-contours.geojson"
        exit 1
    fi
fi

echo "Successfully generated PMTiles!"

echo ""
echo "Step 4: Verifying PMTiles..."
echo ""

# Verify the PMTiles file
podman run --rm \
    -v "$TILES_DIR:/tiles" \
    ghcr.io/protomaps/go-pmtiles:latest \
    verify /tiles/hungary-contours.pmtiles

echo ""
echo "Step 5: Cleaning up temporary files..."
echo ""

# Remove GeoJSON to save space
rm -f "$DATA_DIR/hungary-contours.geojson"

echo ""
echo "======================================"
echo "Contour Generation Complete!"
echo "======================================"
echo ""
echo "Contours PMTiles: $TILES_DIR/hungary-contours.pmtiles"
echo ""
echo "File size:"
ls -lh "$TILES_DIR/hungary-contours.pmtiles"
echo ""
echo "Next steps:"
echo "1. Update www/style.json to include contours source"
echo "2. Add contour layers to your map style"
echo ""
echo "See CONTOURS.md for style configuration"
