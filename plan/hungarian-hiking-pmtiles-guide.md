# Hungarian Hiking Maps with PMTiles

A complete guide to generating and serving vector tiles for Hungarian hiking trails using PMTiles, Tilemaker, and nginx.

## Overview

This guide covers:
- Setting up the toolchain (Tilemaker, PMTiles)
- Downloading and preparing Hungarian OSM data
- Generating hiking-focused vector tiles
- Converting to PMTiles format
- Serving with nginx on your VPS
- Integrating with MapLibre GL JS

## Prerequisites

- Linux VPS with at least 4GB RAM (8GB recommended)
- 20GB free disk space
- nginx installed
- Basic command line familiarity

## Part 1: Installing Tools

### 1.1 Install Tilemaker

```bash
# Install dependencies
sudo apt update
sudo apt install -y build-essential liblua5.1-0-dev libprotobuf-dev \
    protobuf-compiler libsqlite3-dev libboost-program-options-dev \
    libboost-filesystem-dev libboost-system-dev libboost-iostreams-dev \
    rapidjson-dev libshp-dev git cmake

# Clone and build Tilemaker
cd ~
git clone https://github.com/systemed/tilemaker.git
cd tilemaker
make
sudo make install

# Verify installation
tilemaker --help
```

### 1.2 Install PMTiles CLI

```bash
# Download the latest PMTiles CLI
cd ~
wget https://github.com/protomaps/go-pmtiles/releases/download/v1.19.0/go-pmtiles_1.19.0_Linux_x86_64.tar.gz
tar xzf go-pmtiles_1.19.0_Linux_x86_64.tar.gz
sudo mv pmtiles /usr/local/bin/
sudo chmod +x /usr/local/bin/pmtiles

# Verify installation
pmtiles --help
```

### 1.3 Install GDAL (for contour generation, optional)

```bash
sudo apt install -y gdal-bin python3-gdal
```

## Part 2: Downloading Source Data

### 2.1 Get Hungarian OSM Data

```bash
# Create working directory
mkdir -p ~/hiking-tiles
cd ~/hiking-tiles

# Download Hungary extract from Geofabrik
wget https://download.geofabrik.de/europe/hungary-latest.osm.pbf

# File size: ~500MB
```

### 2.2 Get Elevation Data (Optional but Recommended)

For contour lines and hillshading:

```bash
# Download SRTM data for Hungary
# You can get this from various sources:
# - NASA SRTM: https://srtm.csi.cgiar.org/
# - EU-DEM: https://land.copernicus.eu/imagery-in-situ/eu-dem

# Example with EU-DEM (adjust URLs based on Hungarian coverage)
# Download tiles covering Hungary (roughly N45-49, E16-23)
# This step depends on your specific needs
```

## Part 3: Configuring Tilemaker for Hiking Maps

### 3.1 Create Hiking-Specific Config

Create `config-hiking.json`:

```json
{
  "layers": {
    "landuse": {
      "minzoom": 7,
      "maxzoom": 14
    },
    "waterway": {
      "minzoom": 8,
      "maxzoom": 14
    },
    "water": {
      "minzoom": 6,
      "maxzoom": 14
    },
    "roads": {
      "minzoom": 8,
      "maxzoom": 14
    },
    "trails": {
      "minzoom": 10,
      "maxzoom": 14
    },
    "pois": {
      "minzoom": 12,
      "maxzoom": 14
    },
    "buildings": {
      "minzoom": 13,
      "maxzoom": 14
    },
    "place_labels": {
      "minzoom": 3,
      "maxzoom": 14
    },
    "boundaries": {
      "minzoom": 3,
      "maxzoom": 14
    }
  },
  "settings": {
    "minzoom": 6,
    "maxzoom": 14,
    "basezoom": 14,
    "include_ids": false,
    "compress": "gzip",
    "combine_below": 14,
    "name": "Hungarian Hiking Map",
    "version": "1.0",
    "description": "Vector tiles for Hungarian hiking trails"
  }
}
```

### 3.2 Create Lua Processing Script

Create `process-hiking.lua`:

```lua
-- Tilemaker Lua config for Hungarian hiking maps

-- Define layers
node_keys = { "amenity", "shop", "tourism", "natural", "place", "man_made" }
way_keys = { "highway", "waterway", "natural", "landuse", "leisure", "boundary", "building" }

-- Initialize
function init_function()
end

-- Process nodes (points of interest)
function node_function(node)
    local amenity = node:Find("amenity")
    local tourism = node:Find("tourism")
    local natural = node:Find("natural")
    local place = node:Find("place")
    
    -- Hiking-relevant POIs
    if tourism == "alpine_hut" or tourism == "wilderness_hut" or 
       amenity == "shelter" or tourism == "viewpoint" or
       amenity == "drinking_water" or natural == "spring" or
       natural == "peak" or natural == "saddle" or natural == "cave_entrance" then
        
        local layer = LayerAsCentroid("pois")
        layer:Attribute("type", tourism or amenity or natural)
        
        local name = node:Find("name")
        if name ~= "" then
            layer:Attribute("name", name)
        end
        
        local ele = node:Find("ele")
        if ele ~= "" then
            layer:AttributeNumeric("elevation", tonumber(ele))
        end
    end
    
    -- Place labels
    if place ~= "" then
        local layer = LayerAsCentroid("place_labels")
        layer:Attribute("type", place)
        layer:Attribute("name", node:Find("name"))
        
        local population = node:Find("population")
        if population ~= "" then
            layer:AttributeNumeric("population", tonumber(population))
        end
        layer:MinZoom(place == "city" and 6 or place == "town" and 8 or 10)
    end
end

-- Process ways (trails, roads, areas)
function way_function(way)
    local highway = way:Find("highway")
    local waterway = way:Find("waterway")
    local natural = way:Find("natural")
    local landuse = way:Find("landuse")
    local leisure = way:Find("leisure")
    local boundary = way:Find("boundary")
    local building = way:Find("building")
    
    -- Trails (most important for hiking maps)
    if highway == "path" or highway == "footway" or highway == "cycleway" or
       highway == "bridleway" or highway == "track" or highway == "steps" then
        
        local layer = Layer("trails", false)
        layer:Attribute("type", highway)
        
        local name = way:Find("name")
        if name ~= "" then
            layer:Attribute("name", name)
        end
        
        -- Trail markings and difficulty
        local sac_scale = way:Find("sac_scale")
        if sac_scale ~= "" then
            layer:Attribute("difficulty", sac_scale)
        end
        
        local trail_visibility = way:Find("trail_visibility")
        if trail_visibility ~= "" then
            layer:Attribute("visibility", trail_visibility)
        end
        
        -- Hungarian hiking trail colors (osmc:symbol, ref, color)
        local osmc = way:Find("osmc:symbol")
        if osmc ~= "" then
            layer:Attribute("osmc_symbol", osmc)
        end
        
        local ref = way:Find("ref")
        if ref ~= "" then
            layer:Attribute("ref", ref)
        end
        
        local color = way:Find("color")
        if color ~= "" then
            layer:Attribute("color", color)
        end
        
        -- Surface type
        local surface = way:Find("surface")
        if surface ~= "" then
            layer:Attribute("surface", surface)
        end
        
        layer:MinZoom(10)
        
    -- Roads (for context)
    elseif highway == "motorway" or highway == "trunk" or highway == "primary" or
           highway == "secondary" or highway == "tertiary" or highway == "unclassified" or
           highway == "residential" or highway == "service" then
        
        local layer = Layer("roads", false)
        layer:Attribute("type", highway)
        layer:Attribute("name", way:Find("name"))
        
        local surface = way:Find("surface")
        if surface ~= "" then
            layer:Attribute("surface", surface)
        end
        
        layer:MinZoom(highway == "motorway" and 8 or highway == "primary" and 9 or 10)
    end
    
    -- Waterways
    if waterway ~= "" then
        local layer = Layer("waterway", false)
        layer:Attribute("type", waterway)
        layer:Attribute("name", way:Find("name"))
        layer:MinZoom(waterway == "river" and 8 or 10)
    end
    
    -- Water bodies, forests, etc. (filled areas)
    if natural == "water" or landuse == "reservoir" then
        local layer = Layer("water", true)
        layer:Attribute("type", natural or landuse)
        layer:MinZoom(9)
        
    elseif natural == "wood" or landuse == "forest" then
        local layer = Layer("landuse", true)
        layer:Attribute("type", "forest")
        layer:MinZoom(10)
        
    elseif landuse == "grass" or landuse == "meadow" or 
           natural == "grassland" or leisure == "park" then
        local layer = Layer("landuse", true)
        layer:Attribute("type", landuse or natural or leisure)
        layer:MinZoom(11)
        
    elseif landuse == "farmland" or landuse == "orchard" or landuse == "vineyard" then
        local layer = Layer("landuse", true)
        layer:Attribute("type", landuse)
        layer:MinZoom(11)
    end
    
    -- Buildings
    if building ~= "" then
        local layer = Layer("buildings", true)
        layer:MinZoom(13)
    end
    
    -- Boundaries (administrative)
    if boundary == "administrative" then
        local admin_level = tonumber(way:Find("admin_level"))
        if admin_level and admin_level <= 8 then
            local layer = Layer("boundaries", false)
            layer:AttributeNumeric("admin_level", admin_level)
            layer:MinZoom(admin_level <= 4 and 3 or admin_level <= 6 and 6 or 8)
        end
    end
end

-- Not processing multipolygon relations for simplicity
-- Add if needed for complex areas
function exit_function()
end
```

## Part 4: Generate Tiles

### 4.1 Run Tilemaker

```bash
cd ~/hiking-tiles

# Generate MBTiles (this will take 10-30 minutes depending on your VPS)
tilemaker --input hungary-latest.osm.pbf \
  --output hungary-hiking.mbtiles \
  --config config-hiking.json \
  --process process-hiking.lua

# Check the output
ls -lh hungary-hiking.mbtiles
# Should be 2-6GB depending on detail level
```

### 4.2 Convert to PMTiles

```bash
# Convert MBTiles to PMTiles format
pmtiles convert hungary-hiking.mbtiles hungary-hiking.pmtiles

# Verify the PMTiles file
pmtiles show hungary-hiking.pmtiles

# Optional: Remove the MBTiles file to save space
rm hungary-hiking.mbtiles
```

### 4.3 Optimize PMTiles (Optional)

```bash
# PMTiles supports optimization for better HTTP range request performance
# This is automatic in newer versions, but you can verify:
pmtiles verify hungary-hiking.pmtiles
```

## Part 5: Configure nginx

### 5.1 Prepare Directory Structure

```bash
# Create directory for tiles
sudo mkdir -p /var/www/tiles
sudo cp hungary-hiking.pmtiles /var/www/tiles/
sudo chown -R www-data:www-data /var/www/tiles
```

### 5.2 Configure nginx

Create `/etc/nginx/sites-available/tiles`:

```nginx
# HTTP/2 support recommended for better performance
server {
    listen 80;
    listen [::]:80;
    server_name tiles.yourdomain.com;  # Replace with your domain
    
    # Redirect to HTTPS (recommended)
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name tiles.yourdomain.com;  # Replace with your domain
    
    # SSL configuration (adjust paths to your certificates)
    ssl_certificate /etc/letsencrypt/live/tiles.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/tiles.yourdomain.com/privkey.pem;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # CORS headers (required for MapLibre to fetch tiles)
    add_header Access-Control-Allow-Origin "*" always;
    add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS" always;
    add_header Access-Control-Allow-Headers "Range" always;
    add_header Access-Control-Expose-Headers "Content-Length, Content-Range" always;
    
    # Handle OPTIONS requests
    if ($request_method = 'OPTIONS') {
        add_header Access-Control-Allow-Origin "*" always;
        add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Range" always;
        add_header Access-Control-Max-Age 1728000;
        add_header Content-Type "text/plain; charset=utf-8";
        add_header Content-Length 0;
        return 204;
    }
    
    # Root directory for tiles
    root /var/www/tiles;
    
    # PMTiles location
    location / {
        # Enable range requests (CRITICAL for PMTiles)
        add_header Accept-Ranges bytes always;
        
        # Cache control for tiles
        expires 7d;
        add_header Cache-Control "public, immutable";
        
        # Enable sendfile for better performance
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        
        # Gzip already compressed, so don't re-compress
        gzip off;
    }
    
    # Optional: serve a viewer page
    location = /viewer {
        alias /var/www/tiles/viewer.html;
    }
    
    # Logging
    access_log /var/log/nginx/tiles-access.log;
    error_log /var/log/nginx/tiles-error.log;
}
```

### 5.3 Enable and Test nginx Configuration

```bash
# Enable the site
sudo ln -s /etc/nginx/sites-available/tiles /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### 5.4 Setup SSL with Let's Encrypt (Recommended)

```bash
# Install certbot
sudo apt install -y certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d tiles.yourdomain.com

# Auto-renewal is usually set up automatically
# Verify with:
sudo certbot renew --dry-run
```

## Part 6: Integrate with MapLibre GL JS

### 6.1 Basic HTML/JS Example

Create a simple viewer to test your tiles:

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Hungarian Hiking Map</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <script src="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js"></script>
    <link href="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css" rel="stylesheet">
    <script src="https://unpkg.com/pmtiles@3.0.7/dist/pmtiles.js"></script>
    <style>
        body { margin: 0; padding: 0; }
        #map { position: absolute; top: 0; bottom: 0; width: 100%; }
    </style>
</head>
<body>
    <div id="map"></div>
    <script>
        // Register PMTiles protocol
        let protocol = new pmtiles.Protocol();
        maplibregl.addProtocol("pmtiles", protocol.tile);

        // Initialize map
        const map = new maplibregl.Map({
            container: 'map',
            center: [19.5, 47.2], // Budapest area
            zoom: 8,
            style: {
                version: 8,
                sources: {
                    'hungary-hiking': {
                        type: 'vector',
                        url: 'pmtiles://https://tiles.yourdomain.com/hungary-hiking.pmtiles',
                        attribution: '© OpenStreetMap contributors'
                    }
                },
                layers: [
                    // Background
                    {
                        id: 'background',
                        type: 'background',
                        paint: {
                            'background-color': '#f8f4f0'
                        }
                    },
                    // Water
                    {
                        id: 'water',
                        type: 'fill',
                        source: 'hungary-hiking',
                        'source-layer': 'water',
                        paint: {
                            'fill-color': '#a0c8f0'
                        }
                    },
                    // Landuse - forests
                    {
                        id: 'forest',
                        type: 'fill',
                        source: 'hungary-hiking',
                        'source-layer': 'landuse',
                        filter: ['==', 'type', 'forest'],
                        paint: {
                            'fill-color': '#d0e6c8',
                            'fill-opacity': 0.6
                        }
                    },
                    // Landuse - grass/meadow
                    {
                        id: 'grass',
                        type: 'fill',
                        source: 'hungary-hiking',
                        'source-layer': 'landuse',
                        filter: ['in', 'type', 'grass', 'meadow', 'park'],
                        paint: {
                            'fill-color': '#e8f4e0',
                            'fill-opacity': 0.4
                        }
                    },
                    // Waterways
                    {
                        id: 'waterway',
                        type: 'line',
                        source: 'hungary-hiking',
                        'source-layer': 'waterway',
                        paint: {
                            'line-color': '#a0c8f0',
                            'line-width': [
                                'interpolate', ['linear'], ['zoom'],
                                8, 0.5,
                                14, 2
                            ]
                        }
                    },
                    // Roads
                    {
                        id: 'roads',
                        type: 'line',
                        source: 'hungary-hiking',
                        'source-layer': 'roads',
                        paint: {
                            'line-color': [
                                'match',
                                ['get', 'type'],
                                'motorway', '#e892a2',
                                'trunk', '#f9b29c',
                                'primary', '#fcd6a4',
                                'secondary', '#f7fabf',
                                '#ffffff'
                            ],
                            'line-width': [
                                'interpolate', ['linear'], ['zoom'],
                                8, 0.5,
                                14, ['match', ['get', 'type'],
                                    'motorway', 4,
                                    'trunk', 3.5,
                                    'primary', 3,
                                    'secondary', 2.5,
                                    2
                                ]
                            ]
                        }
                    },
                    // Trails - base layer
                    {
                        id: 'trails',
                        type: 'line',
                        source: 'hungary-hiking',
                        'source-layer': 'trails',
                        paint: {
                            'line-color': '#d73f09',
                            'line-width': [
                                'interpolate', ['linear'], ['zoom'],
                                10, 1,
                                14, 3
                            ],
                            'line-dasharray': [
                                'match',
                                ['get', 'type'],
                                'path', [2, 2],
                                'steps', [1, 1],
                                [1, 0]
                            ]
                        }
                    },
                    // Trail labels
                    {
                        id: 'trail-labels',
                        type: 'symbol',
                        source: 'hungary-hiking',
                        'source-layer': 'trails',
                        filter: ['has', 'name'],
                        minzoom: 13,
                        layout: {
                            'text-field': ['get', 'name'],
                            'text-font': ['Open Sans Regular'],
                            'text-size': 11,
                            'symbol-placement': 'line',
                            'text-rotation-alignment': 'map'
                        },
                        paint: {
                            'text-color': '#d73f09',
                            'text-halo-color': '#fff',
                            'text-halo-width': 2
                        }
                    },
                    // Buildings
                    {
                        id: 'buildings',
                        type: 'fill',
                        source: 'hungary-hiking',
                        'source-layer': 'buildings',
                        minzoom: 13,
                        paint: {
                            'fill-color': '#d9d0c9',
                            'fill-opacity': 0.7
                        }
                    },
                    // POIs
                    {
                        id: 'pois',
                        type: 'circle',
                        source: 'hungary-hiking',
                        'source-layer': 'pois',
                        minzoom: 12,
                        paint: {
                            'circle-radius': [
                                'match',
                                ['get', 'type'],
                                'peak', 6,
                                'viewpoint', 5,
                                'alpine_hut', 5,
                                'shelter', 4,
                                3
                            ],
                            'circle-color': [
                                'match',
                                ['get', 'type'],
                                'peak', '#8b4513',
                                'viewpoint', '#ff6b6b',
                                'alpine_hut', '#4ecdc4',
                                'shelter', '#45b7d1',
                                'drinking_water', '#2e86de',
                                '#999'
                            ],
                            'circle-stroke-width': 1,
                            'circle-stroke-color': '#fff'
                        }
                    },
                    // POI labels
                    {
                        id: 'poi-labels',
                        type: 'symbol',
                        source: 'hungary-hiking',
                        'source-layer': 'pois',
                        filter: ['has', 'name'],
                        minzoom: 13,
                        layout: {
                            'text-field': ['get', 'name'],
                            'text-font': ['Open Sans Regular'],
                            'text-size': 10,
                            'text-anchor': 'top',
                            'text-offset': [0, 0.5]
                        },
                        paint: {
                            'text-color': '#333',
                            'text-halo-color': '#fff',
                            'text-halo-width': 1.5
                        }
                    },
                    // Place labels
                    {
                        id: 'place-labels',
                        type: 'symbol',
                        source: 'hungary-hiking',
                        'source-layer': 'place_labels',
                        layout: {
                            'text-field': ['get', 'name'],
                            'text-font': ['Open Sans Bold'],
                            'text-size': [
                                'match',
                                ['get', 'type'],
                                'city', 16,
                                'town', 14,
                                'village', 12,
                                10
                            ]
                        },
                        paint: {
                            'text-color': '#333',
                            'text-halo-color': '#fff',
                            'text-halo-width': 2
                        }
                    }
                ]
            }
        });

        // Add navigation controls
        map.addControl(new maplibregl.NavigationControl());
        
        // Add scale
        map.addControl(new maplibregl.ScaleControl());

        // Click handler for trail info
        map.on('click', 'trails', (e) => {
            const features = map.queryRenderedFeatures(e.point, {
                layers: ['trails']
            });
            
            if (!features.length) return;
            
            const feature = features[0];
            const props = feature.properties;
            
            let html = `<strong>${props.name || 'Unnamed trail'}</strong><br>`;
            html += `Type: ${props.type}<br>`;
            if (props.difficulty) html += `Difficulty: ${props.difficulty}<br>`;
            if (props.surface) html += `Surface: ${props.surface}<br>`;
            if (props.ref) html += `Ref: ${props.ref}<br>`;
            
            new maplibregl.Popup()
                .setLngLat(e.lngLat)
                .setHTML(html)
                .addTo(map);
        });

        // Change cursor on hover
        map.on('mouseenter', 'trails', () => {
            map.getCanvas().style.cursor = 'pointer';
        });
        
        map.on('mouseleave', 'trails', () => {
            map.getCanvas().style.cursor = '';
        });
    </script>
</body>
</html>
```

Save this as `/var/www/tiles/viewer.html` and access it at `https://tiles.yourdomain.com/viewer`

## Part 7: Performance Optimization

### 7.1 nginx Caching

Add to your nginx config inside the `server` block:

```nginx
# Define cache path
proxy_cache_path /var/cache/nginx/tiles levels=1:2 keys_zone=tiles_cache:10m max_size=10g inactive=7d use_temp_path=off;

location ~ \.pmtiles$ {
    # ... existing config ...
    
    # Enable caching
    proxy_cache tiles_cache;
    proxy_cache_valid 200 7d;
    proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
    add_header X-Cache-Status $upstream_cache_status;
}
```

### 7.2 HTTP/2 and Compression

Already enabled in the config above, but verify:

```bash
# Check HTTP/2 is working
curl -I --http2 https://tiles.yourdomain.com/hungary-hiking.pmtiles
```

### 7.3 Monitor Performance

```bash
# Watch access logs
sudo tail -f /var/log/nginx/tiles-access.log

# Monitor cache hit ratio
sudo tail -f /var/log/nginx/tiles-access.log | grep "X-Cache"
```

## Part 8: Updating Your Tiles

### 8.1 Create Update Script

Create `~/hiking-tiles/update-tiles.sh`:

```bash
#!/bin/bash
set -e

WORK_DIR="$HOME/hiking-tiles"
TILES_DIR="/var/www/tiles"
BACKUP_DIR="$WORK_DIR/backups"

cd "$WORK_DIR"

echo "Downloading latest Hungary OSM data..."
wget -N https://download.geofabrik.de/europe/hungary-latest.osm.pbf

echo "Backing up current tiles..."
mkdir -p "$BACKUP_DIR"
sudo cp "$TILES_DIR/hungary-hiking.pmtiles" "$BACKUP_DIR/hungary-hiking-$(date +%Y%m%d).pmtiles"

echo "Generating new tiles..."
tilemaker --input hungary-latest.osm.pbf \
  --output hungary-hiking.mbtiles \
  --config config-hiking.json \
  --process process-hiking.lua

echo "Converting to PMTiles..."
pmtiles convert hungary-hiking.mbtiles hungary-hiking.pmtiles

echo "Deploying new tiles..."
sudo cp hungary-hiking.pmtiles "$TILES_DIR/"
sudo chown www-data:www-data "$TILES_DIR/hungary-hiking.pmtiles"

echo "Cleaning up..."
rm hungary-hiking.mbtiles

echo "Update complete!"
```

Make it executable:

```bash
chmod +x ~/hiking-tiles/update-tiles.sh
```

### 8.2 Schedule Monthly Updates (Optional)

```bash
# Edit crontab
crontab -e

# Add line to run on the 1st of each month at 2 AM
0 2 1 * * /home/youruser/hiking-tiles/update-tiles.sh >> /home/youruser/hiking-tiles/update.log 2>&1
```

## Part 9: Advanced Customization

### 9.1 Adding Custom Trail Data

If you have additional trail data (from GPS tracks, local sources, etc.):

```bash
# Convert GPX to GeoJSON
ogr2ogr -f GeoJSON custom-trails.geojson your-trails.gpx tracks

# Merge with OSM data or process separately
# You can add custom processing in the Lua script
```

### 9.2 Styling Variants

Create different style variants for different uses:
- Light theme (for daytime)
- Dark theme (for night hiking planning)
- High contrast (for accessibility)
- Satellite hybrid (combine with aerial imagery)

### 9.3 Contour Lines

To add elevation contours:

```bash
# Generate contours from DEM
gdaldem contour -a elev -i 20 srtm_hungary.tif contours.shp

# Convert to GeoJSON
ogr2ogr -f GeoJSON contours.geojson contours.shp

# Process with Tippecanoe for optimal tile generation
tippecanoe -o contours.pmtiles -Z8 -z14 contours.geojson

# Reference both PMTiles in your map style
```

## Part 10: Monitoring and Maintenance

### 10.1 Check Tile Performance

```bash
# Test random tile access
pmtiles show hungary-hiking.pmtiles --tile=10/550/710

# Check file structure
pmtiles verify hungary-hiking.pmtiles
```

### 10.2 Monitor nginx

```bash
# Check nginx status
sudo systemctl status nginx

# Monitor bandwidth usage
sudo vnstat -l -i eth0

# Check disk usage
df -h /var/www/tiles
```

### 10.3 Backup Strategy

```bash
# Backup tiles and configs
tar czf hiking-tiles-backup-$(date +%Y%m%d).tar.gz \
  /var/www/tiles/hungary-hiking.pmtiles \
  ~/hiking-tiles/config-hiking.json \
  ~/hiking-tiles/process-hiking.lua

# Store backups off-server (rsync, cloud storage, etc.)
```

## Troubleshooting

### Issue: Tiles not loading in browser

**Check:**
1. CORS headers are present: `curl -I https://tiles.yourdomain.com/hungary-hiking.pmtiles`
2. Range requests work: `curl -H "Range: bytes=0-1024" https://tiles.yourdomain.com/hungary-hiking.pmtiles`
3. Browser console for errors

### Issue: Tilemaker runs out of memory

**Solution:**
- Reduce maxzoom in config (14 → 13)
- Process smaller regions
- Add swap space: `sudo fallocate -l 4G /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`

### Issue: Slow tile generation

**Solution:**
- Use more threads: `tilemaker --threads=4 ...`
- Use SSD storage
- Simplify Lua processing

### Issue: PMTiles file too large

**Solution:**
- Reduce maxzoom
- Simplify geometries with `--bbox` option
- Remove less important features at lower zooms

## Performance Expectations

For your 60-80k daily pageviews:

- **Bandwidth**: PMTiles uses HTTP range requests efficiently. Expect 10-50KB per page view depending on zoom levels
- **Storage**: 2-6GB for all of Hungary at zoom 6-14
- **CPU**: Minimal - nginx serves static files
- **Memory**: PMTiles don't need to be loaded into memory

With proper nginx caching, your VPS should handle this traffic easily.

## Next Steps

1. **Test thoroughly** with different devices and network conditions
2. **Monitor performance** for the first few weeks
3. **Gather feedback** on missing trails or POIs
4. **Iterate on styling** based on user needs
5. **Add features** like search, routing, elevation profiles

## Additional Resources

- [PMTiles Documentation](https://docs.protomaps.com/pmtiles/)
- [Tilemaker Documentation](https://github.com/systemed/tilemaker/blob/master/docs/RUNNING.md)
- [MapLibre GL JS Documentation](https://maplibre.org/maplibre-gl-js/docs/)
- [OpenStreetMap Wiki - Hiking](https://wiki.openstreetmap.org/wiki/Hiking)
- [Hungarian OSM Community](https://wiki.openstreetmap.org/wiki/Hungary)

## License Notes

- **OpenStreetMap data**: © OpenStreetMap contributors, ODbL license
- **Your tiles**: Subject to ODbL - must attribute OSM
- **PMTiles format**: BSD license
- **Tilemaker**: MIT license

---

**Questions or issues?** Feel free to iterate on this guide based on your specific needs. Good luck with your Hungarian hiking map project!
