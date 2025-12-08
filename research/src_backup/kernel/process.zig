//! Grain Basin Process Management
//! Why: Enhanced process management with ELF loading support.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Process execution context.
/// Why: Track process execution state (PC, SP, registers).
/// Grain Style: Static allocation, explicit state tracking.
pub const ProcessContext = struct {
    /// Program counter (entry point or current PC).
    /// Why: Track where process execution starts or continues.
    pc: u64,
    /// Stack pointer (initial SP or current SP).
    /// Why: Track process stack location.
    sp: u64,
    /// Entry point (from ELF header).
    /// Why: Track original entry point for restart/debugging.
    entry_point: u64,
    /// Whether context is initialized.
    /// Why: Track initialization state for safety.
    initialized: bool,
    
    /// Initialize process context.
    /// Why: Set up process execution context.
    /// Contract: pc and sp must be valid addresses within VM memory.
    pub fn init(pc: u64, sp: u64, entry_point: u64) ProcessContext {
        // Assert: PC must be non-zero (valid entry point).
        Debug.kassert(pc != 0, "PC is 0", .{});
        
        // Assert: SP must be non-zero (valid stack pointer).
        Debug.kassert(sp != 0, "SP is 0", .{});
        
        // Assert: Entry point must match PC (for initial context).
        Debug.kassert(entry_point == pc, "Entry point != PC", .{});
        
        return ProcessContext{
            .pc = pc,
            .sp = sp,
            .entry_point = entry_point,
            .initialized = true,
        };
    }
    
    /// Update program counter.
    /// Why: Track process execution progress.
    /// Contract: pc must be valid address.
    pub fn update_pc(self: *ProcessContext, pc: u64) void {
        // Assert: Context must be initialized.
        Debug.kassert(self.initialized, "Context not initialized", .{});
        
        // Assert: PC must be non-zero.
        Debug.kassert(pc != 0, "PC is 0", .{});
        
        self.pc = pc;
        
        // Assert: PC must be updated.
        Debug.kassert(self.pc == pc, "PC not updated", .{});
    }
    
    /// Get program counter.
    /// Why: Query current execution position.
    /// Contract: Context must be initialized.
    pub fn get_pc(self: *const ProcessContext) u64 {
        // Assert: Context must be initialized.
        Debug.kassert(self.initialized, "Context not initialized", .{});
        
        // Assert: PC must be non-zero.
        Debug.kassert(self.pc != 0, "PC is 0", .{});
        
        return self.pc;
    }
    
    /// Get stack pointer.
    /// Why: Query current stack position.
    /// Contract: Context must be initialized.
    pub fn get_sp(self: *const ProcessContext) u64 {
        // Assert: Context must be initialized.
        Debug.kassert(self.initialized, "Context not initialized", .{});
        
        // Assert: SP must be non-zero.
        Debug.kassert(self.sp != 0, "SP is 0", .{});
        
        return self.sp;
    }
    
    /// Reset to entry point.
    /// Why: Restart process execution from beginning.
    /// Contract: Context must be initialized.
    pub fn reset(self: *ProcessContext) void {
        // Assert: Context must be initialized.
        Debug.kassert(self.initialized, "Context not initialized", .{});
        
        // Assert: Entry point must be non-zero.
        Debug.kassert(self.entry_point != 0, "Entry point is 0", .{});
        
        self.pc = self.entry_point;
        
        // Assert: PC must be reset to entry point.
        Debug.kassert(self.pc == self.entry_point, "PC not reset", .{});
    }
};

// Test process context initialization.
test "process context init" {
    const context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    
    // Assert: Context must be initialized.
    try std.testing.expect(context.initialized);
    try std.testing.expect(context.pc == 0x10000);
    try std.testing.expect(context.sp == 0x400000);
    try std.testing.expect(context.entry_point == 0x10000);
}

// Test process context update PC.
test "process context update pc" {
    var context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    
    context.update_pc(0x10010);
    
    // Assert: PC must be updated.
    try std.testing.expect(context.get_pc() == 0x10010);
    try std.testing.expect(context.get_sp() == 0x400000);
}

// Test process context reset.
test "process context reset" {
    var context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    
    context.update_pc(0x10010);
    context.reset();
    
    // Assert: PC must be reset to entry point.
    try std.testing.expect(context.get_pc() == 0x10000);
    try std.testing.expect(context.entry_point == 0x10000);
}

