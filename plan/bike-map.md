# Bike Map Plan

## Approach: New commands in the same repo

The project already has this pattern: `config-hiking.json` + `config-routes-only.json`, both Lua files, all sharing the same Docker/nginx infrastructure. A bike map is a third variant — same OSM PBF input, different Tilemaker config + Lua + style. No separate repo or branch needed.

---

## Decisions

1. **Viewer**: Separate `www/bike.html` page (independent from hiking viewer)
2. **MTB trails**: Included, color-coded; different colors for road/gravel infrastructure; roads forbidden to cyclists marked visually
3. **Route relations**: EuroVelo and national cycling routes shown with line offset so they don't cover the underlying road/path

---

## Implementation Steps

### 1. `config/config-bike.json`

Layers:
- `cycling` — dedicated cycling ways (cycleways, MTB trails, bike paths); minzoom 10, maxzoom 14
- `cycling_routes` — route relation geometries (EuroVelo, NCN, RCN, LCN, MTB); minzoom 6, maxzoom 14
- `roads` — road network with bike access attributes; minzoom 8, maxzoom 14
- `landuse`, `water`, `waterway`, `boundaries`, `place_labels`, `buildings` — same as hiking config

Settings: minzoom 6, maxzoom 14, name "Hungarian Bike Map"

### 2. `config/process-bike.lua`

**Relations** (`route=bicycle` or `route=mtb`):
- Extract: `network` (icn/ncn/rcn/lcn/mtb), `ref`, `name`, `colour`
- Emit to `cycling_routes` layer
- Reject: hiking, foot, bus, and all others

**Ways — `cycling` layer:**
- `highway=cycleway` → `type=cycleway`
- `highway=path/track` with `bicycle=designated/yes` → `type=mtb_path`
- `highway=path/track` with `mtb:scale=*` → `type=mtb_trail`, extract `mtb:scale`
- Extract: `surface` (paved/unpaved distinction), `oneway:bicycle`, `smoothness`

**Ways — `roads` layer** (road context for cyclists):
- All `highway=*` as before, plus:
- Extract `bicycle` access tag: `yes`, `no`, `designated`, `dismount`
- Extract `cycleway`, `cycleway:left`, `cycleway:right` (lane markings)
- Extract `surface` (important for route planning)
- Roads with `bicycle=no` or `access=no + bicycle not exempted` → flag as `bike_forbidden=yes`

**Nodes (POIs):**
- `amenity=bicycle_repair_station` → `type=bike_repair`
- `amenity=bicycle_rental` → `type=bike_rental`
- `amenity=bicycle_parking` → `type=bike_parking`
- `amenity=drinking_water` → `type=drinking_water`

Drop entirely: OSMC parsing, `sac_scale`, `trail_visibility`, hiking relation handling

### 3. `www/style-bike.json`

Base: copy `style.json`, then replace trail/hiking layers.

**`cycling` layer — physical ways:**

| Type | Style | Color |
|------|-------|-------|
| `cycleway` | solid line, 3px | `#1a73e8` (blue) |
| `mtb_trail` (scale 0–1) | solid line, 2px | `#2e7d32` (dark green) |
| `mtb_trail` (scale 2–3) | dashed line, 2px | `#f57c00` (orange) |
| `mtb_trail` (scale 4–6) | dashed line, 2px | `#c62828` (red) |
| `mtb_path` | solid line, 2px | `#558b2f` (green) |

Surface unpaved modifier: switch solid → dashed for `cycleway` and `mtb_path` types.

**`roads` layer — bike access overlay** (additional sublayer on top of roads):
- `bike_forbidden=yes`: thin red strikethrough / red road casing
- Roads with `cycleway=lane/track`: thin blue parallel line rendered on road

**`cycling_routes` layer — route relations** (rendered with `line-offset`):

| Network | Color | Offset | Width |
|---------|-------|--------|-------|
| `icn` / `ncn` (EuroVelo / national) | `#0d47a1` (dark blue) | 6px | 4px |
| `rcn` (regional) | `#1565c0` (blue) | 4px | 3px |
| `lcn` (local) | `#42a5f5` (light blue) | 3px | 2px |
| `mtb` network | `#6a1b9a` (purple) | 4px | 3px |

Route ref labels shown at low density along the offset line.

**Keep from hiking style**: hillshade, terrain-rgb source, contours, base landuse/water/roads layers.
**Remove**: hiking-routes, physical-paths, OSMC trail color logic.

### 4. `www/bike.html`

Copy `index.html`, change:
- Style URL → `style-bike.json`
- Default center/zoom can stay the same
- Update UI controls: keep Hillshade toggle, 3D Terrain toggle
- Add a legend panel showing cycling layer colors (optional, can be done later)

### 5. Makefile targets

```makefile
generate-bike:
    @echo "Generating bike PMTiles..."
    @./scripts/generate-bike.sh

bike: generate-bike
```

### 6. `scripts/generate-bike.sh`

Copy `scripts/generate-tiles.sh`, substitute:
- Config: `config-bike.json` + `process-bike.lua`
- Output: `tiles/hungary-bike.pmtiles`

### 7. Output

`tiles/hungary-bike.pmtiles` (~200–400 MB estimated) served by existing nginx at `/tiles/hungary-bike.pmtiles` — no nginx changes needed.

Viewer at `http://localhost:8080/bike.html`.

---

## OSM Data Notes

Key OSM tags used:
- `route=bicycle` + `network=icn/ncn/rcn/lcn` — cycling route relations
- `route=mtb` — MTB route relations
- `highway=cycleway` — dedicated cycle path
- `cycleway=lane/track/shared_lane` — bike infrastructure on roads
- `mtb:scale=0–6` — MTB difficulty (0=easy, 6=extreme)
- `bicycle=no` — forbidden for cyclists
- `surface=asphalt/concrete/gravel/dirt/…` — surface type
- `smoothness=*` — optional surface quality
