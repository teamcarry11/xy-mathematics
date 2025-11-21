# Graincard Technical Specification

## Overview

**Graincard** is a deterministic ASCII art generator that creates unique "trading cards" for ecological grain systems. Each card is 75 characters wide by 100 lines tall, featuring a procedurally generated grain stalk with ecological metadata.

## Card Dimensions

- **Total Size**: 75×100 characters
- **Content Area**: 73×98 characters (accounting for 1-char borders)
- **Border Style**: `+` corners, `-` horizontal, `|` vertical

## Card Structure

```
+-------------------------------------------------------------------------+
|  GRAINSEED #12345                                                      |
|  Rarity: rare (4%)                                                     |
|  ...header content...                                                  |
|                              [centered stalk]                          |
|  ...metrics...                                                         |
|  Companions: vetch, clover                                             |
|                  "Code that grows. Grain that lasts."                  |
+-------------------------------------------------------------------------+
```

### Sections

1. **Header** (left-aligned): Seed ID, rarity, type, season, physical stats
2. **Stalk Visual** (centered): ASCII art grain stalk (5-15 segments)
3. **Metrics Box** (left-aligned): Soil food web data, carbon sequestration, biodiversity
4. **Footer** (centered): Tagline

## Ecological Parameters

### Ecology Types

Twelve distinct ecology types, each influencing companion plants and rarity:

- `living_soil` - Focus on soil biology
- `carbon_cycle` - Carbon sequestration emphasis
- `rhizosphere` - Root zone specialists
- `polyculture` - Multiple crop species
- `wild_edges` - Biodiversity corridors
- `minimal_disturbance` - No-till systems
- `cover_crop` - Soil protection
- `nutrient_recycler` - Closed-loop systems
- `selective_weeding` - Beneficial "weeds"
- `fungal_network` - Mycorrhizal emphasis
- `residue_builder` - Organic matter focus
- `ecosystem_immune` - Disease suppression

### Seasons

- `spring`, `summer`, `autumn`, `winter`, `year_round`

### Soil Types

- `rich_loam`, `sandy_loam`, `clay_rich`, `volcanic`, `frozen`, `desert_sand`

### Weather Conditions

- `clear`, `rainy`, `windy`, `frost`, `hot`, `moonlit`

## Companion Plants

Ten companion plant species, generated based on ecology type:

- `clover` - Universal nitrogen fixer
- `vetch` - Legume cover crop
- `field_pea` - Nitrogen-rich polyculture
- `chicory` - Deep-rooted mineral miner
- `plantain` - Beneficial "weed"
- `creeping_thyme` - Ground cover
- `yarrow` - Medicinal/beneficial insect attractor
- `fennel` - Beneficial insect habitat
- `dandelion` - Dynamic accumulator
- `lambs_quarters` - Edible volunteer

### Companion Generation Logic

- **Base**: Random chance for `clover`
- **Ecology-specific**:
  - `polyculture`: vetch, field_pea
  - `wild_edges`: yarrow, chicory
  - `minimal_disturbance`: creeping_thyme
  - `cover_crop`: vetch + clover (guaranteed)
  - `selective_weeding`: dandelion, plantain
  - `ecosystem_immune`: yarrow + fennel + dandelion (guaranteed)
- **Random biodiversity**: 20% chance of additional random companion

## Stalk Generation

### Physical Characteristics

- **Height**: 5-15 segments (random)
- **Lean**: -3 to +3 (left/right sway)
- **Leaves**: 0-9 leaves, placed on `|` character as `(|` or `|)`

### Visual Structure

```
      .           ← Grain head
    \ | /
   --(@)--
    / | \
      |
     (|           ← Leaf (left)
      |
      |)          ← Leaf (right)
    ~~~~~         ← Roots
```

### Sway Algorithm

Each segment has a random sway of -1, 0, or +1, accumulated and clamped to [-3, +3]. Indent adjusts based on cumulative lean.

## Rarity System

### Rarity Calculation

Rarity score (0-100) based on:

- **Perfect straight** (lean = 0): +30
- **Maximum height** (≥14 segments): +20
- **Many leaves** (≥6): +25
- **Extreme lean** (|lean| ≥ 3): +15
- **Special ecology**:
  - `ecosystem_immune`: +20
  - `minimal_disturbance`: +15

### Rarity Tiers

| Tier | Score Range | Percentage |
|------|-------------|------------|
| Mythic | 90+ | <0.5% |
| Legendary | 75-89 | 1% |
| Ultra Rare | 60-74 | 1% |
| Rare | 40-59 | 4% |
| Uncommon | 20-39 | 7% |
| Common | 0-19 | 12% |

## Soil Metrics

All metrics are deterministically generated from the seed:

- **Mycorrhizal Fungi**: 200-2400 ft/gram soil
- **Bacterial Biomass**: 400-1800 μg/g
- **Protozoa Count**: 5000-25000 per gram
- **Nematode Diversity**: 8-47 species
- **Earthworm Activity**: 3-18 casts per sq ft
- **Soil Respiration**: 0.8-2.8 mg CO₂/g/day
- **Living Root Coverage**: 180-365 days/year
- **Carbon Sequestration**: 0-1.2% annually
- **Pest Damage**: 0-5% crop damage
- **Biodiversity Index**: 3.0-10.0 scale

## PNG Output

### Format

- **Font**: 8x8 bitmap monospace (custom `font8x8.zig`)
- **Scale**: 1x, 2x, or 3x (configurable via `--png-scale`)
- **Mode**: Full card or stalk-only (`--png-stalk-only`)
- **Output**: PNG image via `zigimg` library

### Usage

```bash
# Generate PNG at 2x scale
zig build graincard -- --seed 12345 --output graincard.txt --png --png-scale 2

# Generate stalk-only PNG
zig build graincard -- --seed 12345 --png --png-stalk-only
```

## CLI Interface

### Single Card Generation

```bash
zig build graincard -- --seed <u64> [--output <path>] [--png] [--png-scale <1-3>]
```

### Batch Generation

```bash
zig build graincard -- --range <start>-<end> --output-dir <path> [--png]
```

### Options

- `--seed <u64>`: Seed number (required for single)
- `--output <path>`: Output file path
- `--range <start>-<end>`: Generate multiple cards
- `--output-dir <path>`: Directory for batch output
- `--ecology <type>`: Force specific ecology type
- `--season <season>`: Force specific season
- `--format <txt|json>`: Output format (default: txt)
- `--png`: Generate PNG image
- `--png-scale <1-3>`: Scale factor for PNG
- `--png-stalk-only`: Generate only stalk visual in PNG

## Implementation Files

- `src/graincard/types.zig` - Core data structures
- `src/graincard/ecology.zig` - Ecological parameter generation
- `src/graincard/layout.zig` - 75×100 layout engine with padding/centering
- `src/graincard/cli.zig` - Command-line interface
- `src/graincard/png_generator.zig` - ASCII-to-PNG conversion
- `src/graincard/font8x8.zig` - Bitmap font data
- `src/graincard.zig` - Main entry point

## Determinism

All generation is **fully deterministic** based on the seed value. The same seed will always produce:

- Identical stalk height, lean, and leaf placement
- Same ecology type, season, soil type, weather
- Same companion plants
- Identical soil metrics
- Same rarity score

This ensures reproducibility for Bitcoin Ordinals or NFT use cases.

## Future Enhancements

- [ ] Memory leak fix: Free companions slice in `EcologicalParams`
- [ ] JSON output format implementation
- [ ] Additional companion plant species
- [ ] Weather-based visual variations (rain, snow effects)
- [ ] Animated GIF output for growth sequences
- [ ] SVG output for scalable graphics
