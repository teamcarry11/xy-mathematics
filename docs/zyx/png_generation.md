# Grainseed PNG Generation

The Graincard Generator now supports exporting grainseeds as optimized grayscale PNG images, suitable for Bitcoin Ordinals inscriptions.

## Features

- **Monospace Bitmap Font**: Uses a custom 8x8 bitmap font for pixel-perfect rendering.
- **Grayscale Output**: 8-bit grayscale PNGs for minimal file size.
- **Scaling**: Supports 1x, 2x, 3x scaling for better visibility.
- **Stalk-Only Mode**: Option to export just the ASCII plant visual.

## Usage

### Single Graincard
Generate a text file and a PNG image:
```bash
zig build graincard -- --seed 12025 --png --output graincard_12025.txt
```

### Batch Generation
Generate PNGs for a range of seeds:
```bash
zig build graincard -- --range 1-100 --png --output-dir output/
```

### Stalk Only (Best for Ordinals)
Generate only the plant visual (smaller file size, cleaner look):
```bash
zig build graincard -- --seed 12025 --png --png-stalk-only --output graincard_12025.txt
```

### Scaling
Generate a 2x larger image:
```bash
zig build graincard -- --seed 12025 --png --png-scale 2 --output graincard_12025.txt
```

## Technical Details

- **Font**: 8x8 pixel bitmap (Public Domain / CC0).
- **Resolution**:
  - Stalk Only (1x): ~584 x 160 pixels
  - Full Card (1x): ~584 x 800 pixels
- **File Size**:
  - Stalk Only: ~3-5 KB
  - Full Card: ~10-15 KB
  - **Ordinals Limit**: 400 KB (We are well within this!)

## Bitcoin Ordinals Optimization

For the "Grainseed" collection, we recommend:
1.  **Format**: PNG (8-bit grayscale)
2.  **Content**: Stalk Only (`--png-stalk-only`) or Full Card
3.  **Scale**: 1x or 2x (depending on desired display size)
4.  **Metadata**: Store the Seed ID and Rarity in the Ordinals metadata, while the image provides the visual proof.

## Implementation

- `src/graincard/png_generator.zig`: Core logic using `zigimg`.
- `src/graincard/font8x8.zig`: Embedded bitmap font data.
- `src/graincard/cli.zig`: CLI integration.
