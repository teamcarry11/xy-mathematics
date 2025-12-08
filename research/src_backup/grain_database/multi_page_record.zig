//! Grain Database Multi-Page Record: Records spanning multiple pages.
//!
//! Why: Support large records that don't fit on a single page.
//! Architecture: Record metadata, page linking, split/merge operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-07-070701-pst: Grain Silo Agent

const std = @import("std");
const grain_core = @import("grain_core");
const file_storage = grain_core.file_storage;
const storage_engine = @import("storage_engine.zig");
const record_serialization = @import("record_serialization.zig");

// Bounded: Max pages per record.
pub const MAX_PAGES_PER_RECORD: u32 = 1024;

// Bounded: Max multi-page records.
pub const MAX_MULTI_PAGE_RECORDS: u32 = 10000;

// Multi-page record metadata.
pub const MultiPageRecordMetadata = struct {
    record_id: u64,
    first_page_id: u32,
    page_count: u32,
    total_size: u32,
    created_at: u64,
    updated_at: u64,
    active: bool,

    pub fn init(record_id: u64, first_page_id: u32, page_count: u32, total_size: u32, timestamp: u64) MultiPageRecordMetadata {
        std.debug.assert(record_id > 0);
        std.debug.assert(first_page_id < file_storage.MAX_PAGES);
        std.debug.assert(page_count > 0);
        std.debug.assert(page_count <= MAX_PAGES_PER_RECORD);
        std.debug.assert(total_size > 0);
        std.debug.assert(timestamp > 0);
        return MultiPageRecordMetadata{
            .record_id = record_id,
            .first_page_id = first_page_id,
            .page_count = page_count,
            .total_size = total_size,
            .created_at = timestamp,
            .updated_at = timestamp,
            .active = true,
        };
    }
};

// Multi-page record manager.
pub const MultiPageRecordManager = struct {
    metadata: [MAX_MULTI_PAGE_RECORDS]MultiPageRecordMetadata,
    metadata_len: u32,

    pub fn init() MultiPageRecordManager {
        var manager = MultiPageRecordManager{
            .metadata = undefined,
            .metadata_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_MULTI_PAGE_RECORDS) : (i += 1) {
            manager.metadata[i] = MultiPageRecordMetadata.init(0, 0, 0, 0, 0);
            manager.metadata[i].active = false;
        }
        return manager;
    }

    // Add multi-page record metadata.
    pub fn add_metadata(
        self: *MultiPageRecordManager,
        record_id: u64,
        first_page_id: u32,
        page_count: u32,
        total_size: u32,
        timestamp: u64,
    ) bool {
        std.debug.assert(record_id > 0);
        std.debug.assert(first_page_id < file_storage.MAX_PAGES);
        std.debug.assert(page_count > 0);
        std.debug.assert(page_count <= MAX_PAGES_PER_RECORD);
        std.debug.assert(total_size > 0);
        std.debug.assert(timestamp > 0);
        if (self.metadata_len >= MAX_MULTI_PAGE_RECORDS) {
            return false;
        }
        self.metadata[self.metadata_len] = MultiPageRecordMetadata.init(
            record_id,
            first_page_id,
            page_count,
            total_size,
            timestamp,
        );
        self.metadata_len += 1;
        std.debug.assert(self.metadata_len <= MAX_MULTI_PAGE_RECORDS);
        return true;
    }

    // Find multi-page record metadata by record_id.
    pub fn find_metadata(
        self: *const MultiPageRecordManager,
        record_id: u64,
    ) ?*const MultiPageRecordMetadata {
        std.debug.assert(record_id > 0);
        var i: u32 = 0;
        while (i < self.metadata_len) : (i += 1) {
            if (self.metadata[i].record_id == record_id and self.metadata[i].active) {
                return &self.metadata[i];
            }
        }
        return null;
    }

    // Check if record needs multiple pages.
    pub fn needs_multiple_pages(serialized_size: u32) bool {
        std.debug.assert(serialized_size > 0);
        return serialized_size > file_storage.PAGE_SIZE;
    }

    // Calculate number of pages needed for record.
    pub fn calculate_page_count(serialized_size: u32) u32 {
        std.debug.assert(serialized_size > 0);
        if (serialized_size <= file_storage.PAGE_SIZE) {
            return 1;
        }
        const pages = (serialized_size + file_storage.PAGE_SIZE - 1) / file_storage.PAGE_SIZE;
        std.debug.assert(pages <= MAX_PAGES_PER_RECORD);
        return pages;
    }
};

