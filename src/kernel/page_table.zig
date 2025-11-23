//! Page Table Implementation
//! Why: Page-level memory protection for fine-grained access control.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Page size (4KB, standard RISC-V page size).
/// Why: Explicit constant for page size, matches RISC-V standard.
pub const PAGE_SIZE: u64 = 4096;

/// Maximum number of pages in VM memory (4MB / 4KB = 1024 pages).
/// Why: Bounded allocation, prevents unbounded growth.
pub const MAX_PAGES: u32 = 1024;

/// Page permissions flags (matches MapFlags from basin_kernel).
/// Why: Explicit flags instead of POSIX-style bitmasks for type safety.
pub const PageFlags = packed struct {
    read: bool = false,
    write: bool = false,
    execute: bool = false,
    shared: bool = false,
    _padding: u28 = 0,
    
    /// Create PageFlags from boolean values.
    /// Why: Explicit construction, no magic numbers.
    pub fn init(flags: struct {
        read: bool = false,
        write: bool = false,
        execute: bool = false,
        shared: bool = false,
    }) PageFlags {
        return PageFlags{
            .read = flags.read,
            .write = flags.write,
            .execute = flags.execute,
            .shared = flags.shared,
            ._padding = 0,
        };
    }
};

/// Page table entry.
/// Why: Track permissions for each 4KB page in VM memory.
/// Grain Style: Static allocation, explicit state tracking.
pub const PageEntry = struct {
    /// Page permissions (read, write, execute).
    flags: PageFlags,
    /// Whether this page is mapped (allocated).
    mapped: bool,
    
    /// Initialize empty page entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() PageEntry {
        return PageEntry{
            .flags = PageFlags.init(.{}),
            .mapped = false,
        };
    }
    
    /// Check if page has read permission.
    /// Why: Explicit permission check, no magic numbers.
    pub fn can_read(self: PageEntry) bool {
        return self.mapped and self.flags.read;
    }
    
    /// Check if page has write permission.
    /// Why: Explicit permission check, no magic numbers.
    pub fn can_write(self: PageEntry) bool {
        return self.mapped and self.flags.write;
    }
    
    /// Check if page has execute permission.
    /// Why: Explicit permission check, no magic numbers.
    pub fn can_execute(self: PageEntry) bool {
        return self.mapped and self.flags.execute;
    }
};

/// Page table.
/// Why: Track page-level permissions for all pages in VM memory.
/// Grain Style: Static allocation, max 1024 pages (4MB VM).
pub const PageTable = struct {
    /// Page entries (one per 4KB page).
    /// Why: Static array for bounded allocation.
    pages: [MAX_PAGES]PageEntry = [_]PageEntry{PageEntry.init()} ** MAX_PAGES,
    
    /// Initialize page table.
    /// Why: Explicit initialization, clear state.
    pub fn init() PageTable {
        const table = PageTable{};
        
        // Assert: All pages must be initialized (precondition).
        for (table.pages) |page| {
            Debug.kassert(!page.mapped, "Page already mapped", .{});
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
        
        const page_idx_u64 = addr / PAGE_SIZE;
        const page_idx = @as(u32, @intCast(page_idx_u64));
        
        // Assert: Page index must be within bounds (postcondition).
        Debug.kassert(page_idx < MAX_PAGES, "Page index out of bounds", .{});
        
        return page_idx;
    }
    
    /// Get page entry for address (read-only).
    /// Why: Look up page permissions for a given address (for reading).
    /// Contract: Address must be valid, returns page entry (may be unmapped).
    /// Returns: Page entry for the page containing the address, or null if out of bounds.
    pub fn get_page(self: *const PageTable, addr: u64) ?*const PageEntry {
        const page_idx = PageTable.get_page_index(addr) orelse {
            return null; // Out of bounds
        };
        
        // Assert: Page index must be valid (postcondition).
        Debug.kassert(page_idx < MAX_PAGES, "Page index out of bounds", .{});
        
        return &self.pages[page_idx];
    }
    
    /// Map pages in address range.
    /// Why: Set permissions for a contiguous range of pages.
    /// Contract: Address and size must be page-aligned, size must be non-zero.
    /// Returns: Error if invalid arguments, success if pages mapped.
    pub fn map_pages(
        self: *PageTable,
        addr: u64,
        size: u64,
        flags: PageFlags,
    ) void {
        // Assert: Address must be page-aligned (precondition).
        Debug.kassert(addr % PAGE_SIZE == 0, "Address not page-aligned", .{});
        
        // Assert: Size must be page-aligned and non-zero (precondition).
        Debug.kassert(size > 0, "Size is zero", .{});
        Debug.kassert(size % PAGE_SIZE == 0, "Size not page-aligned", .{});
        
        // Assert: Flags must have at least one permission (precondition).
        Debug.kassert(flags.read or flags.write or flags.execute, "No permissions set", .{});
        
        const start_page = PageTable.get_page_index(addr).?;
        const num_pages = @as(u32, @intCast(size / PAGE_SIZE));
        const end_page = start_page + num_pages;
        
        // Assert: End page must be within bounds (precondition).
        Debug.kassert(end_page <= MAX_PAGES, "End page out of bounds", .{});
        
        // Map all pages in range.
        for (start_page..end_page) |page_idx| {
            const page = &self.pages[page_idx];
            page.flags = flags;
            page.mapped = true;
            
            // Assert: Page must be mapped correctly (postcondition).
            Debug.kassert(page.mapped, "Page not mapped", .{});
            Debug.kassert(page.flags.read == flags.read, "Read flag mismatch", .{});
            Debug.kassert(page.flags.write == flags.write, "Write flag mismatch", .{});
            Debug.kassert(page.flags.execute == flags.execute, "Execute flag mismatch", .{});
        }
    }
    
    /// Unmap pages in address range.
    /// Why: Clear permissions for a contiguous range of pages.
    /// Contract: Address and size must be page-aligned, size must be non-zero.
    /// Returns: Error if invalid arguments, success if pages unmapped.
    pub fn unmap_pages(
        self: *PageTable,
        addr: u64,
        size: u64,
    ) void {
        // Assert: Address must be page-aligned (precondition).
        Debug.kassert(addr % PAGE_SIZE == 0, "Address not page-aligned", .{});
        
        // Assert: Size must be page-aligned and non-zero (precondition).
        Debug.kassert(size > 0, "Size is zero", .{});
        Debug.kassert(size % PAGE_SIZE == 0, "Size not page-aligned", .{});
        
        const start_page = PageTable.get_page_index(addr).?;
        const num_pages = @as(u32, @intCast(size / PAGE_SIZE));
        const end_page = start_page + num_pages;
        
        // Assert: End page must be within bounds (precondition).
        Debug.kassert(end_page <= MAX_PAGES, "End page out of bounds", .{});
        
        // Unmap all pages in range.
        for (start_page..end_page) |page_idx| {
            const page = &self.pages[page_idx];
            page.mapped = false;
            page.flags = PageFlags.init(.{});
            
            // Assert: Page must be unmapped correctly (postcondition).
            Debug.kassert(!page.mapped, "Page still mapped", .{});
        }
    }
    
    /// Update permissions for pages in address range.
    /// Why: Change permissions for a contiguous range of pages.
    /// Contract: Address and size must be page-aligned, size must be non-zero.
    /// Returns: Error if invalid arguments, success if permissions updated.
    pub fn protect_pages(
        self: *PageTable,
        addr: u64,
        size: u64,
        flags: PageFlags,
    ) void {
        // Assert: Address must be page-aligned (precondition).
        Debug.kassert(addr % PAGE_SIZE == 0, "Address not page-aligned", .{});
        
        // Assert: Size must be page-aligned and non-zero (precondition).
        Debug.kassert(size > 0, "Size is zero", .{});
        Debug.kassert(size % PAGE_SIZE == 0, "Size not page-aligned", .{});
        
        // Assert: Flags must have at least one permission (precondition).
        Debug.kassert(flags.read or flags.write or flags.execute, "No permissions set", .{});
        
        const start_page = PageTable.get_page_index(addr).?;
        const num_pages = @as(u32, @intCast(size / PAGE_SIZE));
        const end_page = start_page + num_pages;
        
        // Assert: End page must be within bounds (precondition).
        Debug.kassert(end_page <= MAX_PAGES, "End page out of bounds", .{});
        
        // Update permissions for all pages in range.
        for (start_page..end_page) |page_idx| {
            const page = &self.pages[page_idx];
            
            // Assert: Page must be mapped (precondition).
            Debug.kassert(page.mapped, "Page not mapped", .{});
            
            page.flags = flags;
            
            // Assert: Permissions must be updated correctly (postcondition).
            Debug.kassert(page.flags.read == flags.read, "Read flag mismatch", .{});
            Debug.kassert(page.flags.write == flags.write, "Write flag mismatch", .{});
            Debug.kassert(page.flags.execute == flags.execute, "Execute flag mismatch", .{});
        }
    }
    
    /// Check memory permissions for an address.
    /// Why: Enforce memory protection by checking read/write/execute permissions.
    /// Contract: Address must be valid, returns permissions if mapped, null if not mapped.
    /// Returns: PageFlags with permissions, or null if address is not mapped.
    /// Note: Kernel space (0x80000000+) and framebuffer (0x90000000+) are always readable/writable.
    pub fn check_permission(self: *const PageTable, addr: u64) ?PageFlags {
        // Assert: Address must be valid (precondition).
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (addr >= VM_MEMORY_SIZE) {
            return null; // Out of bounds
        }
        
        // Kernel space (0x80000000+) always has all permissions.
        if (addr >= 0x80000000 and addr < 0x90000000) {
            return PageFlags.init(.{ .read = true, .write = true, .execute = true });
        }
        
        // Framebuffer space (0x90000000+) always has read/write permissions.
        if (addr >= 0x90000000) {
            return PageFlags.init(.{ .read = true, .write = true, .execute = false });
        }
        
        // Check page table for user space.
        const page = self.get_page(addr) orelse {
            return null; // Out of bounds
        };
        
        if (!page.mapped) {
            return null; // Page not mapped
        }
        
        return page.flags;
    }
};

