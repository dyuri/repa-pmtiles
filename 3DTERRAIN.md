# 3D Terrain & Hillshade Implementation Plan

Add hillshade overlay and 3D terrain rendering to the existing MapLibre GL JS map viewer using self-hosted terrain-RGB PMTiles derived from the existing SRTM DEM.

## Overview

Four components:
1. **`scripts/generate-terrain.sh`** — convert existing SRTM DEM to terrain-RGB PMTiles
2. **`www/style.json`** — add `raster-dem` source + `hillshade` layer
3. **`www/index.html`** — add toggle buttons + JavaScript logic
4. **`Makefile`** — add `terrain` target

## Part 1: Terrain-RGB Generation Pipeline

### Encoding

Use **Terrarium** encoding (open standard, no API key needed):
- `R = floor((elevation + 32768) / 256)`
- `G = (elevation + 32768) mod 256`
- `B = floor(((elevation + 32768) - floor(elevation + 32768)) * 256)` — effectively 0 for integer SRTM data

Hungary elevation range: 78m–1014m (well within uint8 bounds, no overflow).

### Script: `scripts/generate-terrain.sh`

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEM_DIR="$PROJECT_DIR/data/dem"
TILES_DIR="$PROJECT_DIR/tiles"
TMP_DIR="$PROJECT_DIR/tmp/terrain_build"

echo "======================================"
echo "Generating Terrain-RGB Tiles"
echo "======================================"

if [ ! -f "$DEM_DIR/hungary-dem.tif" ]; then
    echo "Error: hungary-dem.tif not found!"
    echo "Please run ./scripts/download-dem.sh first"
    exit 1
fi

mkdir -p "$TMP_DIR" "$TILES_DIR"

echo "Step 1: Reprojecting DEM to Web Mercator (EPSG:3857)..."
podman run --rm \
    -v "$DEM_DIR:/dem" \
    -v "$TMP_DIR:/tmp_work" \
    ghcr.io/osgeo/gdal:alpine-small-latest \
    gdalwarp \
        -t_srs EPSG:3857 \
        -r bilinear \
        -co COMPRESS=DEFLATE \
        -co TILED=YES \
        /dem/hungary-dem.tif /tmp_work/hungary-dem-3857.tif

echo "Step 2: Encoding elevation as Terrarium RGB..."
podman run --rm \
    -v "$TMP_DIR:/tmp_work" \
    ghcr.io/osgeo/gdal:alpine-small-latest \
    sh -c '
        gdal_calc.py -A /tmp_work/hungary-dem-3857.tif \
            --outfile=/tmp_work/terrain-R.tif \
            --calc="numpy.floor((A + 32768) / 256).astype(numpy.uint8)" \
            --type=Byte --NoDataValue=0 --overwrite &&
        gdal_calc.py -A /tmp_work/hungary-dem-3857.tif \
            --outfile=/tmp_work/terrain-G.tif \
            --calc="numpy.mod(numpy.floor(A + 32768), 256).astype(numpy.uint8)" \
            --type=Byte --NoDataValue=0 --overwrite &&
        gdal_calc.py -A /tmp_work/hungary-dem-3857.tif \
            --outfile=/tmp_work/terrain-B.tif \
            --calc="numpy.zeros_like(A, dtype=numpy.uint8)" \
            --type=Byte --NoDataValue=0 --overwrite &&
        gdal_merge.py -separate \
            -o /tmp_work/hungary-terrain-rgb.tif \
            -ot Byte \
            /tmp_work/terrain-R.tif /tmp_work/terrain-G.tif /tmp_work/terrain-B.tif
    '

echo "Step 3: Converting to MBTiles (zoom 5-12)..."
podman run --rm \
    -v "$TMP_DIR:/tmp_work" \
    ghcr.io/osgeo/gdal:alpine-small-latest \
    gdal_translate \
        -of MBTiles \
        -co ZOOM_LEVEL_STRATEGY=AUTO \
        -co TILE_FORMAT=PNG \
        /tmp_work/hungary-terrain-rgb.tif \
        /tmp_work/hungary-terrain.mbtiles

echo "Step 4: Converting MBTiles to PMTiles..."
podman run --rm \
    -v "$TMP_DIR:/tmp_work" \
    -v "$TILES_DIR:/tiles" \
    ghcr.io/protomaps/go-pmtiles:latest \
    convert /tmp_work/hungary-terrain.mbtiles /tiles/hungary-terrain-rgb.pmtiles

echo "Step 5: Verifying PMTiles..."
podman run --rm \
    -v "$TILES_DIR:/tiles" \
    ghcr.io/protomaps/go-pmtiles:latest \
    verify /tiles/hungary-terrain-rgb.pmtiles

echo "Step 6: Cleaning up..."
rm -rf "$TMP_DIR"

echo ""
echo "Output: $TILES_DIR/hungary-terrain-rgb.pmtiles"
ls -lh "$TILES_DIR/hungary-terrain-rgb.pmtiles"
```

Expected output size: ~15–25 MB.

## Part 2: `www/style.json` Changes

### Add source (after `contours` source)

```json
"terrain-rgb": {
  "type": "raster-dem",
  "url": "pmtiles://http://localhost:8080/tiles/hungary-terrain-rgb.pmtiles",
  "encoding": "terrarium",
  "tileSize": 256,
  "attribution": "SRTM via CGIAR"
}
```

### Add hillshade layer (after `background` layer, index 1)

```json
{
  "id": "hillshade",
  "type": "hillshade",
  "source": "terrain-rgb",
  "layout": {
    "visibility": "visible"
  },
  "paint": {
    "hillshade-illumination-direction": 335,
    "hillshade-illumination-anchor": "map",
    "hillshade-exaggeration": 0.35,
    "hillshade-shadow-color": "hsl(0, 0%, 0%)",
    "hillshade-highlight-color": "hsl(0, 0%, 100%)",
    "hillshade-accent-color": "hsl(0, 0%, 0%)"
  }
}
```

Low exaggeration (0.35) keeps the dark theme readable. Hillshade placed early in layer stack so it shades under forests, water, and roads.

## Part 3: `www/index.html` Changes

### CSS (add to `<style>` block)

```css
.terrain-controls {
    position: absolute;
    top: 90px;
    right: 10px;
    background: white;
    border-radius: 5px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
    z-index: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 6px;
}

.terrain-btn {
    padding: 6px 10px;
    border: 1px solid #ccc;
    border-radius: 4px;
    background: white;
    cursor: pointer;
    font-size: 12px;
    font-family: inherit;
    white-space: nowrap;
}

.terrain-btn.active {
    background: #4a90d9;
    color: white;
    border-color: #3a7bc8;
}

.terrain-btn:hover { background: #f0f0f0; }
.terrain-btn.active:hover { background: #3a7bc8; }
```

### HTML (add before `<div id="map">`)

```html
<div class="terrain-controls">
    <button class="terrain-btn" id="btn-hillshade" title="Toggle hillshade overlay">Hillshade</button>
    <button class="terrain-btn" id="btn-terrain" title="Toggle 3D terrain">3D Terrain</button>
</div>
```

### JavaScript (add after map initialization, inside or after `map.on('load', ...)`)

```javascript
let terrainEnabled = false;
let hillshadeEnabled = true; // starts enabled (layer visibility: visible)

document.getElementById('btn-hillshade').classList.add('active');

document.getElementById('btn-terrain').addEventListener('click', function() {
    terrainEnabled = !terrainEnabled;
    this.classList.toggle('active', terrainEnabled);

    if (terrainEnabled) {
        map.setTerrain({ source: 'terrain-rgb', exaggeration: 1.5 });
        if (map.getPitch() < 20) {
            map.easeTo({ pitch: 50, duration: 800 });
        }
    } else {
        map.setTerrain(null);
        map.easeTo({ pitch: 0, duration: 600 });
    }
});

document.getElementById('btn-hillshade').addEventListener('click', function() {
    hillshadeEnabled = !hillshadeEnabled;
    this.classList.toggle('active', hillshadeEnabled);
    map.setLayoutProperty('hillshade', 'visibility', hillshadeEnabled ? 'visible' : 'none');
});
```

Note: Position `top: 90px; right: 10px;` avoids overlapping the existing NavigationControl (top-right).

## Part 4: `Makefile` Changes

Add to `.PHONY` line:
```makefile
.PHONY: help download fonts setup generate contours terrain up down restart logs clean all
```

Add target after `contours`:
```makefile
terrain:
	@echo "Generating terrain-RGB tiles for 3D terrain and hillshade..."
	@if [ ! -f data/dem/hungary-dem.tif ]; then \
		echo "DEM not found, downloading..."; \
		./scripts/download-dem.sh; \
	fi
	@./scripts/generate-terrain.sh
```

Update help text and `topo` target to include terrain.

## Potential Issues

1. **gdal_translate MBTiles zoom range**: May need explicit `-co ZOOM_LEVEL=12` if AUTO doesn't pick the right range. Verify with `go-pmtiles show`.
2. **gdal_calc numpy availability**: `ghcr.io/osgeo/gdal:alpine-small-latest` includes numpy; if not, fall back to VRT-based arithmetic.
3. **Button/NavigationControl overlap**: NavigationControl defaults to top-right. Use `top: 90px` to position below it.

## Upgrade Path: Copernicus DEM (30m)

The existing SRTM 90m is sufficient for zoom 5–12. For zoom 13–14 detail:

1. Download Copernicus DEM 30m tiles from AWS `copernicus-dem-30m` bucket (Hungary: ~E016N48 through E023N45)
2. Merge with `gdalwarp -tr 0.000277778 0.000277778` (~30m resolution)
3. Increase max zoom in `generate-terrain.sh` from 12 to 14
4. Expected output: ~50–80 MB PMTiles

## Implementation Sequence

1. Create `scripts/generate-terrain.sh` (chmod +x)
2. Run `make terrain` → generates `tiles/hungary-terrain-rgb.pmtiles`
3. Add `terrain-rgb` source to `www/style.json`
4. Insert `hillshade` layer after `background` in `www/style.json`
5. Add CSS + HTML buttons to `www/index.html`
6. Add JavaScript toggle logic to `www/index.html`
7. Add `terrain` target to `Makefile`
8. `make restart` and test at `http://localhost:8080`
