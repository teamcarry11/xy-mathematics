# Grain Mobile Style System

**Date**: 2025-12-03-170124-pst  
**Agent**: Grain Mobile Agent  
**Status**: Design Document

---

## Overview

The Grain Mobile Style System provides a shared style guide and component specification system in Zig (Grain Style compliant) that works seamlessly with Kotlin (Android Jetpack Compose) and Swift (iOS SwiftUI).

**Key Principle**: Zig defines style data structures, responsive breakpoints, and component specifications. Native platforms (Kotlin/Swift) consume these via FFI and render using their native UI frameworks.

---

## Architecture

### Three-Layer Approach

1. **Style Definition Layer (Zig)**: 
   - Color palettes, typography, spacing, breakpoints
   - Component specifications (layout, properties, constraints)
   - Responsive breakpoint logic
   - Theme management

2. **FFI Bridge Layer (C API)**:
   - C-compatible exports for style data
   - Breakpoint queries
   - Component property lookups

3. **Native Rendering Layer (Kotlin/Swift)**:
   - Consumes style data via FFI
   - Renders using Jetpack Compose / SwiftUI
   - Handles platform-specific UI behaviors

---

## Design Principles

### 1. **Data-Driven Styles**
- All styles defined as data structures in Zig
- No rendering logic in Zig (rendering is platform-specific)
- Styles are serializable and queryable

### 2. **Responsive Breakpoints**
- Breakpoints defined in Zig (shared across platforms)
- Breakpoint queries return style variants
- Supports: phone (small/medium/large), tablet, desktop

### 3. **Component Specifications**
- Components defined as data structures (not UI code)
- Properties: layout, spacing, colors, typography, constraints
- Native platforms map to their UI components

### 4. **Theme Support**
- Light/dark themes
- Custom color palettes
- Typography scales
- Spacing scales

### 5. **Grain Style Compliance**
- `grain_case` function names
- Explicit types (`u32`, `u64`, not `usize`)
- Bounded allocations (`MAX_*` constants)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- No recursion

---

## Style System Structure

### Breakpoints

```zig
pub const Breakpoint = enum(u8) {
    phone_small,    // < 360dp (Android) / < 375pt (iOS)
    phone_medium,   // 360-414dp / 375-414pt
    phone_large,    // 414-480dp / 414-480pt
    tablet_small,   // 480-600dp / 480-600pt
    tablet_large,   // 600-840dp / 600-840pt
    desktop,        // > 840dp / > 840pt
};
```

### Colors

```zig
pub const ColorPalette = struct {
    primary: Color,
    secondary: Color,
    background: Color,
    surface: Color,
    error: Color,
    on_primary: Color,
    on_secondary: Color,
    on_background: Color,
    on_surface: Color,
    on_error: Color,
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};
```

### Typography

```zig
pub const TypographyScale = struct {
    display_large: TextStyle,
    display_medium: TextStyle,
    display_small: TextStyle,
    headline_large: TextStyle,
    headline_medium: TextStyle,
    headline_small: TextStyle,
    title_large: TextStyle,
    title_medium: TextStyle,
    title_small: TextStyle,
    body_large: TextStyle,
    body_medium: TextStyle,
    body_small: TextStyle,
    label_large: TextStyle,
    label_medium: TextStyle,
    label_small: TextStyle,
};

pub const TextStyle = struct {
    font_size: u32,      // Points (iOS) / SP (Android)
    line_height: u32,    // Points / SP
    letter_spacing: i32, // Points / SP (can be negative)
    font_weight: FontWeight,
};
```

### Spacing

```zig
pub const SpacingScale = struct {
    xs: u32,   // 4dp/4pt
    sm: u32,   // 8dp/8pt
    md: u32,   // 16dp/16pt
    lg: u32,   // 24dp/24pt
    xl: u32,   // 32dp/32pt
    xxl: u32,  // 48dp/48pt
};
```

### Component Specifications

```zig
pub const ComponentSpec = struct {
    component_type: ComponentType,
    layout: LayoutSpec,
    spacing: SpacingSpec,
    colors: ColorSpec,
    typography: TypographySpec,
    constraints: ConstraintSpec,
};

pub const ComponentType = enum(u8) {
    button,
    text_field,
    card,
    list_item,
    app_bar,
    bottom_nav,
    // ... more components
};
```

---

## Responsive Design Strategy

### Breakpoint Detection

Zig provides breakpoint queries based on screen dimensions:

```zig
pub fn get_breakpoint(width_dp: u32, height_dp: u32) Breakpoint {
    // Logic to determine breakpoint
    // Returns appropriate breakpoint enum
}
```

### Responsive Styles

Styles can vary by breakpoint:

```zig
pub fn get_component_style(
    component_type: ComponentType,
    breakpoint: Breakpoint,
    theme: Theme,
) ComponentSpec {
    // Returns style variant based on breakpoint
    // e.g., larger padding on tablet, different font sizes
}
```

---

## FFI API Design

### Style Queries

```zig
// Get breakpoint for screen dimensions
export fn grain_mobile_get_breakpoint(
    width_dp: u32,
    height_dp: u32,
) u8; // Returns Breakpoint enum value

// Get color from palette
export fn grain_mobile_get_color(
    palette: *const ColorPalette,
    color_name: [*c]const u8,
    color_name_len: u32,
    color_out: *Color,
) c_int;

// Get typography style
export fn grain_mobile_get_typography(
    scale: *const TypographyScale,
    style_name: [*c]const u8,
    style_name_len: u32,
    text_style_out: *TextStyle,
) c_int;

// Get spacing value
export fn grain_mobile_get_spacing(
    scale: *const SpacingScale,
    size_name: [*c]const u8,
    size_name_len: u32,
    spacing_out: *u32,
) c_int;

// Get component specification
export fn grain_mobile_get_component_spec(
    component_type: ComponentType,
    breakpoint: Breakpoint,
    theme: Theme,
    spec_out: *ComponentSpec,
) c_int;
```

---

## Native Platform Integration

### Android (Kotlin + Jetpack Compose)

```kotlin
// Query breakpoint from Zig
val breakpoint = grain_mobile_get_breakpoint(
    LocalConfiguration.current.screenWidthDp.toUInt(),
    LocalConfiguration.current.screenHeightDp.toUInt()
)

// Get component style
val buttonSpec = grain_mobile_get_component_spec(
    ComponentType.BUTTON,
    breakpoint,
    currentTheme
)

// Use in Compose
Button(
    modifier = Modifier
        .padding(
            horizontal = buttonSpec.spacing.horizontal.dp,
            vertical = buttonSpec.spacing.vertical.dp
        )
        .height(buttonSpec.constraints.min_height.dp),
    colors = ButtonDefaults.buttonColors(
        backgroundColor = Color(
            buttonSpec.colors.background.r,
            buttonSpec.colors.background.g,
            buttonSpec.colors.background.b,
            buttonSpec.colors.background.a
        )
    )
) {
    Text(
        text = "Click Me",
        style = TextStyle(
            fontSize = buttonSpec.typography.font_size.sp,
            fontWeight = FontWeight(buttonSpec.typography.font_weight.value)
        )
    )
}
```

### iOS (Swift + SwiftUI)

```swift
// Query breakpoint from Zig
let screenWidth = UIScreen.main.bounds.width
let screenHeight = UIScreen.main.bounds.height
let breakpoint = grain_mobile_get_breakpoint(
    UInt32(screenWidth),
    UInt32(screenHeight)
)

// Get component style
var buttonSpec = ComponentSpec()
grain_mobile_get_component_spec(
    .button,
    breakpoint,
    currentTheme,
    &buttonSpec
)

// Use in SwiftUI
Button(action: {}) {
    Text("Click Me")
        .font(.system(
            size: CGFloat(buttonSpec.typography.font_size),
            weight: Font.Weight(buttonSpec.typography.font_weight)
        ))
        .padding(
            .horizontal, CGFloat(buttonSpec.spacing.horizontal)
        )
        .padding(
            .vertical, CGFloat(buttonSpec.spacing.vertical)
        )
        .frame(minHeight: CGFloat(buttonSpec.constraints.min_height))
        .background(Color(
            red: Double(buttonSpec.colors.background.r) / 255.0,
            green: Double(buttonSpec.colors.background.g) / 255.0,
            blue: Double(buttonSpec.colors.background.b) / 255.0,
            opacity: Double(buttonSpec.colors.background.a) / 255.0
        ))
}
```

---

## Implementation Plan

### Phase 1: Core Style Definitions
- [ ] Color palette structures
- [ ] Typography scale structures
- [ ] Spacing scale structures
- [ ] Breakpoint definitions
- [ ] Theme structures

### Phase 2: Responsive Logic
- [ ] Breakpoint detection function
- [ ] Responsive style queries
- [ ] Breakpoint-based style variants

### Phase 3: Component Specifications
- [ ] Component type definitions
- [ ] Component specification structures
- [ ] Component style lookup functions

### Phase 4: FFI Layer
- [ ] C-compatible style query exports
- [ ] Breakpoint query exports
- [ ] Component spec exports

### Phase 5: Native Platform Bindings
- [ ] Android JNI bindings (Kotlin)
- [ ] iOS C interop bindings (Swift)
- [ ] Example implementations

### Phase 6: Documentation & Examples
- [ ] Style guide documentation
- [ ] Component usage examples
- [ ] Responsive design patterns

---

## File Structure

```
src/grain_mobile_core/
├── style/
│   ├── root.zig              # Style system root
│   ├── colors.zig            # Color palettes
│   ├── typography.zig         # Typography scales
│   ├── spacing.zig           # Spacing scales
│   ├── breakpoints.zig       # Breakpoint definitions
│   ├── themes.zig            # Theme management
│   ├── components.zig        # Component specifications
│   └── responsive.zig        # Responsive logic
└── ffi/
    └── style_api.zig         # FFI exports for styles
```

---

## Benefits

1. **Single Source of Truth**: All styles defined once in Zig
2. **Consistency**: Same styles across Android and iOS
3. **Type Safety**: Compile-time style validation
4. **Performance**: No runtime style parsing overhead
5. **Maintainability**: Centralized style management
6. **Responsive**: Breakpoint-based responsive design
7. **Themeable**: Easy theme switching

---

## Next Steps

1. Implement core style definitions (colors, typography, spacing)
2. Implement breakpoint detection
3. Implement component specifications
4. Create FFI layer
5. Test with native platform bindings

