# Assets

## Icons

The application requires icons in multiple formats:

- **icon.png** - 512x512 PNG for general use
- **icon.ico** - Windows icon file (multi-resolution)
- **icon.icns** - macOS icon file (multi-resolution)

### Generating Icons

You can convert the SVG icon to required formats using:

```bash
# Install imagemagick if not already installed
# macOS: brew install imagemagick
# Windows: choco install imagemagick

# Convert SVG to PNG
convert icon.svg -resize 512x512 icon.png

# For Windows .ico (requires multiple sizes)
convert icon.svg -define icon:auto-resize=256,128,96,64,48,32,16 icon.ico

# For macOS .icns (use png2icns or iconutil)
# 1. Create iconset directory with required sizes
# 2. Use iconutil to convert to .icns
```

For now, the SVG file is used as a placeholder during development.
