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
| `scripts/dem_to_terrain_rgb.py` | DEM → Mapbox terrain-RGB GeoTIFF (reproject, fill voids, encode) |
| `scripts/generate-terrain.sh` | Full terrain-RGB PMTiles pipeline |
| `scripts/generate-bike.sh` | Bike map PMTiles pipeline |
| `scripts/test-terrain-budakeszi.sh` | Quick test pipeline for Budakeszi area only |
| `scripts/publish.sh` | Copy assets to target dir, substitute URLs |
| `config/config-bike.json` | Tilemaker layer definitions for bike map |
| `config/process-bike.lua` | Tilemaker Lua: OSM → cycling/MTB/route extraction |
| `www/bike.html` | Bike map viewer (MapLibre, separate from hiking viewer) |
| `www/style-bike.json` | MapLibre style for bike map |

## Tile Sources (style.json)

- `hungary-hiking` — vector PMTiles (503 MB): trails, POIs, roads, landuse, water, buildings, place_labels, boundaries
- `hungary-bike` — vector PMTiles: cycling infrastructure, route relations, bike POIs (separate pipeline)
- `contours` — vector PMTiles (71 MB): elevation contours at 20m intervals
- `terrain-rgb` — raster-dem PMTiles: Mapbox-encoded elevation for hillshade + 3D terrain

## Generated Tiles

```
tiles/hungary-hiking.pmtiles       503 MB  main OSM data
tiles/hungary-bike.pmtiles         ~TBD    bike map (cycling routes, MTB, infrastructure)
tiles/hungary-contours.pmtiles      71 MB  elevation contours
tiles/hungary-terrain-rgb.pmtiles   ~15 MB  terrain-RGB (Mapbox encoding, zoom 5-12)
data/dem/hungary-dem.tif            ~80 MB  Copernicus DEM GLO-30 (30m, Hungary bounds)
```

## Map Layers (24 total)

Background → hillshade → forest/grass/farmland/water → waterway → boundaries → contours → buildings → roads → physical-paths → hiking-routes → pois → labels → place-labels

Trail colors: red, blue, green, yellow, orange, purple, black, brown (Hungarian OSMC system)

## Data Pipeline

```
OSM PBF → Tilemaker + Lua → MBTiles → go-pmtiles convert → PMTiles
DEM TIF → gdal_contour → GeoJSON → tippecanoe → PMTiles
DEM TIF → dem_to_terrain_rgb.py (reproject+encode) → gdal_translate MBTiles → gdaladdo → go-pmtiles convert → PMTiles
```

## Make Targets

```bash
make download      # Download hungary-latest.osm.pbf (~307 MB)
make fonts         # Download Noto Sans PBF glyphs → www/fonts/
make generate      # OSM → PMTiles (10-30 min via Docker)
make contours      # DEM download + contour PMTiles (20m intervals)
make terrain       # DEM → terrain-RGB PMTiles (hillshade + 3D terrain)
make generate-bike # OSM → hungary-bike.pmtiles (cycling routes, MTB, infrastructure)
make bike          # alias for generate-bike
make up            # Start nginx (podman compose up -d)
make topo          # download + fonts + generate + contours
make all           # download + fonts + generate + up
make dev-up        # Start with Maputnik editor on port 8888
```

## Docker Images Used

- `ghcr.io/systemed/tilemaker:master` — OSM → MBTiles
- `ghcr.io/protomaps/go-pmtiles:latest` — MBTiles → PMTiles, verification
- `ghcr.io/osgeo/gdal:alpine-small-latest` — DEM processing, contours, MBTiles conversion
- `ghcr.io/osgeo/gdal:alpine-normal-latest` — terrain-RGB encoding (needs Python/numpy)
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

UI controls: Hillshade toggle, 3D Terrain toggle + exaggeration slider (0.5×–5×)

## 3D Terrain / Hillshade

- Source: `terrain-rgb` (`raster-dem`, Mapbox encoding)
- Hillshade layer always rendered (toggleable), exaggeration 0.8
- 3D terrain via `map.setTerrain()` with exaggeration slider
- DEM source: Copernicus DEM GLO-30 (30m, downloaded from AWS public S3)
- Encoding: Mapbox (`elevation = -10000 + (R*65536 + G*256 + B) * 0.1`)
- Pipeline details in `3DTERRAIN.md`

## Known Issues / Workarounds

- MapLibre "Unimplemented type: 4" error suppressed via `map.on('error', ...)` handler — occurs with complex route geometries
- Trail symbols (`trail_symbol`, `trail_text`, `trail_text_color`) commented out in `config/process-hiking.lua` to avoid MapLibre rendering errors; only `trail_color` is active
- `hungary-hiking.pmtiles` max zoom is 14; style layers using it respect that
- Right-click drag on map canvas (3D rotation) has `contextmenu` and `mousedown` propagation stopped to prevent Chrome extension interference

## Fonts

Self-hosted at `www/fonts/`, served as `http://localhost:8080/fonts/{fontstack}/{range}.pbf`
Primary font: "Noto Sans Regular" / "Noto Sans Bold"

## Style Editing

```bash
make style-to-maputnik    # Convert pmtiles:// URLs for Maputnik compatibility
make dev-up               # Start Maputnik on port 8888
make style-from-maputnik  # Convert back to pmtiles:// URLs
```

## Publishing

```bash
./scripts/publish.sh <target-dir> <destination-url>
# Example: ./scripts/publish.sh /var/www/hiking https://maps.example.com
```
