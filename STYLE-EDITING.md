# Style Editing Guide

Your map style is now externalized to `www/style.json`, making it easy to edit visually with style editors.

## Option 1: Maputnik (Recommended)

**Maputnik** is a free, open-source visual editor for MapLibre styles.

### Online Editor (Easiest)

1. **Open Maputnik**: https://maputnik.github.io/editor/

2. **Load your style**:
   - Click "Open" in the top menu
   - Select "Load from URL"
   - Enter: `http://localhost:8080/style.json`
   - Click "Open URL"

3. **Edit visually**:
   - Click on layers to edit colors, widths, opacity, etc.
   - Add new layers with the "+" button
   - Reorder layers by dragging
   - Use the inspector (Cmd/Ctrl + I) to click features and see their properties

4. **Save your changes**:
   - Click "Export" at the top
   - Click "Download" to save the JSON
   - Replace `www/style.json` with your downloaded file
   - Hard refresh your map (`Ctrl+Shift+R`)

### Self-Hosted Maputnik (Better for Development)

Run Maputnik locally for faster editing:

```bash
# Using Docker/Podman
podman run -it --rm -p 8888:8888 maputnik/editor

# Then open: http://localhost:8888
```

Load your style from `http://localhost:8080/style.json` and edit away!

## Option 2: Manual JSON Editing

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

## Tips for Maputnik

1. **Use the inspector**: Click the inspector icon (or `Cmd/Ctrl+I`), then click on map features to see their properties and layers

2. **Test zoom levels**: Use the zoom slider to see how layers appear at different zoom levels

3. **Preview changes live**: Maputnik shows changes in real-time as you edit

4. **Data properties**: In Maputnik, you can see all available properties for each feature (like trail type, surface, name, etc.)

5. **Color picker**: Click on any color value to open a visual color picker

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

## Quick Start

1. Open https://maputnik.github.io/editor/
2. Load `http://localhost:8080/style.json`
3. Click on "trails" layer
4. Change colors, widths, patterns
5. Export → Download
6. Replace `www/style.json`
7. Refresh browser!

Happy styling! 🎨
