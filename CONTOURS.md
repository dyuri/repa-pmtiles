# Adding Contour Lines to Your Hiking Map

Contour lines (elevation lines) are essential for topographic hiking maps. They show the shape of the terrain and help hikers understand elevation changes.

## What You'll Get

- **Contour lines** every 20 meters (customizable)
- **Elevation labels** showing heights
- **Major contours** highlighted every 100m
- **Self-hosted** - no external dependencies

## Quick Start

```bash
# 1. Download DEM data for Hungary
./scripts/download-dem.sh

# 2. Generate contour lines (20m interval)
./scripts/generate-contours.sh 20

# 3. Update your style (see below)
# 4. Restart nginx and refresh browser
```

## Step-by-Step Guide

### Step 1: Download Elevation Data

Download SRTM (Shuttle Radar Topography Mission) data covering Hungary:

```bash
./scripts/download-dem.sh
```

This downloads ~30-50MB of data and creates `data/dem/hungary-dem.tif`.

**Note:** The script tries automatic download, but CGIAR SRTM servers can be slow or unavailable. If it fails, you can manually download from:
- https://srtm.csi.cgiar.org/srtmdata/
- https://dwtkns.com/srtm30m/ (visual tile selector)

Download tiles covering Hungary (approximately lat 45.5-48.7°N, lon 16.0-23.0°E).

### Step 2: Generate Contours

Generate contour lines from the DEM:

```bash
# 20 meter contours (recommended for hiking)
./scripts/generate-contours.sh 20

# Or 10 meter contours (more detail, larger file)
./scripts/generate-contours.sh 10

# Or 50 meter contours (less detail, smaller file)
./scripts/generate-contours.sh 50
```

This creates `tiles/hungary-contours.pmtiles` (typically 50-200MB depending on interval).

**Processing time:** 10-20 minutes depending on your system.

### Step 3: Update Your Style

Add contours as a second source in `www/style.json`:

#### A) Add the Contours Source

Find the `"sources"` section and add the contours source:

```json
{
  "version": 8,
  "name": "Hungarian Hiking Map",
  "glyphs": "http://localhost:8080/fonts/{fontstack}/{range}.pbf",
  "sources": {
    "hungary-hiking": {
      "type": "vector",
      "url": "pmtiles://http://localhost:8080/tiles/hungary-hiking.pmtiles",
      "attribution": "© OpenStreetMap contributors"
    },
    "contours": {
      "type": "vector",
      "url": "pmtiles://http://localhost:8080/tiles/hungary-contours.pmtiles",
      "attribution": "SRTM"
    }
  },
  "layers": [...]
}
```

#### B) Add Contour Layers

Add these layers to your style (insert after the background but before trails):

```json
{
  "id": "contour-lines",
  "type": "line",
  "source": "contours",
  "source-layer": "contour",
  "minzoom": 11,
  "filter": ["!=", ["get", "elevation"], 0],
  "paint": {
    "line-color": "#c2a66b",
    "line-width": [
      "match",
      ["%", ["get", "elevation"], 100],
      0, 1.2,
      0.5
    ],
    "line-opacity": 0.6
  }
},
{
  "id": "contour-labels",
  "type": "symbol",
  "source": "contours",
  "source-layer": "contour",
  "minzoom": 13,
  "filter": ["==", ["%", ["get", "elevation"], 100], 0],
  "layout": {
    "text-field": "{elevation}m",
    "text-font": ["Noto Sans Regular"],
    "text-size": 9,
    "symbol-placement": "line",
    "text-rotation-alignment": "map"
  },
  "paint": {
    "text-color": "#8b7355",
    "text-halo-color": "#fff",
    "text-halo-width": 1
  }
}
```

### Step 4: Apply Changes

```bash
# Restart nginx to serve the new PMTiles file
make restart

# Hard refresh your browser (Ctrl+Shift+R or Cmd+Shift+R)
```

## Customization

### Change Contour Styling

**Thin, subtle contours:**
```json
"paint": {
  "line-color": "#d4c5a9",
  "line-width": 0.3,
  "line-opacity": 0.4
}
```

**Bold, prominent contours:**
```json
"paint": {
  "line-color": "#8b7355",
  "line-width": 1,
  "line-opacity": 0.8
}
```

**Dark theme contours:**
```json
"paint": {
  "line-color": "#666",
  "line-width": 0.5,
  "line-opacity": 0.5
}
```

### Highlight Major Contours

Make every 100m contour thicker:

```json
"paint": {
  "line-color": "#c2a66b",
  "line-width": [
    "match",
    ["%", ["get", "elevation"], 100],
    0, 1.5,  // Every 100m: thick
    0.4      // Other contours: thin
  ]
}
```

### Adjust Zoom Levels

Show contours earlier or later:

```json
"minzoom": 10,  // Show from zoom 10 (earlier)
"maxzoom": 16   // Hide after zoom 16 (optional)
```

### Change Contour Interval

Regenerate with different interval:

```bash
# More detailed (10m)
./scripts/generate-contours.sh 10

# Less detailed (50m)
./scripts/generate-contours.sh 50
```

## Visual Editing in Maputnik

1. Open https://maputnik.github.io/editor/
2. Load your updated `style.json`
3. Edit the `contour-lines` layer:
   - Change colors
   - Adjust line width
   - Modify opacity
4. Export and save

## File Sizes

Typical file sizes for Hungary:

| Interval | File Size | Detail Level |
|----------|-----------|--------------|
| 10m      | 200-300MB | Very detailed |
| 20m      | 100-150MB | Good balance |
| 50m      | 50-80MB   | Basic |
| 100m     | 30-50MB   | Minimal |

**Recommendation:** 20m is ideal for hiking maps.

## Performance Tips

1. **Start contours at higher zoom:** Use `"minzoom": 12` if performance is slow
2. **Limit max zoom:** Use `"maxzoom": 15` to avoid rendering at extreme zooms
3. **Simplify more:** Edit `generate-contours.sh` and increase `-simplify` value

## Troubleshooting

### DEM Download Fails

Manual download:
1. Go to https://dwtkns.com/srtm30m/
2. Click tiles covering Hungary
3. Download and extract to `data/dem/`
4. Run merge command manually:

```bash
cd data/dem
podman run --rm -v "$(pwd):/data" ghcr.io/osgeo/gdal:alpine-small-latest \
  gdalwarp -te 16.0 45.5 23.0 48.7 \
  -tr 0.0008333333 0.0008333333 -r cubic \
  -co COMPRESS=DEFLATE -co TILED=YES \
  /data/*.tif /data/hungary-dem.tif
```

### Contour Generation Too Slow

- Use fewer cores or simplify more
- Increase contour interval (50m or 100m)
- Process smaller area (edit bounds in script)

### PMTiles Too Large

- Increase contour interval
- Increase simplification tolerance
- Reduce zoom range (skip higher zooms)

### Contours Not Showing

1. Check browser console for errors
2. Verify PMTiles file exists: `ls -lh tiles/hungary-contours.pmtiles`
3. Check nginx logs: `make logs`
4. Ensure style.json has correct source URL
5. Hard refresh browser (Ctrl+Shift+R)

## Example: Complete Style with Contours

Here's a minimal working style with contours:

```json
{
  "version": 8,
  "name": "Hiking Map with Contours",
  "glyphs": "http://localhost:8080/fonts/{fontstack}/{range}.pbf",
  "sources": {
    "hungary-hiking": {
      "type": "vector",
      "url": "pmtiles://http://localhost:8080/tiles/hungary-hiking.pmtiles"
    },
    "contours": {
      "type": "vector",
      "url": "pmtiles://http://localhost:8080/tiles/hungary-contours.pmtiles"
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {"background-color": "#f8f4f0"}
    },
    {
      "id": "contour-lines",
      "type": "line",
      "source": "contours",
      "source-layer": "contour",
      "minzoom": 11,
      "paint": {
        "line-color": "#c2a66b",
        "line-width": ["match", ["%", ["get", "elevation"], 100], 0, 1.2, 0.5],
        "line-opacity": 0.6
      }
    },
    {
      "id": "water",
      "type": "fill",
      "source": "hungary-hiking",
      "source-layer": "water",
      "paint": {"fill-color": "#a0c8f0"}
    },
    {
      "id": "trails",
      "type": "line",
      "source": "hungary-hiking",
      "source-layer": "trails",
      "paint": {
        "line-color": "#d73f09",
        "line-width": 2
      }
    }
  ]
}
```

## Advanced: Hillshading

For even more terrain detail, you can add hillshading (requires more processing):

```bash
# Generate hillshade
podman run --rm -v "$(pwd)/data/dem:/data" \
  ghcr.io/osgeo/gdal:alpine-small-latest \
  gdaldem hillshade /data/hungary-dem.tif /data/hillshade.tif \
  -z 2 -az 315 -alt 45
```

Then convert to raster tiles for use in your map.

## Resources

- [GDAL Contour Documentation](https://gdal.org/programs/gdal_contour.html)
- [Tippecanoe Documentation](https://github.com/felt/tippecanoe)
- [SRTM Data Info](https://www.usgs.gov/centers/eros/science/usgs-eros-archive-digital-elevation-shuttle-radar-topography-mission-srtm-1)
- [Contour Styling Examples](https://maplibre.org/maplibre-style-spec/layers/)

## Summary

1. `make contours` - One command to rule them all (when added to Makefile)
2. Updates `style.json` with contours source and layers
3. Restart nginx and refresh browser
4. Enjoy your topographic hiking map! 🏔️
