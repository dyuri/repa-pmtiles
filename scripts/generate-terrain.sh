#!/bin/bash
set -e

# Generate terrain-RGB PMTiles (Mapbox encoding) for 3D terrain and hillshade
# Output: tiles/hungary-terrain-rgb.pmtiles

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEM_DIR="$PROJECT_DIR/data/dem"
TILES_DIR="$PROJECT_DIR/tiles"
TMP_DIR="$PROJECT_DIR/tmp/terrain_build"

echo "======================================"
echo "Generating Terrain-RGB PMTiles (Mapbox)"
echo "======================================"

if [ ! -f "$DEM_DIR/hungary-dem.tif" ]; then
    echo "Error: hungary-dem.tif not found!"
    exit 1
fi

mkdir -p "$TMP_DIR" "$TILES_DIR"

echo "Step 1: Encoding DEM to Mapbox RGB TIFF..."
podman run --rm \
    -v "$DEM_DIR:/dem" \
    -v "$TMP_DIR:/tmp_work" \
    -v "$SCRIPT_DIR:/scripts" \
    ghcr.io/osgeo/gdal:alpine-normal-latest \
    python3 /scripts/dem_to_terrain_rgb.py \
        /dem/hungary-dem.tif \
        /tmp_work/hungary-terrain-rgb.tif

echo "Step 2: Converting to MBTiles..."
podman run --rm \
    -v "$TMP_DIR:/tmp_work" \
    ghcr.io/osgeo/gdal:alpine-small-latest \
    gdal_translate \
        -of MBTiles \
        -r nearest \
        -co ZOOM_LEVEL_STRATEGY=UPPER \
        -co TILE_FORMAT=PNG \
        /tmp_work/hungary-terrain-rgb.tif \
        /tmp_work/hungary-terrain.mbtiles

echo "Step 3: Building Tile Pyramid (Lower Zooms)..."
# Build overviews from 2x down to 128x (roughly zooms 14 down to 7)
podman run --rm \
    -v "$TMP_DIR:/tmp_work" \
    ghcr.io/osgeo/gdal:alpine-small-latest \
    gdaladdo -r nearest /tmp_work/hungary-terrain.mbtiles 2 4 8 16 32 64 128

echo "Step 4: Converting MBTiles to PMTiles..."
podman run --rm \
    -v "$TMP_DIR:/tmp_work" \
    -v "$TILES_DIR:/tiles" \
    ghcr.io/protomaps/go-pmtiles:latest \
    convert /tmp_work/hungary-terrain.mbtiles /tiles/hungary-terrain-rgb.pmtiles

echo "Step 5: Cleaning up..."
rm -rf "$TMP_DIR"

echo "======================================"
echo "Success! Output: $TILES_DIR/hungary-terrain-rgb.pmtiles"
echo "======================================"
