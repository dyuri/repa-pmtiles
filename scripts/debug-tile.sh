#!/bin/bash
# Debug a specific tile by lat/lon coordinates

set -e

LAT=${1:-47.494599}
LON=${2:-18.975386}
ZOOM=${3:-13}

# Convert lat/lon to tile coordinates
# Using Python for the conversion
TILE_COORDS=$(python3 << EOF
import math

lat = $LAT
lon = $LON
zoom = $ZOOM

# Convert to tile coordinates
n = 2 ** zoom
x = int((lon + 180) / 360 * n)
y = int((1 - math.log(math.tan(math.radians(lat)) + 1 / math.cos(math.radians(lat))) / math.pi) / 2 * n)

print(f"{zoom}/{x}/{y}")
print(f"Tile: Z{zoom} X{x} Y{y}")
EOF
)

TILE_PATH=$(echo "$TILE_COORDS" | head -1)
echo "Coordinates: $LAT, $LON"
echo "Tile path: $TILE_PATH"
echo ""

# Extract Z, X, Y from tile path
Z=$(echo $TILE_PATH | cut -d'/' -f1)
X=$(echo $TILE_PATH | cut -d'/' -f2)
Y=$(echo $TILE_PATH | cut -d'/' -f3)

# Extract the tile using pmtiles via Docker (outputs to stdout)
echo "Extracting tile Z=$Z X=$X Y=$Y from hungary-hiking.pmtiles..."
SUPPRESS_BOLTDB_WARNING=1 podman run --rm -v "$(pwd)/tiles:/tiles:ro" \
  -e SUPPRESS_BOLTDB_WARNING=1 \
  ghcr.io/protomaps/go-pmtiles:latest \
  tile /tiles/hungary-hiking.pmtiles $Z $X $Y > debug/tile-$Z-$X-$Y.mvt 2>/dev/null

if [ -f "debug/tile-$Z-$X-$Y.mvt" ]; then
  echo ""
  echo "Tile extracted to: debug/tile-$Z-$X-$Y.mvt"
  echo "Size: $(du -h debug/tile-$Z-$X-$Y.mvt | cut -f1)"

  # Try to get some basic info about the tile
  echo ""
  echo "Tile contents (hex dump first 100 bytes):"
  hexdump -C debug/tile-$Z-$X-$Y.mvt | head -20
else
  echo "Failed to extract tile or tile doesn't exist"
fi
