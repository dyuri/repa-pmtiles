.PHONY: help download fonts setup generate contours up down restart logs clean all

help:
	@echo "Hungarian Hiking Maps - Docker Setup"
	@echo ""
	@echo "Available commands:"
	@echo "  make download    - Download Hungarian OSM data"
	@echo "  make fonts       - Download font glyphs for map labels"
	@echo "  make generate    - Generate PMTiles from OSM data"
	@echo "  make contours    - Generate elevation contour lines (optional)"
	@echo "  make up          - Start the nginx server"
	@echo "  make down        - Stop the nginx server"
	@echo "  make restart     - Restart the nginx server"
	@echo "  make logs        - View nginx logs"
	@echo "  make clean       - Clean up temporary files"
	@echo "  make setup       - Download OSM data and fonts"
	@echo "  make all         - Complete setup: download, fonts, generate, start server"
	@echo ""
	@echo "Topographic maps:"
	@echo "  make topo        - Full topographic setup with contours"
	@echo ""

download:
	@echo "Downloading Hungarian OSM data..."
	@./scripts/download.sh

fonts:
	@echo "Downloading font glyphs..."
	@./scripts/download-fonts.sh

setup: download fonts
	@echo ""
	@echo "Setup complete! OSM data and fonts downloaded."
	@echo "Next: Run 'make generate' to create tiles"

generate:
	@echo "Generating PMTiles..."
	@./scripts/generate-tiles.sh

contours:
	@echo "Generating contour lines..."
	@echo ""
	@echo "Step 1: Downloading DEM data..."
	@./scripts/download-dem.sh
	@echo ""
	@echo "Step 2: Generating contours..."
	@./scripts/generate-contours.sh 20
	@echo ""
	@echo "Contours complete! Update www/style.json to add contours."
	@echo "See CONTOURS.md for instructions."

topo: download fonts generate contours
	@echo ""
	@echo "=========================================="
	@echo "Topographic Map Setup Complete!"
	@echo "=========================================="
	@echo ""
	@echo "Generated files:"
	@echo "  - tiles/hungary-hiking.pmtiles (trails, POIs, landuse)"
	@echo "  - tiles/hungary-contours.pmtiles (elevation contours)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Update www/style.json to include contours (see CONTOURS.md)"
	@echo "  2. Run: make up"
	@echo "  3. Open: http://localhost:8080"
	@echo ""

up:
	@echo "Starting nginx server..."
	@podman compose up -d
	@echo ""
	@echo "Server started! View your map at:"
	@echo "  http://localhost:8080"
	@echo ""

down:
	@echo "Stopping nginx server..."
	@podman compose down

restart:
	@echo "Restarting nginx server..."
	@podman compose restart

logs:
	@podman compose logs -f nginx

clean:
	@echo "Cleaning up temporary files..."
	@rm -f tiles/*.mbtiles
	@echo "Done!"

all: download fonts generate up
	@echo ""
	@echo "=========================================="
	@echo "Setup complete!"
	@echo "=========================================="
	@echo ""
	@echo "View your map at: http://localhost:8080"
	@echo ""
