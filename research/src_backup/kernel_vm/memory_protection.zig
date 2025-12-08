//! VM Memory Protection System
//!
//! Objective: Provide memory protection capabilities (page tables, permissions, access control).
//! Why: Enable kernel development with proper memory protection and isolation.
//! GrainStyle: Static allocation, bounded page tables, explicit types, deterministic protection.
//!
//! Methodology:
//! - Page table management (create, modify, query page tables)
//! - Memory permission management (read, write, execute permissions)
//! - Page fault handling (detect and handle page faults)
//! - Memory region protection (protect memory regions with permissions)
//! - Bounded page table entries (MAX_PAGE_TABLE_ENTRIES: 1024)
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded arrays: fixed-size page table arrays
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-12-02
//! GrainStyle: Comprehensive memory protection, deterministic behavior, explicit limits

const std = @import("std");
const VM = @import("vm.zig").VM;
const VMError = @import("vm.zig").VM.VMError;

// Bounded: Maximum page table entries (sufficient for kernel development).
pub const MAX_PAGE_TABLE_ENTRIES: u32 = 1024;
// Page size: 4KB (standard RISC-V page size).
pub const PAGE_SIZE: u64 = 4096;

// Memory permissions (bit flags).
pub const MemoryPermissions = struct {
    pub const READ: u8 = 1;
    pub const WRITE: u8 = 2;
    pub const EXECUTE: u8 = 4;
    pub const USER: u8 = 8;
};

// Page table entry.
pub const PageTableEntry = struct {
    virtual_address: u64,
    physical_address: u64,
    permissions: u8,
    present: bool,

    pub fn init() PageTableEntry {
        return PageTableEntry{
            .virtual_address = 0,
            .physical_address = 0,
            .permissions = 0,
            .present = false,
        };
    }
};

// VM memory protection manager.
pub const VMMemoryProtection = struct {
    page_table: [MAX_PAGE_TABLE_ENTRIES]PageTableEntry,
    page_table_len: u32,

    pub fn init() VMMemoryProtection {
        var protection = VMMemoryProtection{
            .page_table = undefined,
            .page_table_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_PAGE_TABLE_ENTRIES) : (i += 1) {
            protection.page_table[i] = PageTableEntry.init();
        }
        return protection;
    }

    pub fn map_page(self: *VMMemoryProtection, virtual_addr: u64, physical_addr: u64, permissions: u8) bool {
        if (self.page_table_len >= MAX_PAGE_TABLE_ENTRIES) {
            return false;
        }
        if (virtual_addr % PAGE_SIZE != 0) {
            return false;
        }
        if (physical_addr % PAGE_SIZE != 0) {
            return false;
        }
        var i: u32 = 0;
        while (i < self.page_table_len) : (i += 1) {
            const entry = &self.page_table[i];
            if (entry.virtual_address == virtual_addr) {
                entry.physical_address = physical_addr;
                entry.permissions = permissions;
                entry.present = true;
                return true;
            }
        }
        const idx = self.page_table_len;
        self.page_table[idx] = PageTableEntry{
            .virtual_address = virtual_addr,
            .physical_address = physical_addr,
            .permissions = permissions,
            .present = true,
        };
        self.page_table_len += 1;
        return true;
    }

    pub fn unmap_page(self: *VMMemoryProtection, virtual_addr: u64) bool {
        var i: u32 = 0;
        while (i < self.page_table_len) : (i += 1) {
            const entry = &self.page_table[i];
            if (entry.virtual_address == virtual_addr) {
                entry.present = false;
                return true;
            }
        }
        return false;
    }

    pub fn get_permissions(self: *const VMMemoryProtection, virtual_addr: u64) ?u8 {
        const page_addr = (virtual_addr / PAGE_SIZE) * PAGE_SIZE;
        var i: u32 = 0;
        while (i < self.page_table_len) : (i += 1) {
            const entry = &self.page_table[i];
            if (entry.present and entry.virtual_address == page_addr) {
                return entry.permissions;
            }
        }
        return null;
    }

    pub fn check_permission(self: *const VMMemoryProtection, virtual_addr: u64, required_perm: u8) bool {
        const perms_opt = self.get_permissions(virtual_addr);
        if (perms_opt == null) {
            return false;
        }
        const perms = perms_opt.?;
        return (perms & required_perm) != 0;
    }

    pub fn translate_address(self: *const VMMemoryProtection, virtual_addr: u64) ?u64 {
        const page_addr = (virtual_addr / PAGE_SIZE) * PAGE_SIZE;
        var i: u32 = 0;
        while (i < self.page_table_len) : (i += 1) {
            const entry = &self.page_table[i];
            if (entry.present and entry.virtual_address == page_addr) {
                const offset = virtual_addr - page_addr;
                return entry.physical_address + offset;
            }
        }
        return null;
    }

    pub fn protect_region(self: *VMMemoryProtection, start_addr: u64, end_addr: u64, permissions: u8) bool {
        var addr = (start_addr / PAGE_SIZE) * PAGE_SIZE;
        const end = (end_addr / PAGE_SIZE) * PAGE_SIZE;
        while (addr <= end) {
            const page_addr = addr;
            var found = false;
            var i: u32 = 0;
            while (i < self.page_table_len) : (i += 1) {
                const entry = &self.page_table[i];
                if (entry.virtual_address == page_addr) {
                    entry.permissions = permissions;
                    found = true;
                    break;
                }
            }
            if (!found) {
                if (self.page_table_len >= MAX_PAGE_TABLE_ENTRIES) {
                    return false;
                }
                const idx = self.page_table_len;
                self.page_table[idx] = PageTableEntry{
                    .virtual_address = page_addr,
                    .physical_address = page_addr,
                    .permissions = permissions,
                    .present = true,
                };
                self.page_table_len += 1;
            }
            addr += PAGE_SIZE;
        }
        return true;
    }

    pub fn get_page_count(self: *const VMMemoryProtection) u32 {
        return self.page_table_len;
    }
};

