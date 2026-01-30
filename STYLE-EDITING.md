# Style Editing Guide

Your map style is in `www/style.json` and uses the `pmtiles://` protocol for serving tiles efficiently.

## Understanding the Three Layers of Control

Before editing styles, it's important to understand how zoom levels and features are controlled across three different files:

### 1. `config/process-hiking.lua` (Data Generation)
- **Purpose**: Controls what data gets **written into** the PMTiles file
- **MinZoom(X)**: Features only appear in tiles at zoom X and above
- **When to change**: Rarely - only when adding new feature types or changing data strategy
- **Impact**: Requires regenerating tiles (slow, 10-30 minutes)
- **Best practice**: Set MinZoom values **generously** (lower than you think you need)

Example:
```lua
if landuse == "forest" then
    MinZoom(7)  -- Include forests in tiles from zoom 7+
                -- Even if you plan to display them from zoom 9
end
```

### 2. `config/config-hiking.json` (Layer Configuration)
- **Purpose**: Layer-level zoom limits for tile generation
- **minzoom/maxzoom**: Per-layer zoom range for data generation
- **When to change**: Rarely - set conservatively once
- **Impact**: Requires regenerating tiles

Example:
```json
{
  "layers": {
    "landuse": {
      "minzoom": 7,
      "maxzoom": 14
    }
  }
}
```

### 3. `www/style.json` (Visual Display)
- **Purpose**: Controls how data is **displayed** in the browser
- **minzoom/maxzoom**: Client-side visibility control
- **paint**: Colors, widths, opacity, patterns
- **layout**: Labels, symbols, visibility
- **When to change**: Frequently - this is your main editing target
- **Impact**: Instant - just refresh browser (Ctrl+Shift+R)

Example:
```json
{
  "id": "forest",
  "type": "fill",
  "minzoom": 9,
  "paint": {
    "fill-color": "#228B22",
    "fill-opacity": 0.6
  }
}
```

### The Optimal Workflow

**Phase 1: Initial Data Setup** (do once or rarely)
```bash
# Edit process-hiking.lua with generous MinZoom values
vim config/process-hiking.lua

# Regenerate tiles
make generate
```

**Phase 2: Visual Iteration** (do frequently, no regeneration needed!)
```bash
# Start dev environment
make dev-up
make style-to-maputnik

# Edit in Maputnik or manually edit style.json
# Change colors, zoom levels, widths, opacity, etc.

# Convert back if using Maputnik
make style-from-maputnik

# Just refresh browser - changes are instant!
```

### Why This Matters

If you set `MinZoom(10)` in Lua but later want to show features at zoom 8, you **must regenerate tiles** (slow).

But if you set `MinZoom(7)` in Lua and `minzoom: 10` in style.json, you can later change style.json to `minzoom: 8` **instantly** by just refreshing your browser.

**Golden Rule**: Set Lua MinZoom values generously (lower zoom = earlier visibility). Do all fine-tuning in style.json where changes are instant.

---

## Important Note about Visual Editors

**Maputnik and other visual style editors do NOT support `pmtiles://` URLs.** They expect standard tile server URLs (like `https://example.com/{z}/{x}/{y}.pbf`).

Since this project serves PMTiles files directly via nginx (without a tile server), visual editors like Maputnik cannot load the map tiles for preview.

**Options:**
1. **Manual JSON editing** (recommended for this setup)
2. **Set up a tile server** (adds complexity - see below)

## Option 1: Manual JSON Editing (Recommended)

Edit `www/style.json` directly in your favorite text editor:

```bash
# Edit the style
nano www/style.json
# or
code www/style.json
```

After editing, hard refresh your browser (`Ctrl+Shift+R` or `Cmd+Shift+R`) to see changes.

## Style Structure

Your `style.json` contains:

- **version**: MapLibre style spec version (8)
- **glyphs**: URL template for font files
- **sources**: Data sources (your PMTiles file)
- **layers**: Visual layers (roads, trails, water, etc.)

Each layer has:
- **id**: Unique identifier
- **type**: fill, line, circle, symbol, etc.
- **source**: Which data source to use
- **source-layer**: Which layer from the PMTiles
- **paint**: Visual styling (colors, widths, opacity)
- **layout**: Layout properties (text fields, placement)
- **filter**: Which features to show

## Common Customizations

### Change Trail Color

In `style.json`, find the `trails` layer and change `line-color`:

```json
{
  "id": "trails",
  "type": "line",
  "paint": {
    "line-color": "#ff0000"  // Change to red
  }
}
```

### Adjust Water Color

```json
{
  "id": "water",
  "type": "fill",
  "paint": {
    "fill-color": "#3388ff"  // Brighter blue
  }
}
```

### Make Forests More Visible

```json
{
  "id": "forest",
  "type": "fill",
  "paint": {
    "fill-color": "#228B22",  // Forest green
    "fill-opacity": 0.8        // More opaque
  }
}
```

### Change Background Color

```json
{
  "id": "background",
  "type": "background",
  "paint": {
    "background-color": "#f5f5f5"  // Light gray
  }
}
```

### Add Dashed Lines for Paths

```json
{
  "id": "trails",
  "type": "line",
  "paint": {
    "line-color": "#d73f09",
    "line-width": 2,
    "line-dasharray": [2, 2]  // Dashed pattern
  }
}
```

## Option 2: Using Maputnik (Visual Editor)

We've created an automated workflow for visual style editing with Maputnik!

### Quick Start

```bash
# 1. Start development environment (tile server + Maputnik)
make dev-up

# 2. Convert your style to Maputnik-compatible format
make style-to-maputnik

# 3. Open Maputnik in your browser
# http://localhost:8888

# 4. In Maputnik:
#    - Click "Open" → "Load from URL"
#    - Enter: http://localhost:8080/style-maputnik.json
#    - Click "Open URL"

# 5. Edit visually:
#    - Change colors, line widths, opacity
#    - Add/remove layers
#    - Test at different zoom levels

# 6. When done:
#    - Click "Export" → "Download"
#    - Save as www/style-edited.json

# 7. Convert back to pmtiles:// format
make style-from-maputnik

# 8. Stop development environment
make dev-down

# 9. Refresh your browser to see changes!
```

### What This Does

The development environment starts:
- **PMTiles tile server** (port 8081) - Serves individual tiles from your PMTiles archive
- **Maputnik editor** (port 8888) - Visual style editor with live preview
- **Nginx server** (port 8080) - Your regular map viewer

The conversion scripts automatically:
- Convert `pmtiles://` URLs to standard tile URLs for Maputnik
- Convert back to `pmtiles://` URLs for production use
- Create backups of your style before changes

## Tips for Manual Editing

1. **Use a good JSON editor**: VS Code, nano with syntax highlighting, etc.

2. **Test in browser**: After each change, hard refresh (`Ctrl+Shift+R`) to see results

3. **Use browser DevTools**: Press `F12` and click on map features to see their properties in the console

4. **Start simple**: Change one color at a time, test, then move to the next

5. **Keep backups**: Always backup before major changes

## Debugging

If your map doesn't load after editing:

1. **Check JSON syntax**: Use a JSON validator (jsonlint.com)
2. **Check browser console**: `F12` → Console tab for errors
3. **Revert to backup**: Keep a copy of working `style.json`

```bash
# Make a backup before editing
cp www/style.json www/style.json.backup

# Restore if needed
cp www/style.json.backup www/style.json
```

## Advanced: Using Variables

You can define color variables for consistency:

```json
{
  "version": 8,
  "metadata": {
    "colors": {
      "primary": "#d73f09",
      "water": "#a0c8f0",
      "forest": "#d0e6c8"
    }
  },
  "layers": [...]
}
```

Then reference them in Maputnik using expressions.

## Resources

- [MapLibre Style Specification](https://maplibre.org/maplibre-style-spec/)
- [Maputnik Documentation](https://github.com/maputnik/editor/wiki)
- [MapLibre Expression Reference](https://maplibre.org/maplibre-style-spec/expressions/)
- [Color Picker](https://coolors.co/) for finding nice color schemes

## Quick Start for Manual Editing

1. Open `www/style.json` in your editor
2. Find the layer you want to change (search for layer `"id"`)
3. Modify the `"paint"` or `"layout"` properties
4. Save the file
5. Hard refresh your browser (`Ctrl+Shift+R`)
6. Repeat until satisfied!

**Pro tip:** Make small changes and test frequently. If something breaks, check the browser console (`F12`) for errors.

Happy styling! 🎨
