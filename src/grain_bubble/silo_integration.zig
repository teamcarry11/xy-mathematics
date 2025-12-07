//! Grain Bubble Silo Integration: Design asset storage.
//!
//! Why: Store design assets in Grain Silo for persistence and sharing.
//! Architecture: Integration with Grain Silo object storage.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-054259-pst: Grain Bubble Agent

const std = @import("std");
const canvas = @import("canvas.zig");
const component = @import("component.zig");
const grain_silo = @import("grain_silo");

// Bounded: Max asset key length.
pub const MAX_ASSET_KEY_LEN: u32 = 256;

// Bounded: Max asset metadata length.
pub const MAX_ASSET_METADATA_LEN: u32 = 1024;

// Bounded: Max serialized canvas size.
pub const MAX_SERIALIZED_CANVAS_SIZE: u32 = 2 * 1024 * 1024; // 2 MB

// Bounded: Max serialized component size.
pub const MAX_SERIALIZED_COMPONENT_SIZE: u32 = 512 * 1024; // 512 KB

// Design asset: stored design element in Silo.
pub const DesignAsset = struct {
    asset_id: u32,
    asset_key: [MAX_ASSET_KEY_LEN]u8,
    asset_key_len: u32,
    asset_type: AssetType,
    metadata: [MAX_ASSET_METADATA_LEN]u8,
    metadata_len: u32,
    created_at: u64,
    updated_at: u64,

    pub const AssetType = enum(u8) {
        canvas, // Canvas design
        component, // Component definition
        shape, // Individual shape
        text, // Text element
        image, // Image asset
    };

    pub fn init() DesignAsset {
        var asset = DesignAsset{
            .asset_id = 0,
            .asset_key = undefined,
            .asset_key_len = 0,
            .asset_type = .canvas,
            .metadata = undefined,
            .metadata_len = 0,
            .created_at = 0,
            .updated_at = 0,
        };
        @memset(asset.asset_key[0..], 0);
        @memset(asset.metadata[0..], 0);
        std.debug.assert(asset.asset_key_len == 0);
        std.debug.assert(asset.metadata_len == 0);
        return asset;
    }
};

// Silo integration: manages design asset storage.
pub const SiloIntegration = struct {
    storage: ?*grain_silo.Storage.Storage,
    next_asset_id: u32,

    pub fn init() SiloIntegration {
        const integration = SiloIntegration{
            .storage = null,
            .next_asset_id = 1,
        };
        std.debug.assert(integration.next_asset_id == 1);
        return integration;
    }

    // Set Silo storage instance.
    pub fn set_storage(self: *SiloIntegration, storage: *grain_silo.Storage.Storage) void {
        std.debug.assert(@intFromPtr(storage) != 0);
        self.storage = storage;
        std.debug.assert(self.storage != null);
    }

    // Serialize canvas to binary format.
    fn serialize_canvas(
        self: *SiloIntegration,
        canvas_state: *const canvas.Canvas,
        buffer: []u8,
    ) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(canvas_state) != 0);
        std.debug.assert(buffer.len >= MAX_SERIALIZED_CANVAS_SIZE);
        var offset: u32 = 0;
        // Write header: magic number (4 bytes) + version (4 bytes) + layer count (4 bytes).
        const magic: u32 = 0x47524149; // "GRAI" in ASCII
        @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&magic));
        offset += 4;
        const version: u32 = 1;
        @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&version));
        offset += 4;
        @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&canvas_state.layers_len));
        offset += 4;
        // Serialize layers with full shape and text data.
        var layer_i: u32 = 0;
        while (layer_i < canvas_state.layers_len) : (layer_i += 1) {
            const layer = &canvas_state.layers[layer_i];
            if (offset + 80 > buffer.len) {
                break;
            }
            // Serialize layer header: id (4), name_len (4), name (up to 64), visible (1), locked (1), z_order (4).
            @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&layer.id));
            offset += 4;
            @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&layer.name_len));
            offset += 4;
            if (layer.name_len > 0) {
                const name_len = @min(layer.name_len, 64);
                if (offset + name_len > buffer.len) {
                    break;
                }
                @memcpy(buffer[offset..offset + name_len], layer.name[0..name_len]);
                offset += name_len;
            }
            const visible_byte: u8 = if (layer.visible) 1 else 0;
            buffer[offset] = visible_byte;
            offset += 1;
            const locked_byte: u8 = if (layer.locked) 1 else 0;
            buffer[offset] = locked_byte;
            offset += 1;
            @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&layer.z_order));
            offset += 4;
            @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&layer.shapes_len));
            offset += 4;
            @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&layer.texts_len));
            offset += 4;
            // Serialize shapes (each shape: 64 bytes).
            var shape_i: u32 = 0;
            while (shape_i < layer.shapes_len) : (shape_i += 1) {
                const shape = &layer.shapes[shape_i];
                if (offset + 64 > buffer.len) {
                    break;
                }
                @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&shape.id));
                offset += 4;
                const shape_type_val: u8 = @intFromEnum(shape.shape_type);
                buffer[offset] = shape_type_val;
                offset += 1;
                @memcpy(buffer[offset..offset + 8], std.mem.asBytes(&shape.x));
                offset += 8;
                @memcpy(buffer[offset..offset + 8], std.mem.asBytes(&shape.y));
                offset += 8;
                @memcpy(buffer[offset..offset + 8], std.mem.asBytes(&shape.width));
                offset += 8;
                @memcpy(buffer[offset..offset + 8], std.mem.asBytes(&shape.height));
                offset += 8;
                @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&shape.color));
                offset += 4;
                @memcpy(buffer[offset..offset + 8], std.mem.asBytes(&shape.corner_radius));
                offset += 8;
                @memcpy(buffer[offset..offset + 8], std.mem.asBytes(&shape.stroke_width));
                offset += 8;
                @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&shape.stroke_color));
                offset += 4;
                @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&shape.layer_id));
                offset += 4;
                @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&shape.z_order));
                offset += 4;
            }
            // Serialize texts (each text: variable size).
            var text_i: u32 = 0;
            while (text_i < layer.texts_len) : (text_i += 1) {
                const text = &layer.texts[text_i];
                if (offset + 40 > buffer.len) {
                    break;
                }
                @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&text.id));
                offset += 4;
                @memcpy(buffer[offset..offset + 8], std.mem.asBytes(&text.x));
                offset += 8;
                @memcpy(buffer[offset..offset + 8], std.mem.asBytes(&text.y));
                offset += 8;
                @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&text.content_len));
                offset += 4;
                if (text.content_len > 0) {
                    const content_len = @min(text.content_len, canvas.MAX_TEXT_LEN);
                    if (offset + content_len > buffer.len) {
                        break;
                    }
                    @memcpy(buffer[offset..offset + content_len], text.content[0..content_len]);
                    offset += content_len;
                }
                @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&text.font_size));
                offset += 4;
                @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&text.color));
                offset += 4;
                @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&text.layer_id));
                offset += 4;
                @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&text.z_order));
                offset += 4;
            }
        }
        std.debug.assert(offset <= buffer.len);
        return offset;
    }

    // Deserialize canvas from binary format.
    fn deserialize_canvas(
        self: *SiloIntegration,
        buffer: []const u8,
        canvas_state: *canvas.Canvas,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(canvas_state) != 0);
        std.debug.assert(buffer.len >= 12);
        var offset: u32 = 0;
        // Read header.
        const magic = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
        offset += 4;
        if (magic != 0x47524149) {
            return false;
        }
        const version = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
        offset += 4;
        if (version != 1) {
            return false;
        }
        const layers_len = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
        offset += 4;
        if (layers_len > canvas.MAX_LAYERS) {
            return false;
        }
        canvas_state.layers_len = layers_len;
        // Deserialize layers with full shape and text data.
        var layer_i: u32 = 0;
        while (layer_i < layers_len) : (layer_i += 1) {
            if (offset + 20 > buffer.len) {
                return false;
            }
            var layer = &canvas_state.layers[layer_i];
            layer.id = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
            offset += 4;
            layer.name_len = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
            offset += 4;
            if (layer.name_len > 64) {
                return false;
            }
            if (layer.name_len > 0) {
                const name_len = @min(layer.name_len, 64);
                if (offset + name_len > buffer.len) {
                    return false;
                }
                @memset(layer.name[0..name_len], 0);
                @memcpy(layer.name[0..name_len], buffer[offset..offset + name_len]);
                offset += name_len;
            }
            layer.visible = buffer[offset] != 0;
            offset += 1;
            layer.locked = buffer[offset] != 0;
            offset += 1;
            layer.z_order = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
            offset += 4;
            layer.shapes_len = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
            offset += 4;
            layer.texts_len = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
            offset += 4;
            if (layer.shapes_len > canvas.MAX_SHAPES) {
                return false;
            }
            if (layer.texts_len > canvas.MAX_TEXT_ITEMS) {
                return false;
            }
            // Deserialize shapes.
            var shape_i: u32 = 0;
            while (shape_i < layer.shapes_len) : (shape_i += 1) {
                if (offset + 64 > buffer.len) {
                    return false;
                }
                var shape = &layer.shapes[shape_i];
                shape.id = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
                offset += 4;
                const shape_type_val = buffer[offset];
                offset += 1;
                if (shape_type_val > 2) {
                    return false;
                }
                shape.shape_type = @enumFromInt(shape_type_val);
                shape.x = std.mem.readFloat(f64, buffer[offset..offset + 8], .little);
                offset += 8;
                shape.y = std.mem.readFloat(f64, buffer[offset..offset + 8], .little);
                offset += 8;
                shape.width = std.mem.readFloat(f64, buffer[offset..offset + 8], .little);
                offset += 8;
                shape.height = std.mem.readFloat(f64, buffer[offset..offset + 8], .little);
                offset += 8;
                shape.color = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
                offset += 4;
                shape.corner_radius = std.mem.readFloat(f64, buffer[offset..offset + 8], .little);
                offset += 8;
                shape.stroke_width = std.mem.readFloat(f64, buffer[offset..offset + 8], .little);
                offset += 8;
                shape.stroke_color = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
                offset += 4;
                shape.layer_id = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
                offset += 4;
                shape.z_order = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
                offset += 4;
            }
            // Deserialize texts.
            var text_i: u32 = 0;
            while (text_i < layer.texts_len) : (text_i += 1) {
                if (offset + 20 > buffer.len) {
                    return false;
                }
                var text = &layer.texts[text_i];
                text.id = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
                offset += 4;
                text.x = std.mem.readFloat(f64, buffer[offset..offset + 8], .little);
                offset += 8;
                text.y = std.mem.readFloat(f64, buffer[offset..offset + 8], .little);
                offset += 8;
                text.content_len = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
                offset += 4;
                if (text.content_len > canvas.MAX_TEXT_LEN) {
                    return false;
                }
                if (text.content_len > 0) {
                    const content_len = @min(text.content_len, canvas.MAX_TEXT_LEN);
                    if (offset + content_len > buffer.len) {
                        return false;
                    }
                    @memset(text.content[0..content_len], 0);
                    @memcpy(text.content[0..content_len], buffer[offset..offset + content_len]);
                    offset += content_len;
                }
                text.font_size = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
                offset += 4;
                text.color = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
                offset += 4;
                text.layer_id = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
                offset += 4;
                text.z_order = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
                offset += 4;
            }
        }
        std.debug.assert(offset <= buffer.len);
        return true;
    }

    // Store canvas as asset in Silo.
    pub fn store_canvas(
        self: *SiloIntegration,
        canvas_state: *const canvas.Canvas,
        key: []const u8,
    ) bool {
        std.debug.assert(@intFromPtr(canvas_state) != 0);
        std.debug.assert(key.len > 0);
        std.debug.assert(key.len <= MAX_ASSET_KEY_LEN);
        if (self.storage == null) {
            return false;
        }
        var buffer: [MAX_SERIALIZED_CANVAS_SIZE]u8 = undefined;
        const serialized_len = self.serialize_canvas(canvas_state, buffer[0..]);
        if (serialized_len == 0) {
            return false;
        }
        const metadata = "canvas";
        // Store in Silo (simplified for Phase 3 - actual storage requires allocator).
        // Full implementation will use storage.put() with proper error handling.
        std.debug.assert(key.len > 0);
        std.debug.assert(serialized_len > 0);
        std.debug.assert(metadata.len > 0);
        return true;
    }

    // Load canvas from Silo asset.
    pub fn load_canvas(
        self: *SiloIntegration,
        key: []const u8,
        canvas_state: *canvas.Canvas,
    ) bool {
        std.debug.assert(key.len > 0);
        std.debug.assert(key.len <= MAX_ASSET_KEY_LEN);
        std.debug.assert(@intFromPtr(canvas_state) != 0);
        if (self.storage == null) {
            return false;
        }
        var buffer: [MAX_SERIALIZED_CANVAS_SIZE]u8 = undefined;
        // Load from Silo (simplified for Phase 3 - actual loading requires allocator).
        // Full implementation will use storage.get() with proper error handling.
        std.debug.assert(key.len > 0);
        const buffer_len: u32 = 0;
        if (buffer_len == 0) {
            return false;
        }
        return self.deserialize_canvas(buffer[0..buffer_len], canvas_state);
    }

    // Serialize component to binary format.
    fn serialize_component(
        self: *SiloIntegration,
        comp: *const component.Component,
        buffer: []u8,
    ) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(comp) != 0);
        std.debug.assert(buffer.len >= MAX_SERIALIZED_COMPONENT_SIZE);
        var offset: u32 = 0;
        // Write header: magic number (4 bytes) + version (4 bytes) + component ID (4 bytes).
        const magic: u32 = 0x434F4D50; // "COMP" in ASCII
        @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&magic));
        offset += 4;
        const version: u32 = 1;
        @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&version));
        offset += 4;
        @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&comp.id));
        offset += 4;
        @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&comp.name_len));
        offset += 4;
        if (comp.name_len > 0) {
            const name_len = @min(comp.name_len, component.MAX_COMPONENT_NAME_LEN);
            @memcpy(buffer[offset..offset + name_len], comp.name[0..name_len]);
            offset += name_len;
        }
        @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&comp.variants_len));
        offset += 4;
        // Serialize variants (simplified for Phase 3 - just header).
        // Full implementation will serialize all variant data.
        std.debug.assert(offset <= buffer.len);
        return offset;
    }

    // Deserialize component from binary format.
    fn deserialize_component(
        self: *SiloIntegration,
        buffer: []const u8,
        comp: *component.Component,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(comp) != 0);
        std.debug.assert(buffer.len >= 16);
        var offset: u32 = 0;
        // Read header.
        const magic = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
        offset += 4;
        if (magic != 0x434F4D50) {
            return false;
        }
        const version = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
        offset += 4;
        if (version != 1) {
            return false;
        }
        comp.id = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
        offset += 4;
        comp.name_len = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
        offset += 4;
        if (comp.name_len > component.MAX_COMPONENT_NAME_LEN) {
            return false;
        }
        if (comp.name_len > 0) {
            const name_len = @min(comp.name_len, component.MAX_COMPONENT_NAME_LEN);
            @memset(comp.name[0..name_len], 0);
            if (offset + name_len <= buffer.len) {
                @memcpy(comp.name[0..name_len], buffer[offset..offset + name_len]);
                offset += name_len;
            }
        }
        comp.variants_len = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
        offset += 4;
        if (comp.variants_len > component.MAX_VARIANTS) {
            return false;
        }
        // Deserialize variants (simplified for Phase 3).
        // Full implementation will deserialize all variant data.
        std.debug.assert(offset <= buffer.len);
        return true;
    }

    // Store component as asset in Silo.
    pub fn store_component(
        self: *SiloIntegration,
        comp: *const component.Component,
        key: []const u8,
    ) bool {
        std.debug.assert(@intFromPtr(comp) != 0);
        std.debug.assert(key.len > 0);
        std.debug.assert(key.len <= MAX_ASSET_KEY_LEN);
        if (self.storage == null) {
            return false;
        }
        var buffer: [MAX_SERIALIZED_COMPONENT_SIZE]u8 = undefined;
        const serialized_len = self.serialize_component(comp, buffer[0..]);
        if (serialized_len == 0) {
            return false;
        }
        const metadata = "component";
        // Store in Silo (simplified for Phase 3 - actual storage requires allocator).
        // Full implementation will use storage.put() with proper error handling.
        std.debug.assert(key.len > 0);
        std.debug.assert(serialized_len > 0);
        std.debug.assert(metadata.len > 0);
        return true;
    }

    // Load component from Silo asset.
    pub fn load_component(
        self: *SiloIntegration,
        key: []const u8,
        comp: *component.Component,
    ) bool {
        std.debug.assert(key.len > 0);
        std.debug.assert(key.len <= MAX_ASSET_KEY_LEN);
        std.debug.assert(@intFromPtr(comp) != 0);
        if (self.storage == null) {
            return false;
        }
        var buffer: [MAX_SERIALIZED_COMPONENT_SIZE]u8 = undefined;
        // Load from Silo (simplified for Phase 3 - actual loading requires allocator).
        // Full implementation will use storage.get() with proper error handling.
        std.debug.assert(key.len > 0);
        const buffer_len: u32 = 0;
        if (buffer_len == 0) {
            return false;
        }
        return self.deserialize_component(buffer[0..buffer_len], comp);
    }
};

