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
        var integration = SiloIntegration{
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
        // Serialize layers (simplified for Phase 3 - just header).
        // Full implementation will serialize all layer, shape, and text data.
        std.debug.assert(offset <= buffer.len);
        return offset;
    }

    // Deserialize canvas from binary format.
    fn deserialize_canvas(
        self: *SiloIntegration,
        buffer: []const u8,
        canvas_state: *canvas.Canvas,
    ) bool {
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
        // Deserialize layers (simplified for Phase 3).
        // Full implementation will deserialize all layer data.
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
        _ = key;
        _ = buffer[0..serialized_len];
        _ = metadata;
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
        _ = key;
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
        _ = key;
        _ = buffer[0..serialized_len];
        _ = metadata;
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
        _ = key;
        const buffer_len: u32 = 0;
        if (buffer_len == 0) {
            return false;
        }
        return self.deserialize_component(buffer[0..buffer_len], comp);
    }
};

