# Project Summary: Hungarian Hiking Maps with Docker

## Overview

This project provides a complete Docker-based solution for generating and serving Hungarian hiking trail vector tiles. It eliminates the need to manually compile Tilemaker and handles all the complexity through Docker containers.

## What Was Created

### 1. Docker Infrastructure
- **docker-compose.yml** - Runs nginx server for serving PMTiles
- Uses official Docker images for all tools (no manual compilation needed)

### 2. Automation Scripts
- **scripts/download.sh** - Downloads Hungarian OSM data (~500MB)
- **scripts/generate-tiles.sh** - Generates tiles using Tilemaker and PMTiles in Docker
- **scripts/update.sh** - Updates tiles with latest OSM data (with automatic backup)
- **scripts/check-setup.sh** - Verifies your setup is correct

### 3. Configuration Files
- **config/config-hiking.json** - Tilemaker layer definitions (trails, POIs, water, etc.)
- **config/process-hiking.lua** - Processing logic for Hungarian hiking trails
- **nginx/nginx.conf** - Web server config with CORS and HTTP range request support

### 4. Web Viewer
- **www/index.html** - Complete MapLibre GL JS viewer with hiking map styling
- Includes interactive trail popups, POI markers, and proper Hungarian trail rendering

### 5. Documentation
- **README.md** - Complete setup and deployment guide
- **Makefile** - Convenient shortcuts (make download, make generate, make up)
- **.gitignore** - Prevents committing large data files

## Directory Structure

```
pmtiles-server/
├── config/                    # Tilemaker configuration
├── data/                      # Downloaded OSM data (created on first run)
├── tiles/                     # Generated PMTiles (created on first run)
├── www/                       # Web viewer
├── nginx/                     # nginx configuration
├── scripts/                   # Automation scripts
├── docker-compose.yml         # Docker setup
├── Makefile                   # Command shortcuts
└── README.md                  # Full documentation
```

## Usage

### Quick Start (3 Commands)

```bash
./scripts/download.sh          # Download OSM data
./scripts/generate-tiles.sh    # Generate tiles (10-30 min)
docker-compose up -d           # Start server
```

Then open: http://localhost:8080

### Using Makefile

```bash
make all        # Do everything: download, generate, start server
make download   # Just download OSM data
make generate   # Just generate tiles
make up         # Just start server
make logs       # View server logs
make down       # Stop server
```

## Key Features

✓ **Zero Installation Hassle** - All tools run in Docker containers
✓ **No Manual Compilation** - Uses pre-built Docker images
✓ **Complete Solution** - From OSM data to working web map
✓ **Production Ready** - Proper CORS, caching, and range request support
✓ **Easy Updates** - Automated update script with backups
✓ **Customizable** - Edit configs to change layers, zoom levels, styling

## Docker Images Used

- `ghcr.io/systemed/tilemaker:master` - Vector tile generation from OSM data
- `ghcr.io/protomaps/go-pmtiles:latest` - MBTiles to PMTiles conversion
- `nginx:alpine` - Lightweight web server for serving tiles

## Output

After running the scripts, you get:

1. **hungary-hiking.pmtiles** - Optimized vector tile archive (2-6GB)
2. **Web viewer** - Interactive map at http://localhost:8080
3. **API access** - Direct PMTiles access at http://localhost:8080/tiles/hungary-hiking.pmtiles

## What's Included in the Map

- **Hiking Trails** - All paths, footways, tracks with Hungarian color markings
- **POIs** - Peaks, viewpoints, shelters, water sources, cave entrances
- **Base Map** - Roads, water bodies, forests, buildings, place labels
- **Metadata** - Trail difficulty (SAC scale), surface types, elevations

## Performance

- **File Size**: 2-6GB for all of Hungary (zoom 6-14)
- **Bandwidth**: 10-50KB per page view (efficient HTTP range requests)
- **Server Load**: Minimal (static file serving with nginx)
- **Scaling**: Can handle 60-80k daily pageviews easily

## Deployment Options

### Local Development
- Current setup works out of the box on port 8080

### Production VPS
1. Copy project to server
2. Run the scripts to generate tiles
3. Add SSL/TLS (via Caddy, Traefik, or Let's Encrypt)
4. Update PMTiles URL in www/index.html to use your domain

### With Existing Reverse Proxy
- Keep this setup running on port 8080
- Configure your reverse proxy to forward requests
- Ensure Range headers are passed through

## Customization

### Change Port
Edit `docker-compose.yml`:
```yaml
ports:
  - "3000:80"  # Change to desired port
```

### Adjust Zoom Levels
Edit `config/config-hiking.json`:
```json
"maxzoom": 13  // Lower for faster generation
```

### Modify Map Style
Edit `www/index.html` - change colors, layers, fonts, etc.

### Add Custom Features
Edit `config/process-hiking.lua` - add custom POI types or attributes

## Troubleshooting

Run the check script to verify setup:
```bash
./scripts/check-setup.sh
```

Common issues:
- **Docker not found**: Install Docker Desktop or Docker Engine
- **Permission denied**: Make scripts executable with `chmod +x scripts/*.sh`
- **Out of memory**: Lower maxzoom in config or add swap space
- **Tiles not loading**: Check browser console and nginx logs

## License

- OpenStreetMap data: ODbL license (attribution required)
- PMTiles format: BSD license
- Tilemaker: MIT license
- This setup: Use freely, attribution appreciated

## Next Steps

1. Generate your tiles with the provided scripts
2. Customize the map style to match your needs
3. Deploy to production with HTTPS
4. Set up automated updates (monthly via cron)
5. Add features like search, routing, or elevation profiles

---

**For detailed documentation, see README.md**
