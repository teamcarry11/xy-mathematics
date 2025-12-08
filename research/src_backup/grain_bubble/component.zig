//! Grain Bubble Component: Reusable design components.
//!
//! Why: Enable reusable design components (buttons, cards, etc.).
//! Architecture: Component library with variants and design tokens.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-135535-pst: Grain Bubble Agent

const std = @import("std");
const canvas = @import("canvas.zig");

// Bounded: Max components in library.
pub const MAX_COMPONENTS: u32 = 256;

// Bounded: Max variants per component.
pub const MAX_VARIANTS: u32 = 16;

// Bounded: Max component name length.
pub const MAX_COMPONENT_NAME_LEN: u32 = 64;

// Bounded: Max design tokens.
pub const MAX_DESIGN_TOKENS: u32 = 128;

// Component variant: different state/size/theme of a component.
pub const ComponentVariant = struct {
    id: u32,
    name: [MAX_COMPONENT_NAME_LEN]u8,
    name_len: u32,
    variant_type: VariantType,
    shapes: [canvas.MAX_SHAPES]canvas.Shape,
    shapes_len: u32,
    texts: [canvas.MAX_TEXT_ITEMS]canvas.Text,
    texts_len: u32,

    pub const VariantType = enum(u8) {
        state, // Different state (default, hover, active, disabled)
        size, // Different size (small, medium, large)
        theme, // Different theme (light, dark, custom)
    };

    pub fn init() ComponentVariant {
        var variant = ComponentVariant{
            .id = 0,
            .name = undefined,
            .name_len = 0,
            .variant_type = .state,
            .shapes = undefined,
            .shapes_len = 0,
            .texts = undefined,
            .texts_len = 0,
        };
        @memset(variant.name[0..], 0);
        std.debug.assert(variant.shapes_len == 0);
        std.debug.assert(variant.texts_len == 0);
        return variant;
    }
};

// Design token: reusable design value (color, spacing, typography).
pub const DesignToken = struct {
    id: u32,
    name: [MAX_COMPONENT_NAME_LEN]u8,
    name_len: u32,
    token_type: TokenType,
    value: TokenValue,

    pub const TokenType = enum(u8) {
        color,
        spacing,
        typography,
        radius,
    };

    pub const TokenValue = union(TokenType) {
        color: u32,
        spacing: f64,
        typography: TypographyValue,
        radius: f64,
    };

    pub const TypographyValue = struct {
        font_size: u32,
        line_height: f64,
        letter_spacing: f64,
    };

    pub fn init() DesignToken {
        var token = DesignToken{
            .id = 0,
            .name = undefined,
            .name_len = 0,
            .token_type = .color,
            .value = .{ .color = 0 },
        };
        @memset(token.name[0..], 0);
        return token;
    }
};

// Component: reusable design element.
pub const Component = struct {
    id: u32,
    name: [MAX_COMPONENT_NAME_LEN]u8,
    name_len: u32,
    variants: [MAX_VARIANTS]ComponentVariant,
    variants_len: u32,
    default_variant_id: u32,
    design_tokens: [MAX_DESIGN_TOKENS]DesignToken,
    design_tokens_len: u32,

    pub fn init() Component {
        var component = Component{
            .id = 0,
            .name = undefined,
            .name_len = 0,
            .variants = undefined,
            .variants_len = 0,
            .default_variant_id = 0,
            .design_tokens = undefined,
            .design_tokens_len = 0,
        };
        @memset(component.name[0..], 0);
        var i: u32 = 0;
        while (i < MAX_VARIANTS) : (i += 1) {
            component.variants[i] = ComponentVariant.init();
        }
        i = 0;
        while (i < MAX_DESIGN_TOKENS) : (i += 1) {
            component.design_tokens[i] = DesignToken.init();
        }
        std.debug.assert(component.variants_len == 0);
        std.debug.assert(component.design_tokens_len == 0);
        return component;
    }
};

// Component library: collection of reusable components.
pub const ComponentLibrary = struct {
    components: [MAX_COMPONENTS]Component,
    components_len: u32,
    next_component_id: u32,
    next_variant_id: u32,
    next_token_id: u32,

    pub fn init() ComponentLibrary {
        std.debug.assert(MAX_COMPONENTS > 0);
        std.debug.assert(MAX_VARIANTS > 0);
        std.debug.assert(MAX_DESIGN_TOKENS > 0);
        var library = ComponentLibrary{
            .components = undefined,
            .components_len = 0,
            .next_component_id = 1,
            .next_variant_id = 1,
            .next_token_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_COMPONENTS) : (i += 1) {
            library.components[i] = Component.init();
        }
        std.debug.assert(library.components_len == 0);
        std.debug.assert(library.next_component_id == 1);
        return library;
    }

    // Create component from canvas selection.
    pub fn create_component_from_selection(
        self: *ComponentLibrary,
        canvas_state: *const canvas.Canvas,
        name: []const u8,
    ) ?u32 {
        std.debug.assert(@intFromPtr(canvas_state) != 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        if (self.components_len >= MAX_COMPONENTS) {
            return null;
        }
        if (canvas_state.selection_len == 0) {
            return null;
        }
        const component_id = self.next_component_id;
        self.next_component_id += 1;
        var component = Component.init();
        component.id = component_id;
        const name_len = @min(name.len, MAX_COMPONENT_NAME_LEN);
        @memset(component.name[0..name_len], 0);
        @memcpy(component.name[0..name_len], name[0..name_len]);
        component.name_len = @as(u32, @intCast(name_len));
        // Create default variant from selected shapes.
        var variant = ComponentVariant.init();
        variant.id = self.next_variant_id;
        self.next_variant_id += 1;
        variant.variant_type = .state;
        const variant_name = "default";
        const variant_name_len = @min(variant_name.len, MAX_COMPONENT_NAME_LEN);
        @memset(variant.name[0..variant_name_len], 0);
        @memcpy(variant.name[0..variant_name_len], variant_name[0..variant_name_len]);
        variant.name_len = @as(u32, @intCast(variant_name_len));
        // Copy selected shapes to variant.
        var shape_i: u32 = 0;
        while (shape_i < canvas_state.selection_len and
            variant.shapes_len < canvas.MAX_SHAPES) : (shape_i += 1)
        {
            const shape_id = canvas_state.selection[shape_i];
            if (canvas_state.get_shape(shape_id)) |shape| {
                variant.shapes[variant.shapes_len] = shape.*;
                variant.shapes_len += 1;
            }
        }
        component.variants[0] = variant;
        component.variants_len = 1;
        component.default_variant_id = variant.id;
        self.components[self.components_len] = component;
        self.components_len += 1;
        std.debug.assert(self.components_len <= MAX_COMPONENTS);
        std.debug.assert(component.variants_len == 1);
        return component_id;
    }

    // Get component by ID.
    pub fn get_component(self: *ComponentLibrary, component_id: u32) ?*Component {
        std.debug.assert(component_id > 0);
        var i: u32 = 0;
        while (i < self.components_len) : (i += 1) {
            if (self.components[i].id == component_id) {
                return &self.components[i];
            }
        }
        return null;
    }

    // Get component by ID (mutable).
    pub fn get_component_mut(
        self: *ComponentLibrary,
        component_id: u32,
    ) ?*Component {
        std.debug.assert(component_id > 0);
        var i: u32 = 0;
        while (i < self.components_len) : (i += 1) {
            if (self.components[i].id == component_id) {
                return &self.components[i];
            }
        }
        return null;
    }

    // Get component by name.
    pub fn get_component_by_name(
        self: *const ComponentLibrary,
        name: []const u8,
    ) ?*const Component {
        std.debug.assert(name.len > 0);
        var i: u32 = 0;
        while (i < self.components_len) : (i += 1) {
            const component = &self.components[i];
            if (component.name_len == name.len) {
                var match = true;
                var j: u32 = 0;
                while (j < name.len) : (j += 1) {
                    if (component.name[j] != name[j]) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    return component;
                }
            }
        }
        return null;
    }

    // Instantiate component on canvas (create instance from component).
    pub fn instantiate_component(
        self: *const ComponentLibrary,
        component_id: u32,
        canvas_state: *canvas.Canvas,
        layer_id: u32,
        x: f64,
        y: f64,
    ) ?u32 {
        std.debug.assert(component_id > 0);
        std.debug.assert(@intFromPtr(canvas_state) != 0);
        std.debug.assert(layer_id > 0);
        if (self.get_component(component_id)) |component| {
            if (component.variants_len == 0) {
                return null;
            }
            // Use default variant.
            const default_variant = &component.variants[0];
            // Calculate offset from component origin.
            var min_x: f64 = std.math.inf(f64);
            var min_y: f64 = std.math.inf(f64);
            var shape_i: u32 = 0;
            while (shape_i < default_variant.shapes_len) : (shape_i += 1) {
                const shape = &default_variant.shapes[shape_i];
                if (shape.x < min_x) min_x = shape.x;
                if (shape.y < min_y) min_y = shape.y;
            }
            // Instantiate shapes with offset.
            var first_shape_id: ?u32 = null;
            shape_i = 0;
            while (shape_i < default_variant.shapes_len) : (shape_i += 1) {
                const shape = &default_variant.shapes[shape_i];
                const offset_x = x - min_x;
                const offset_y = y - min_y;
                const shape_id = canvas_state.add_shape_with_stroke(
                    layer_id,
                    shape.shape_type,
                    shape.x + offset_x,
                    shape.y + offset_y,
                    shape.width,
                    shape.height,
                    shape.color,
                    shape.corner_radius,
                    shape.stroke_width,
                    shape.stroke_color,
                );
                if (shape_id) |id| {
                    if (first_shape_id == null) {
                        first_shape_id = id;
                    }
                }
            }
            return first_shape_id;
        }
        return null;
    }

    // Add variant to component.
    pub fn add_variant(
        self: *ComponentLibrary,
        component_id: u32,
        name: []const u8,
        variant_type: ComponentVariant.VariantType,
    ) ?u32 {
        std.debug.assert(component_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        if (self.get_component_mut(component_id)) |component| {
            if (component.variants_len >= MAX_VARIANTS) {
                return null;
            }
            const variant_id = self.next_variant_id;
            self.next_variant_id += 1;
            var variant = ComponentVariant.init();
            variant.id = variant_id;
            variant.variant_type = variant_type;
            const name_len = @min(name.len, MAX_COMPONENT_NAME_LEN);
            @memset(variant.name[0..name_len], 0);
            @memcpy(variant.name[0..name_len], name[0..name_len]);
            variant.name_len = @as(u32, @intCast(name_len));
            component.variants[component.variants_len] = variant;
            component.variants_len += 1;
            std.debug.assert(component.variants_len <= MAX_VARIANTS);
            return variant_id;
        }
        return null;
    }

    // Add design token to component.
    pub fn add_design_token(
        self: *ComponentLibrary,
        component_id: u32,
        name: []const u8,
        token_type: DesignToken.TokenType,
        value: DesignToken.TokenValue,
    ) ?u32 {
        std.debug.assert(component_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        if (self.get_component_mut(component_id)) |component| {
            if (component.design_tokens_len >= MAX_DESIGN_TOKENS) {
                return null;
            }
            const token_id = self.next_token_id;
            self.next_token_id += 1;
            var token = DesignToken.init();
            token.id = token_id;
            token.token_type = token_type;
            token.value = value;
            const name_len = @min(name.len, MAX_COMPONENT_NAME_LEN);
            @memset(token.name[0..name_len], 0);
            @memcpy(token.name[0..name_len], name[0..name_len]);
            token.name_len = @as(u32, @intCast(name_len));
            component.design_tokens[component.design_tokens_len] = token;
            component.design_tokens_len += 1;
            std.debug.assert(component.design_tokens_len <= MAX_DESIGN_TOKENS);
            return token_id;
        }
        return null;
    }
};

