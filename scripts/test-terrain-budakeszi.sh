#!/bin/bash
set -e

# Quick terrain-RGB test for Budakeszi area only
# Runs the full pipeline on a small clip - completes in seconds instead of minutes
# Output: tiles/test-terrain-budakeszi.pmtiles

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEM_DIR="$PROJECT_DIR/data/dem"
TILES_DIR="$PROJECT_DIR/tiles"
TMP_DIR="$PROJECT_DIR/tmp/test_terrain"

# Budakeszi area bounds (minlon minlat maxlon maxlat)
BOUNDS="18.7 47.35 19.1 47.65"

echo "======================================"
echo "Test: Terrain-RGB for Budakeszi area"
echo "Bounds: $BOUNDS"
echo "======================================"
echo ""

if [ ! -f "$DEM_DIR/hungary-dem.tif" ]; then
    echo "Error: hungary-dem.tif not found!"
    exit 1
fi

mkdir -p "$TMP_DIR" "$TILES_DIR"

echo "Step 1: Clipping DEM to Budakeszi area..."
podman run --rm \
    -v "$DEM_DIR:/dem" \
    -v "$TMP_DIR:/tmp_work" \
    ghcr.io/osgeo/gdal:alpine-small-latest \
    gdal_translate \
        -projwin 18.7 47.65 19.1 47.35 \
        /dem/hungary-dem.tif /tmp_work/budakeszi-dem.tif

echo ""
echo "Step 2: Converting to terrain-RGB..."
podman run --rm \
    -v "$TMP_DIR:/tmp_work" \
    -v "$SCRIPT_DIR:/scripts" \
    ghcr.io/osgeo/gdal:alpine-normal-latest \
    python3 /scripts/dem_to_terrain_rgb.py \
        /tmp_work/budakeszi-dem.tif \
        /tmp_work/budakeszi-terrain-rgb.tif

echo ""
echo "Step 3: Converting to MBTiles..."
podman run --rm \
    -v "$TMP_DIR:/tmp_work" \
    ghcr.io/osgeo/gdal:alpine-small-latest \
    gdal_translate \
        -of MBTiles \
        -r nearest \
        -co ZOOM_LEVEL_STRATEGY=UPPER \
        -co TILE_FORMAT=PNG \
        /tmp_work/budakeszi-terrain-rgb.tif \
        /tmp_work/budakeszi-terrain.mbtiles

echo ""
echo "Step 4: Building tile pyramid (lower zoom levels)..."
podman run --rm \
    -v "$TMP_DIR:/tmp_work" \
    ghcr.io/osgeo/gdal:alpine-small-latest \
    gdaladdo -r nearest /tmp_work/budakeszi-terrain.mbtiles 2 4 8 16 32 64 128

echo ""
echo "Step 5: Converting to PMTiles..."
podman run --rm \
    -v "$TMP_DIR:/tmp_work" \
    -v "$TILES_DIR:/tiles" \
    ghcr.io/protomaps/go-pmtiles:latest \
    convert /tmp_work/budakeszi-terrain.mbtiles /tiles/test-terrain-budakeszi.pmtiles

echo ""
echo "Step 6: Cleaning up..."
rm -rf "$TMP_DIR"

echo ""
echo "======================================"
echo "Done! Output: $TILES_DIR/test-terrain-budakeszi.pmtiles"
echo "======================================"
echo ""
echo "To test, temporarily update www/style.json source url to:"
echo "  pmtiles://http://localhost:8080/tiles/test-terrain-budakeszi.pmtiles"
echo "then: make restart"
echo ""
