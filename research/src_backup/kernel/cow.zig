//! Copy-on-Write (COW) Memory Sharing System
//!
//! Objective: Enable efficient memory sharing between processes using copy-on-write semantics.
//! Why: Allow multiple processes to share read-only memory pages, copying pages only when modified.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track reference counts for shared pages
//! - Mark pages as COW when shared
//! - Copy pages on first write (fault handling)
//! - Decrement reference counts on unmap
//! - Free pages when reference count reaches zero
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded counters: fixed-size counters (no overflow issues)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-01-XX
//! GrainStyle: Comprehensive COW tracking, deterministic behavior, explicit limits

const std = @import("std");
const Debug = @import("debug.zig");

/// Page size (4KB, standard RISC-V page size).
/// Why: Explicit constant for page size, matches RISC-V standard.
pub const PAGE_SIZE: u64 = 4096;

/// Maximum number of pages in VM memory (4MB / 4KB = 1024 pages).
/// Why: Bounded allocation, prevents unbounded growth.
const MAX_PAGES: u32 = 1024;

/// Maximum reference count for a shared page.
/// Why: Bounded reference count to prevent overflow.
const MAX_REF_COUNT: u32 = 255;

/// COW page entry.
/// Why: Track reference count and COW state for each page.
/// GrainStyle: Static allocation, explicit state tracking.
pub const CowPageEntry = struct {
    /// Reference count (number of processes sharing this page).
    /// Why: Track how many processes share this page.
    ref_count: u32 = 0,
    
    /// Whether this page is marked for copy-on-write.
    /// Why: Track if page should be copied on write.
    cow_marked: bool = false,
    
    /// Initialize empty COW page entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() CowPageEntry {
        return CowPageEntry{
            .ref_count = 0,
            .cow_marked = false,
        };
    }
    
    /// Check if page is shared (ref_count > 1).
    /// Why: Determine if page is shared between processes.
    pub fn is_shared(self: CowPageEntry) bool {
        return self.ref_count > 1;
    }
    
    /// Check if page should be copied on write.
    /// Why: Determine if COW should trigger on write.
    pub fn should_copy_on_write(self: CowPageEntry) bool {
        return self.cow_marked and self.ref_count > 1;
    }
};

/// COW page table.
/// Why: Track reference counts and COW state for all pages in VM memory.
/// GrainStyle: Static allocation, max 1024 pages (4MB VM).
pub const CowTable = struct {
    /// COW page entries (one per 4KB page).
    /// Why: Static array for bounded allocation.
    pages: [MAX_PAGES]CowPageEntry = [_]CowPageEntry{CowPageEntry.init()} ** MAX_PAGES,
    
    /// Initialize COW table.
    /// Why: Explicit initialization, clear state.
    pub fn init() CowTable {
        const table = CowTable{};
        
        // Assert: All pages must be initialized (precondition).
        for (table.pages) |page| {
            Debug.kassert(page.ref_count == 0, "Page ref count not zero", .{});
            Debug.kassert(!page.cow_marked, "Page already COW marked", .{});
        }
        
        return table;
    }
    
    /// Get page index from address.
    /// Why: Convert address to page index for table lookup.
    /// Contract: Address must be valid (within VM memory bounds).
    /// Returns: Page index (0-1023), or null if address is out of bounds.
    pub fn get_page_index(addr: u64) ?u32 {
        // Assert: Address must be valid (precondition).
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (addr >= VM_MEMORY_SIZE) {
            return null; // Out of bounds
        }
        
        const page_idx = @as(u32, @intCast(addr / PAGE_SIZE));
        
        // Assert: Page index must be within bounds (postcondition).
        Debug.kassert(page_idx < MAX_PAGES, "Page index out of bounds", .{});
        
        return page_idx;
    }
    
    /// Get COW page entry for address.
    /// Why: Look up COW state for a given address.
    /// Contract: Address must be valid, returns page entry (may be unshared).
    /// Returns: COW page entry for the page containing the address, or null if out of bounds.
    pub fn get_page(self: *const CowTable, addr: u64) ?*const CowPageEntry {
        const page_idx = CowTable.get_page_index(addr) orelse {
            return null; // Out of bounds
        };
        
        // Assert: Page index must be valid (postcondition).
        Debug.kassert(page_idx < MAX_PAGES, "Page index out of bounds", .{});
        
        return @ptrCast(&self.pages[page_idx]);
    }
    
    /// Increment reference count for pages in address range.
    /// Why: Track that pages are being shared (mapped by another process).
    /// Contract: Address and size must be page-aligned, size must be non-zero.
    /// Returns: Error if invalid arguments, success if reference counts incremented.
    pub fn increment_refs(
        self: *CowTable,
        addr: u64,
        size: u64,
        mark_cow: bool,
    ) void {
        // Assert: Address must be page-aligned (precondition).
        Debug.kassert(addr % PAGE_SIZE == 0, "Address not page-aligned", .{});
        
        // Assert: Size must be page-aligned and non-zero (precondition).
        Debug.kassert(size > 0, "Size is zero", .{});
        Debug.kassert(size % PAGE_SIZE == 0, "Size not page-aligned", .{});
        
        const start_page = CowTable.get_page_index(addr).?;
        const num_pages = @as(u32, @intCast(size / PAGE_SIZE));
        const end_page = start_page + num_pages;
        
        // Assert: End page must be within bounds (precondition).
        Debug.kassert(end_page <= MAX_PAGES, "End page out of bounds", .{});
        
        // Increment reference counts for all pages in range.
        for (start_page..end_page) |page_idx| {
            const page = &self.pages[page_idx];
            
            // Assert: Reference count must not overflow (precondition).
            Debug.kassert(page.ref_count < MAX_REF_COUNT, "Ref count overflow", .{});
            
            page.ref_count += 1;
            if (mark_cow) {
                page.cow_marked = true;
            }
            
            // Assert: Reference count must be incremented (postcondition).
            Debug.kassert(page.ref_count > 0, "Ref count not incremented", .{});
        }
    }
    
    /// Decrement reference count for pages in address range.
    /// Why: Track that pages are no longer shared (unmapped by a process).
    /// Contract: Address and size must be page-aligned, size must be non-zero.
    /// Returns: Error if invalid arguments, success if reference counts decremented.
    pub fn decrement_refs(
        self: *CowTable,
        addr: u64,
        size: u64,
    ) void {
        // Assert: Address must be page-aligned (precondition).
        Debug.kassert(addr % PAGE_SIZE == 0, "Address not page-aligned", .{});
        
        // Assert: Size must be page-aligned and non-zero (precondition).
        Debug.kassert(size > 0, "Size is zero", .{});
        Debug.kassert(size % PAGE_SIZE == 0, "Size not page-aligned", .{});
        
        const start_page = CowTable.get_page_index(addr).?;
        const num_pages = @as(u32, @intCast(size / PAGE_SIZE));
        const end_page = start_page + num_pages;
        
        // Assert: End page must be within bounds (precondition).
        Debug.kassert(end_page <= MAX_PAGES, "End page out of bounds", .{});
        
        // Decrement reference counts for all pages in range.
        for (start_page..end_page) |page_idx| {
            const page = &self.pages[page_idx];
            
            // Assert: Reference count must be non-zero (precondition).
            Debug.kassert(page.ref_count > 0, "Ref count is zero", .{});
            
            page.ref_count -= 1;
            
            // Clear COW mark if reference count reaches 1 or 0.
            if (page.ref_count <= 1) {
                page.cow_marked = false;
            }
            
            // Assert: Reference count must be decremented (postcondition).
            Debug.kassert(page.ref_count < MAX_REF_COUNT, "Ref count not decremented", .{});
        }
    }
    
    /// Check if page should be copied on write.
    /// Why: Determine if COW should trigger for a write to this address.
    /// Contract: Address must be valid.
    /// Returns: true if page should be copied, false otherwise.
    pub fn should_copy_on_write(self: *const CowTable, addr: u64) bool {
        const page = self.get_page(addr) orelse {
            return false; // Out of bounds
        };
        
        return page.*.should_copy_on_write();
    }
    
    /// Get reference count for a page.
    /// Why: Query how many processes share a page.
    /// Contract: Address must be valid.
    /// Returns: Reference count for the page, or 0 if out of bounds.
    pub fn get_ref_count(self: *const CowTable, addr: u64) u32 {
        const page = self.get_page(addr) orelse {
            return 0; // Out of bounds
        };
        
        return page.*.ref_count;
    }
    
    /// Check if page is shared.
    /// Why: Determine if page is shared between multiple processes.
    /// Contract: Address must be valid.
    /// Returns: true if page is shared (ref_count > 1), false otherwise.
    pub fn is_shared(self: *const CowTable, addr: u64) bool {
        const page = self.get_page(addr) orelse {
            return false; // Out of bounds
        };
        
        return page.*.is_shared();
    }
};

