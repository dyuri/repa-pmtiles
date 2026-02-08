# Project: Hungarian Hiking Maps with PMTiles

Self-hosted vector tile map for Hungarian hiking trails. Docker/Podman-based pipeline from OSM data to MapLibre GL JS viewer.

## Stack

- **MapLibre GL JS**: 4.7.1 (in `www/index.html`)
- **PMTiles**: 3.0.7 protocol (`pmtiles://` URL scheme)
- **Container runtime**: Podman (`podman compose`), Docker-compatible
- **Web server**: nginx on port 8080
- **Map viewer**: `http://localhost:8080`

## Key Files

| File | Purpose |
|------|---------|
| `www/index.html` | MapLibre viewer — map init, click handlers, controls |
| `www/style.json` | MapLibre style spec v8 — sources, layers, fonts |
| `config/config-hiking.json` | Tilemaker layer definitions, zoom 6-14 |
| `config/process-hiking.lua` | Tilemaker Lua: OSM → trail/POI/road extraction |
| `nginx/nginx.conf` | nginx with CORS + range request support |
| `Makefile` | All build targets |

## Tile Sources (style.json)

- `hungary-hiking` — vector PMTiles (503 MB): trails, POIs, roads, landuse, water, buildings, place_labels, boundaries
- `contours` — vector PMTiles (71 MB): elevation contours at 20m intervals

## Generated Tiles

```
tiles/hungary-hiking.pmtiles    503 MB  main OSM data
tiles/hungary-contours.pmtiles   71 MB  elevation contours
data/dem/hungary-dem.tif         13 MB  SRTM 90m raw DEM (Hungary bounds)
```

## Map Layers (23 total)

Background → hillshade (if added) → forest/grass/farmland/water → waterway → boundaries → contours → buildings → roads → physical-paths → hiking-routes → pois → labels → place-labels

Trail colors: red, blue, green, yellow, orange, purple, black, brown (Hungarian OSMC system)

## Data Pipeline

```
OSM PBF → Tilemaker + Lua → MBTiles → go-pmtiles convert → PMTiles
DEM TIF → gdal_contour → GeoJSON → tippecanoe → PMTiles
```

## Make Targets

```bash
make download      # Download hungary-latest.osm.pbf (~307 MB)
make fonts         # Download Noto Sans PBF glyphs → www/fonts/
make generate      # OSM → PMTiles (10-30 min via Docker)
make contours      # DEM download + contour PMTiles (20m intervals)
make up            # Start nginx (podman compose up -d)
make topo          # download + fonts + generate + contours
make all           # download + fonts + generate + up
make dev-up        # Start with Maputnik editor on port 8888
```

## Docker Images Used

- `ghcr.io/systemed/tilemaker:master` — OSM → MBTiles
- `ghcr.io/protomaps/go-pmtiles:latest` — MBTiles → PMTiles, verification
- `ghcr.io/osgeo/gdal:alpine-small-latest` — DEM processing, contours
- `nginx:alpine` — tile server

## Map Init (index.html)

```javascript
new maplibregl.Map({
    container: 'map',
    style: 'http://localhost:8080/style.json',
    center: [19.5, 47.2],  // Budapest area
    zoom: 8,
    hash: true
})
```

Interactive layers: `hiking-routes`, `physical-paths`, `pois`

## Known Issues / Workarounds

- MapLibre "Unimplemented type: 4" error suppressed via `map.on('error', ...)` handler — occurs with complex route geometries
- Trail symbols (`trail_symbol`, `trail_text`, `trail_text_color`) commented out in `config/process-hiking.lua` to avoid MapLibre rendering errors; only `trail_color` is active
- `hungary-hiking.pmtiles` max zoom is 14; style layers using it respect that

## Fonts

Self-hosted at `www/fonts/`, served as `http://localhost:8080/fonts/{fontstack}/{range}.pbf`
Primary font: "Noto Sans Regular" / "Noto Sans Bold"

## Style Editing

```bash
make style-to-maputnik    # Convert pmtiles:// URLs for Maputnik compatibility
make dev-up               # Start Maputnik on port 8888
make style-from-maputnik  # Convert back to pmtiles:// URLs
```

## Pending Work

- **3D Terrain + Hillshade**: Full plan in `3DTERRAIN.md`
  - Generate terrain-RGB PMTiles from existing `data/dem/hungary-dem.tif`
  - Add `raster-dem` source + `hillshade` layer to `style.json`
  - Add terrain/hillshade toggle buttons to `index.html`
  - Add `terrain` Makefile target
  - Pipeline: gdalwarp → gdal_calc (Terrarium encoding) → gdal_translate -of MBTiles → go-pmtiles convert
