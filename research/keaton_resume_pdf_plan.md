# Keaton Dunsford Resume PDF: Grain Bubble Design Plan

**Date**: 2025-12-07  
**Tool**: Grain Bubble (Grain OS Design Tool)  
**Source Data**: `keaton_profile.zig`  
**Output**: 5-6 page aesthetic PDF resume with creator platform mockups

---

## Design Vision

**Aesthetic**: Unorthodox, glitchy-dark-neon-colorful, textured hemp paper  
**Philosophy**: Visual design ability + technical depth + creative vision  
**Inspiration**: Lucy Guo's Passes (authenticity, bubbliness, anti-PR approach)

---

## Page Structure (5-6 Pages)

### Page 1: Cover / Identity
- **Background**: Grainy off-white hemp paper texture (subtle noise pattern)
- **Content**:
  - Large glitchy-dark-neon portrait (AI-edited Instagram image)
  - Name: "Keaton Dunsford" (neon typography, slight glitch effect)
  - Tagline: "Systems Architect | Grain OS | Patient Discipline"
  - Key values as visual bubbles: #vegan #zig #sol
  - Small text: "Bridges technical/spiritual, structured/exploratory"

### Page 2: Core Profile (from keaton_profile.zig)
- **Background**: Same grainy hemp texture
- **Content**:
  - Description text (from profile)
  - Values visualization (bubble diagram)
  - Inspirations grid (Vic Dicara, Natalie Vais, Gary Yourofsky, Will Tuttle, Lucy Guo)
  - Musical preferences as visual rhythm patterns

### Page 3: Work & Projects
- **Background**: Grainy hemp texture
- **Content**:
  - Grain OS architecture diagram (bubble flow)
  - Multi-agent system visualization
  - Research directory concept
  - Technical achievements (zero technical debt, Grain Style)

### Page 4: Creator Platform Mockup - Private Spaces
- **Background**: Dark neon gradient overlay on hemp texture
- **Content**:
  - Mockup: "Grain OS Creator Platform" (inspired by Passes)
  - Private digital social spaces UI mockup
  - Features:
    - Intimate fan connections
    - Safe, private spaces
    - Real-time messaging
    - Content sharing
  - Visual: Glitchy neon UI elements, rounded "bubble" components

### Page 5: Creator Platform Mockup - Livestreaming & Payments
- **Background**: Dark neon gradient overlay on hemp texture
- **Content**:
  - Livestreaming interface mockup
  - Micropayment system visualization:
    - Grainbank (MMT fiat) integration
    - Grainsoul (Grain Solana) integration
  - Real-time tipping UI during streams
  - Payment flow diagram (bubble connections)

### Page 6: Creator Platform Mockup - Financial Dashboard
- **Background**: Dark neon gradient overlay on hemp texture
- **Content**:
  - Financial dashboard mockup
  - Features:
    - Total $1M+ diversified accredited-investor equity assets
    - Context: National citizenship display
    - Connection to sovereign government departments
    - Fiat currency context (which sovereign issues currency)
  - Visual: Data visualization bubbles, neon charts, glitchy aesthetics

---

## Technical Implementation Plan

### Step 1: Background Texture Generation
```zig
// Create grainy hemp paper texture
// - Off-white base color (#F5F5DC or similar)
// - Noise pattern overlay (subtle grain)
// - Can be done via Grain Bubble canvas with noise pattern shapes
```

### Step 2: Load keaton_profile.zig Data
```zig
// Parse keaton_profile.zig structure
// Extract:
// - name, description
// - values array
// - inspirations (technical, spiritual, ethical, creative)
// - music preferences
// - work context
```

### Step 3: Image Integration
```zig
// Load Instagram portrait images
// Apply glitchy-dark-neon effects:
// - Dark base with neon color overlays
// - Glitch effects (RGB channel separation, scan lines)
// - Can be done via Grain Bubble image import + overlay shapes
```

### Step 4: Page Layout Creation
```zig
// For each page (1-6):
// 1. Create canvas layer for background texture
// 2. Add content layers (text, shapes, images)
// 3. Apply neon glitch effects to key elements
// 4. Export to PDF
```

### Step 5: Mockup Design (Pages 4-6)
```zig
// Creator Platform UI Mockups:
// - Use Grain Bubble's rounded "bubble" components
// - Dark background with neon accents
// - Glitchy effects on interactive elements
// - Show: private spaces, livestreaming, payments, dashboard
```

---

## Grain Bubble Workflow

### 1. Create Background Texture Component
- Component: "hemp_paper_texture"
- Variants: base, with_neon_overlay
- Design tokens: off_white_color, grain_noise_level

### 2. Create Typography Components
- Component: "neon_glitch_text"
- Variants: large_title, body_text, small_label
- Design tokens: neon_colors (cyan, magenta, yellow), glitch_intensity

### 3. Create Portrait Frame Component
- Component: "glitchy_portrait_frame"
- Variants: large, medium, small
- Design tokens: glitch_effect_strength, neon_border_color

### 4. Create UI Mockup Components (Pages 4-6)
- Component: "creator_platform_button"
- Component: "livestream_interface"
- Component: "payment_flow_bubble"
- Component: "financial_dashboard_card"

### 5. Assemble Pages
- Page 1: Cover layout
- Page 2: Profile layout
- Page 3: Work layout
- Pages 4-6: Mockup layouts

### 6. Export to PDF
- Use `export_pdf.PdfDocument`
- Multi-page PDF (5-6 pages)
- High-quality vector graphics

---

## Design Tokens

```zig
// Color Palette
const DESIGN_TOKENS = struct {
    // Background
    hemp_off_white: u32 = 0xF5F5DCFF,
    hemp_grain_dark: u32 = 0xE8E8D8FF,
    
    // Neon Colors
    neon_cyan: u32 = 0x00FFFF00,
    neon_magenta: u32 = 0xFF00FF00,
    neon_yellow: u32 = 0xFFFF0000,
    neon_green: u32 = 0x00FF0000,
    
    // Dark Base
    dark_base: u32 = 0x0A0A0AFF,
    dark_overlay: u32 = 0x1A1A1AFF,
    
    // Glitch Effects
    glitch_rgb_separation: f64 = 2.0,
    glitch_scan_line_opacity: f64 = 0.3,
};
```

---

## Implementation Steps

### Phase 1: Setup
1. Create Grain Bubble project file
2. Import keaton_profile.zig data parser
3. Load Instagram portrait images
4. Create background texture component

### Phase 2: Page 1 (Cover)
1. Add hemp paper background
2. Place glitchy portrait (large, centered)
3. Add name typography (neon glitch effect)
4. Add tagline and hashtags
5. Export page 1 to PDF

### Phase 3: Page 2 (Profile)
1. Add hemp paper background
2. Render description text
3. Create values bubble diagram
4. Create inspirations grid
5. Add musical preferences visualization
6. Export page 2 to PDF

### Phase 4: Page 3 (Work)
1. Add hemp paper background
2. Create Grain OS architecture diagram (bubble flow)
3. Visualize multi-agent system
4. Show research directory concept
5. List technical achievements
6. Export page 3 to PDF

### Phase 5: Pages 4-6 (Mockups)
1. Create dark neon gradient backgrounds
2. Design private spaces UI mockup (Page 4)
3. Design livestreaming + payments UI mockup (Page 5)
4. Design financial dashboard mockup (Page 6)
5. Apply glitchy neon effects
6. Export pages 4-6 to PDF

### Phase 6: Final Assembly
1. Combine all pages into single PDF
2. Verify page order and quality
3. Final export

---

## Mockup Specifications

### Page 4: Private Spaces
- **Layout**: Split screen showing creator and fan views
- **Elements**:
  - Private chat interface (bubble messages)
  - Content sharing gallery
  - Fan tier visualization (superfans highlighted)
  - Safety features badge

### Page 5: Livestreaming & Payments
- **Layout**: Livestream player with payment overlay
- **Elements**:
  - Video player (rounded corners, neon border)
  - Real-time tip buttons (Grainbank/Grainsoul)
  - Payment flow visualization (bubble connections)
  - Micropayment amounts displayed

### Page 6: Financial Dashboard
- **Layout**: Dashboard grid with data visualizations
- **Elements**:
  - Total assets display ($1M+)
  - Citizenship context (flag, country name)
  - Government department connections
  - Fiat currency context
  - Investment diversification chart (bubble diagram)

---

## Grain Bubble Code Structure

```zig
// Main export function
pub fn export_keaton_resume_pdf(
    allocator: std.mem.Allocator,
    profile: *PersonProfile,
    portrait_images: []const []const u8, // Image file paths
) ![]const u8 {
    // 1. Create multi-page PDF document
    // 2. For each page:
    //    - Create canvas
    //    - Add background texture
    //    - Add content (text, shapes, images)
    //    - Apply effects
    //    - Export page
    // 3. Combine pages
    // 4. Return PDF bytes
}
```

---

## Next Steps

1. **Create Grain Bubble project file** for resume
2. **Implement background texture generator** (hemp paper)
3. **Create glitch effect components** (neon, RGB separation)
4. **Build page layouts** (1-6)
5. **Design mockup components** (creator platform UI)
6. **Integrate keaton_profile.zig data** parser
7. **Load and process portrait images** (glitch effects)
8. **Export final PDF**

---

## Design Philosophy

This resume demonstrates:
- **Visual design ability**: Unorthodox aesthetic, glitchy neon effects
- **Technical depth**: Grain OS architecture, systems thinking
- **Creative vision**: Creator platform mockups, innovative features
- **Authenticity**: Real inspirations, real values, real work

The "bubble flows" in Grain Bubble will create organic, flowing connections between ideas, just like the DAG structure in the profile data.

---

**Status**: Plan ready for implementation  
**Estimated Time**: 2-3 days for full implementation  
**Tools Needed**: Grain Bubble, keaton_profile.zig, Instagram portrait images
