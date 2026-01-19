.PHONY: help download generate up down restart logs clean

help:
	@echo "Hungarian Hiking Maps - Docker Setup"
	@echo ""
	@echo "Available commands:"
	@echo "  make download    - Download Hungarian OSM data"
	@echo "  make generate    - Generate PMTiles from OSM data"
	@echo "  make up          - Start the nginx server"
	@echo "  make down        - Stop the nginx server"
	@echo "  make restart     - Restart the nginx server"
	@echo "  make logs        - View nginx logs"
	@echo "  make clean       - Clean up temporary files"
	@echo "  make all         - Download, generate, and start server"
	@echo ""

download:
	@echo "Downloading Hungarian OSM data..."
	@./scripts/download.sh

generate:
	@echo "Generating PMTiles..."
	@./scripts/generate-tiles.sh

up:
	@echo "Starting nginx server..."
	@docker-compose up -d
	@echo ""
	@echo "Server started! View your map at:"
	@echo "  http://localhost:8080"
	@echo ""

down:
	@echo "Stopping nginx server..."
	@docker-compose down

restart:
	@echo "Restarting nginx server..."
	@docker-compose restart

logs:
	@docker-compose logs -f nginx

clean:
	@echo "Cleaning up temporary files..."
	@rm -f tiles/*.mbtiles
	@echo "Done!"

all: download generate up
	@echo ""
	@echo "=========================================="
	@echo "Setup complete!"
	@echo "=========================================="
	@echo ""
	@echo "View your map at: http://localhost:8080"
	@echo ""
