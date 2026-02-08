#!/bin/bash
set -e

# Script to download Digital Elevation Model (DEM) data for Hungary
# Uses Copernicus DEM GLO-30 (TanDEM-X based, 30m resolution)
# Source: AWS Open Data public bucket - no authentication required
# Usage: ./scripts/download-dem.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEM_DIR="$PROJECT_DIR/data/dem"

echo "======================================"
echo "Downloading Copernicus DEM for Hungary"
echo "======================================"
echo ""
echo "Source: Copernicus DEM GLO-30 (30m resolution, TanDEM-X)"
echo "Much higher quality than SRTM, especially in urban/hilly areas"
echo ""

mkdir -p "$DEM_DIR"
cd "$DEM_DIR"

# Copernicus DEM GLO-30 on AWS Open Data (public bucket, no auth needed)
BASE_URL="https://copernicus-dem-30m.s3.amazonaws.com"

# Hungary bounds: ~45.7-48.6 N, ~16.1-22.9 E
# We use 1-degree tiles, so need N45-N48, E016-E022
LATS=(45 46 47 48)
LONS=(16 17 18 19 20 21 22)

DOWNLOADED_FILES=""

echo "Downloading 1-degree tiles covering Hungary..."
echo "(tiles missing from the bucket are skipped - e.g. water-only areas)"
echo ""

for lat in "${LATS[@]}"; do
    for lon in "${LONS[@]}"; do
        lat_str=$(printf "N%02d" $lat)
        lon_str=$(printf "E%03d" $lon)
        tile_name="Copernicus_DSM_COG_10_${lat_str}_00_${lon_str}_00_DEM"
        tile_file="${tile_name}.tif"
        tile_url="${BASE_URL}/${tile_name}/${tile_file}"

        if [ -f "$tile_file" ]; then
            echo "✓ ${tile_file} already exists, skipping..."
            DOWNLOADED_FILES="$DOWNLOADED_FILES /data/${tile_file}"
            continue
        fi

        echo "Downloading ${tile_file}..."
        if wget -q --timeout=60 "$tile_url" -O "$tile_file"; then
            echo "  ✓ downloaded"
            DOWNLOADED_FILES="$DOWNLOADED_FILES /data/${tile_file}"
        else
            echo "  - not found, skipping (water or no coverage)"
            rm -f "$tile_file"
        fi
    done
done

echo ""

if [ -z "$DOWNLOADED_FILES" ]; then
    echo "======================================"
    echo "Error: No tiles downloaded!"
    echo "======================================"
    echo ""
    echo "The AWS bucket may be unreachable. Try alternative sources:"
    echo "  - https://opentopography.org/ (requires free account)"
    echo "  - https://www.copernicus.eu/en/access-data"
    echo ""
    exit 1
fi

echo "Merging tiles and clipping to Hungary bounds..."
echo "Hungary bounds: [16.0, 45.5, 23.0, 48.7]"
echo ""

podman run --rm \
    -v "$DEM_DIR:/data" \
    ghcr.io/osgeo/gdal:alpine-small-latest \
    gdalwarp \
        -te 16.0 45.5 23.0 48.7 \
        -tr 0.0002777778 0.0002777778 \
        -r bilinear \
        -srcnodata -32768 \
        -dstnodata -32768 \
        -multi \
        -wo NUM_THREADS=ALL_CPUS \
        -co COMPRESS=DEFLATE \
        -co TILED=YES \
        $DOWNLOADED_FILES \
        /data/hungary-dem.tif

echo ""
echo "Cleaning up individual tiles..."
for lat in "${LATS[@]}"; do
    for lon in "${LONS[@]}"; do
        lat_str=$(printf "N%02d" $lat)
        lon_str=$(printf "E%03d" $lon)
        tile_name="Copernicus_DSM_COG_10_${lat_str}_00_${lon_str}_00_DEM"
        rm -f "${tile_name}.tif"
    done
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
echo "Resolution: ~30m (Copernicus DEM GLO-30)"
echo "Next step: Run ./scripts/generate-contours.sh"
echo "           or: make terrain"
echo ""
