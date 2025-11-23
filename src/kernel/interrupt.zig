//! Grain Basin Interrupt Controller
//! Why: Handle interrupts (timer, external, software) for kernel.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Interrupt type (RISC-V interrupt types).
/// Why: Explicit interrupt types for type safety.
pub const InterruptType = enum(u32) {
    /// Software interrupt (from other cores or software).
    software = 1,
    /// Timer interrupt (from SBI timer or hardware timer).
    timer = 5,
    /// External interrupt (from devices, keyboard, mouse, etc.).
    external = 9,
};

/// Interrupt handler function type.
/// Why: Type-safe interrupt handler registration.
/// Contract: Handler must be fast, non-blocking, and return void.
pub const InterruptHandler = *const fn (interrupt_type: InterruptType, context: ?*anyopaque) void;

/// Interrupt context (optional data for handler).
/// Why: Allow handlers to access kernel state or device data.
pub const InterruptContext = struct {
    /// Context data (opaque pointer).
    data: ?*anyopaque,
    /// Context type identifier (for type safety).
    type_id: u32,
};

/// Interrupt controller for Grain Basin kernel.
/// Why: Central interrupt handling, routing, and dispatch.
/// Grain Style: Static allocation, explicit state tracking.
pub const InterruptController = struct {
    /// Timer interrupt handler (optional).
    /// Why: Register handler for timer interrupts.
    timer_handler: ?InterruptHandler = null,
    /// Timer interrupt context (optional).
    /// Why: Pass context to timer handler.
    timer_context: ?*anyopaque = null,
    
    /// External interrupt handler (optional).
    /// Why: Register handler for external interrupts.
    external_handler: ?InterruptHandler = null,
    /// External interrupt context (optional).
    /// Why: Pass context to external handler.
    external_context: ?*anyopaque = null,
    
    /// Software interrupt handler (optional).
    /// Why: Register handler for software interrupts.
    software_handler: ?InterruptHandler = null,
    /// Software interrupt context (optional).
    /// Why: Pass context to software handler.
    software_context: ?*anyopaque = null,
    
    /// Pending interrupts (bitmask).
    /// Why: Track pending interrupts for deferred handling.
    pending: u32 = 0,
    
    /// Whether interrupt controller is initialized.
    /// Why: Track initialization state for safety.
    initialized: bool = false,
    
    /// Initialize interrupt controller.
    /// Why: Set up interrupt controller state.
    /// Contract: Must be called once at kernel boot.
    pub fn init() InterruptController {
        return InterruptController{
            .timer_handler = null,
            .timer_context = null,
            .external_handler = null,
            .external_context = null,
            .software_handler = null,
            .software_context = null,
            .pending = 0,
            .initialized = true,
        };
    }
    
    /// Register timer interrupt handler.
    /// Why: Set handler for timer interrupts.
    /// Contract: Handler must be fast, non-blocking.
    pub fn register_timer_handler(
        self: *InterruptController,
        handler: InterruptHandler,
        context: ?*anyopaque,
    ) void {
        // Assert: Interrupt controller must be initialized.
        Debug.kassert(self.initialized, "Interrupt controller not initialized", .{});
        
        // Assert: Handler must be non-null.
        const handler_ptr = @intFromPtr(handler);
        Debug.kassert(handler_ptr != 0, "Handler is null", .{});
        
        // Register handler and context.
        self.timer_handler = handler;
        self.timer_context = context;
        
        // Assert: Handler must be registered.
        Debug.kassert(self.timer_handler != null, "Handler not registered", .{});
    }
    
    /// Register external interrupt handler.
    /// Why: Set handler for external interrupts (devices).
    /// Contract: Handler must be fast, non-blocking.
    pub fn register_external_handler(
        self: *InterruptController,
        handler: InterruptHandler,
        context: ?*anyopaque,
    ) void {
        // Assert: Interrupt controller must be initialized.
        Debug.kassert(self.initialized, "Interrupt controller not initialized", .{});
        
        // Assert: Handler must be non-null.
        const handler_ptr = @intFromPtr(handler);
        Debug.kassert(handler_ptr != 0, "Handler is null", .{});
        
        // Register handler and context.
        self.external_handler = handler;
        self.external_context = context;
        
        // Assert: Handler must be registered.
        Debug.kassert(self.external_handler != null, "Handler not registered", .{});
    }
    
    /// Register software interrupt handler.
    /// Why: Set handler for software interrupts (IPC, etc.).
    /// Contract: Handler must be fast, non-blocking.
    pub fn register_software_handler(
        self: *InterruptController,
        handler: InterruptHandler,
        context: ?*anyopaque,
    ) void {
        // Assert: Interrupt controller must be initialized.
        Debug.kassert(self.initialized, "Interrupt controller not initialized", .{});
        
        // Assert: Handler must be non-null.
        const handler_ptr = @intFromPtr(handler);
        Debug.kassert(handler_ptr != 0, "Handler is null", .{});
        
        // Register handler and context.
        self.software_handler = handler;
        self.software_context = context;
        
        // Assert: Handler must be registered.
        Debug.kassert(self.software_handler != null, "Handler not registered", .{});
    }
    
    /// Handle interrupt (dispatch to registered handler).
    /// Why: Central interrupt dispatch, route to appropriate handler.
    /// Contract: Interrupt type must be valid, handler must be registered.
    pub fn handle_interrupt(
        self: *InterruptController,
        interrupt_type: InterruptType,
    ) void {
        // Assert: Interrupt controller must be initialized.
        Debug.kassert(self.initialized, "Interrupt controller not initialized", .{});
        
        // Dispatch based on interrupt type.
        switch (interrupt_type) {
            .timer => {
                if (self.timer_handler) |handler| {
                    // Assert: Handler must be non-null.
                    const handler_ptr = @intFromPtr(handler);
                    Debug.kassert(handler_ptr != 0, "Timer handler is null", .{});
                    
                    // Call timer handler.
                    handler(interrupt_type, self.timer_context);
                }
            },
            .external => {
                if (self.external_handler) |handler| {
                    // Assert: Handler must be non-null.
                    const handler_ptr = @intFromPtr(handler);
                    Debug.kassert(handler_ptr != 0, "External handler is null", .{});
                    
                    // Call external handler.
                    handler(interrupt_type, self.external_context);
                }
            },
            .software => {
                if (self.software_handler) |handler| {
                    // Assert: Handler must be non-null.
                    const handler_ptr = @intFromPtr(handler);
                    Debug.kassert(handler_ptr != 0, "Software handler is null", .{});
                    
                    // Call software handler.
                    handler(interrupt_type, self.software_context);
                }
            },
        }
    }
    
    /// Mark interrupt as pending (deferred handling).
    /// Why: Allow interrupts to be handled later (e.g., in main loop).
    /// Contract: Interrupt type must be valid.
    pub fn mark_pending(self: *InterruptController, interrupt_type: InterruptType) void {
        // Assert: Interrupt controller must be initialized.
        Debug.kassert(self.initialized, "Interrupt controller not initialized", .{});
        
        // Set pending bit for interrupt type.
        const interrupt_id = @as(u5, @intCast(@intFromEnum(interrupt_type)));
        self.pending |= (@as(u32, 1) << interrupt_id);
        
        // Assert: Pending bit must be set.
        Debug.kassert((self.pending & (@as(u32, 1) << interrupt_id)) != 0, "Pending bit not set", .{});
    }
    
    /// Process pending interrupts.
    /// Why: Handle deferred interrupts in main loop.
    /// Contract: Must be called periodically (e.g., in trap loop).
    pub fn process_pending(self: *InterruptController) void {
        // Assert: Interrupt controller must be initialized.
        Debug.kassert(self.initialized, "Interrupt controller not initialized", .{});
        
        // Process timer interrupt if pending.
        if ((self.pending & (@as(u32, 1) << @intFromEnum(InterruptType.timer))) != 0) {
            self.handle_interrupt(.timer);
            self.pending &= ~(@as(u32, 1) << @intFromEnum(InterruptType.timer));
        }
        
        // Process external interrupt if pending.
        if ((self.pending & (@as(u32, 1) << @intFromEnum(InterruptType.external))) != 0) {
            self.handle_interrupt(.external);
            self.pending &= ~(@as(u32, 1) << @intFromEnum(InterruptType.external));
        }
        
        // Process software interrupt if pending.
        if ((self.pending & (@as(u32, 1) << @intFromEnum(InterruptType.software))) != 0) {
            self.handle_interrupt(.software);
            self.pending &= ~(@as(u32, 1) << @intFromEnum(InterruptType.software));
        }
    }
    
    /// Check if interrupt is pending.
    /// Why: Query pending interrupt state.
    /// Contract: Interrupt type must be valid.
    pub fn is_pending(self: *const InterruptController, interrupt_type: InterruptType) bool {
        // Assert: Interrupt controller must be initialized.
        Debug.kassert(self.initialized, "Interrupt controller not initialized", .{});
        
        const interrupt_id = @as(u5, @intCast(@intFromEnum(interrupt_type)));
        return (self.pending & (@as(u32, 1) << interrupt_id)) != 0;
    }
    
    /// Clear pending interrupt.
    /// Why: Clear pending interrupt state.
    /// Contract: Interrupt type must be valid.
    pub fn clear_pending(self: *InterruptController, interrupt_type: InterruptType) void {
        // Assert: Interrupt controller must be initialized.
        Debug.kassert(self.initialized, "Interrupt controller not initialized", .{});
        
        const interrupt_id = @as(u5, @intCast(@intFromEnum(interrupt_type)));
        self.pending &= ~(@as(u32, 1) << interrupt_id);
        
        // Assert: Pending bit must be cleared.
        Debug.kassert((self.pending & (@as(u32, 1) << interrupt_id)) == 0, "Pending bit not cleared", .{});
    }
};

// Test interrupt controller initialization.
test "interrupt controller init" {
    const controller = InterruptController.init();
    
    // Assert: Controller must be initialized.
    try std.testing.expect(controller.initialized);
    try std.testing.expect(controller.pending == 0);
    try std.testing.expect(controller.timer_handler == null);
}

// Test timer handler registration.
test "interrupt controller register timer" {
    var controller = InterruptController.init();
    
    var handler_called_ptr = struct {
        value: bool = false,
    }{};
    
    const handler: InterruptHandler = struct {
        fn handle(_: InterruptType, ctx: ?*anyopaque) void {
            if (ctx) |c| {
                const called = @as(*struct { value: bool }, @ptrCast(@alignCast(c)));
                called.value = true;
            }
        }
    }.handle;
    
    controller.register_timer_handler(handler, &handler_called_ptr);
    
    // Assert: Handler must be registered.
    try std.testing.expect(controller.timer_handler != null);
    
    // Test handler call.
    controller.handle_interrupt(.timer);
    
    // Assert: Handler must be called.
    try std.testing.expect(handler_called_ptr.value);
}

// Test pending interrupts.
test "interrupt controller pending" {
    var controller = InterruptController.init();
    
    // Mark timer interrupt as pending.
    controller.mark_pending(.timer);
    
    // Assert: Timer interrupt must be pending.
    try std.testing.expect(controller.is_pending(.timer));
    
    // Clear pending.
    controller.clear_pending(.timer);
    
    // Assert: Timer interrupt must not be pending.
    try std.testing.expect(!controller.is_pending(.timer));
}

// Test process pending interrupts.
test "interrupt controller process pending" {
    var controller = InterruptController.init();
    
    var handler_called_ptr = struct {
        value: bool = false,
    }{};
    
    const handler: InterruptHandler = struct {
        fn handle(_: InterruptType, ctx: ?*anyopaque) void {
            if (ctx) |c| {
                const called = @as(*struct { value: bool }, @ptrCast(@alignCast(c)));
                called.value = true;
            }
        }
    }.handle;
    
    controller.register_timer_handler(handler, &handler_called_ptr);
    
    // Mark timer interrupt as pending.
    controller.mark_pending(.timer);
    
    // Process pending interrupts.
    controller.process_pending();
    
    // Assert: Handler must be called.
    try std.testing.expect(handler_called_ptr.value);
    
    // Assert: Pending must be cleared.
    try std.testing.expect(!controller.is_pending(.timer));
}

