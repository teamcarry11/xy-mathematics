//! Interrupt Controller Tests
//! Why: Comprehensive TigerStyle tests for interrupt controller functionality.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const InterruptController = basin_kernel.basin_kernel.InterruptController;
const InterruptType = basin_kernel.basin_kernel.InterruptType;
const interrupt = @import("interrupt");
const InterruptHandler = interrupt.InterruptHandler;

// Test interrupt controller initialization.
test "interrupt controller init" {
    const controller = InterruptController.init();
    
    // Assert: Controller must be initialized.
    try std.testing.expect(controller.initialized);
    try std.testing.expect(controller.pending == 0);
    
    // Assert: All handlers must be null initially.
    try std.testing.expect(controller.timer_handler == null);
    try std.testing.expect(controller.external_handler == null);
    try std.testing.expect(controller.software_handler == null);
}

// Test timer handler registration.
test "interrupt controller register timer" {
    var controller = InterruptController.init();
    
    // Use a struct to hold mutable state (GrainStyle: no closures with mutable captures).
    const HandlerState = struct {
        called: bool = false,
        
        fn handle(state: *@This(), _: InterruptType, _: ?*anyopaque) void {
            state.called = true;
        }
    };
    
    var handler_state = HandlerState{};
    
    const handler: InterruptHandler = struct {
        fn handle_wrapper(interrupt_type: InterruptType, context: ?*anyopaque) void {
            const state = @as(*HandlerState, @ptrCast(context.?));
            HandlerState.handle(state, interrupt_type, null);
        }
    }.handle_wrapper;
    
    controller.register_timer_handler(handler, &handler_state);
    
    // Assert: Handler must be registered.
    try std.testing.expect(controller.timer_handler != null);
    
    // Test handler call.
    controller.handle_interrupt(.timer);
    
    // Assert: Handler must be called.
    try std.testing.expect(handler_state.called);
}

// Test external handler registration.
test "interrupt controller register external" {
    var controller = InterruptController.init();
    
    // Use a struct to hold mutable state (GrainStyle: no closures with mutable captures).
    const HandlerState = struct {
        called: bool = false,
        
        fn handle(state: *@This(), _: InterruptType, _: ?*anyopaque) void {
            state.called = true;
        }
    };
    
    var handler_state = HandlerState{};
    
    const handler: InterruptHandler = struct {
        fn handle_wrapper(interrupt_type: InterruptType, context: ?*anyopaque) void {
            const state = @as(*HandlerState, @ptrCast(context.?));
            HandlerState.handle(state, interrupt_type, null);
        }
    }.handle_wrapper;
    
    controller.register_external_handler(handler, &handler_state);
    
    // Assert: Handler must be registered.
    try std.testing.expect(controller.external_handler != null);
    
    // Test handler call.
    controller.handle_interrupt(.external);
    
    // Assert: Handler must be called.
    try std.testing.expect(handler_state.called);
}

// Test software handler registration.
test "interrupt controller register software" {
    var controller = InterruptController.init();
    
    // Use a struct to hold mutable state (GrainStyle: no closures with mutable captures).
    const HandlerState = struct {
        called: bool = false,
        
        fn handle(state: *@This(), _: InterruptType, _: ?*anyopaque) void {
            state.called = true;
        }
    };
    
    var handler_state = HandlerState{};
    
    const handler: InterruptHandler = struct {
        fn handle_wrapper(interrupt_type: InterruptType, context: ?*anyopaque) void {
            const state = @as(*HandlerState, @ptrCast(context.?));
            HandlerState.handle(state, interrupt_type, null);
        }
    }.handle_wrapper;
    
    controller.register_software_handler(handler, &handler_state);
    
    // Assert: Handler must be registered.
    try std.testing.expect(controller.software_handler != null);
    
    // Test handler call.
    controller.handle_interrupt(.software);
    
    // Assert: Handler must be called.
    try std.testing.expect(handler_state.called);
}

// Test handler with context.
test "interrupt controller handler context" {
    const controller = InterruptController.init();
    
    // Use a struct to hold mutable state (GrainStyle: no closures with mutable captures).
    const HandlerState = struct {
        received_context: ?*anyopaque = null,
        
        fn handle(state: *@This(), _: InterruptType, ctx: ?*anyopaque) void {
            state.received_context = ctx;
        }
    };
    
    var handler_state = HandlerState{};
    
    const handler: InterruptHandler = struct {
        fn handle_wrapper(interrupt_type: InterruptType, context: ?*anyopaque) void {
            const state = @as(*HandlerState, @ptrCast(context.?));
            HandlerState.handle(state, interrupt_type, context);
        }
    }.handle_wrapper;
    
    controller.register_timer_handler(handler, &handler_state);
    
    // Test handler call with context.
    controller.handle_interrupt(.timer);
    
    // Assert: Context must be passed to handler.
    try std.testing.expect(handler_state.received_context != null);
}

// Test pending interrupts.
test "interrupt controller pending" {
    var controller = InterruptController.init();
    
    // Mark timer interrupt as pending.
    controller.mark_pending(.timer);
    
    // Assert: Timer interrupt must be pending.
    try std.testing.expect(controller.is_pending(.timer));
    
    // Mark external interrupt as pending.
    controller.mark_pending(.external);
    
    // Assert: Both interrupts must be pending.
    try std.testing.expect(controller.is_pending(.timer));
    try std.testing.expect(controller.is_pending(.external));
    
    // Clear timer pending.
    controller.clear_pending(.timer);
    
    // Assert: Timer must not be pending, external must still be pending.
    try std.testing.expect(!controller.is_pending(.timer));
    try std.testing.expect(controller.is_pending(.external));
}

// Test process pending interrupts.
test "interrupt controller process pending" {
    var controller = InterruptController.init();
    
    // Use a struct to hold mutable state (GrainStyle: no closures with mutable captures).
    const HandlerState = struct {
        timer_called: bool = false,
        external_called: bool = false,
        
        fn handle_timer(state: *@This(), _: InterruptType, _: ?*anyopaque) void {
            state.timer_called = true;
        }
        
        fn handle_external(state: *@This(), _: InterruptType, _: ?*anyopaque) void {
            state.external_called = true;
        }
    };
    
    var handler_state = HandlerState{};
    
    const timer_handler: InterruptController.InterruptHandler = struct {
        fn handle_wrapper(interrupt_type: InterruptType, context: ?*anyopaque) void {
            const state = @as(*HandlerState, @ptrCast(context.?));
            HandlerState.handle_timer(state, interrupt_type, null);
        }
    }.handle_wrapper;
    
    const external_handler: InterruptController.InterruptHandler = struct {
        fn handle_wrapper(interrupt_type: InterruptType, context: ?*anyopaque) void {
            const state = @as(*HandlerState, @ptrCast(context.?));
            HandlerState.handle_external(state, interrupt_type, null);
        }
    }.handle_wrapper;
    
    controller.register_timer_handler(timer_handler, &handler_state);
    controller.register_external_handler(external_handler, &handler_state);
    
    // Mark interrupts as pending.
    controller.mark_pending(.timer);
    controller.mark_pending(.external);
    
    // Process pending interrupts.
    controller.process_pending();
    
    // Assert: Both handlers must be called.
    try std.testing.expect(handler_state.timer_called);
    try std.testing.expect(handler_state.external_called);
    
    // Assert: Pending must be cleared.
    try std.testing.expect(!controller.is_pending(.timer));
    try std.testing.expect(!controller.is_pending(.external));
}

// Test handle interrupt without handler.
test "interrupt controller no handler" {
    var controller = InterruptController.init();
    
    // Handle interrupt without registered handler (should not crash).
    controller.handle_interrupt(.timer);
    controller.handle_interrupt(.external);
    controller.handle_interrupt(.software);
    
    // Assert: Controller must still be initialized.
    try std.testing.expect(controller.initialized);
}

// Test kernel interrupt controller integration.
test "kernel interrupt controller integration" {
    const kernel = BasinKernel.init();
    
    // Assert: Kernel interrupt controller must be initialized.
    try std.testing.expect(kernel.interrupt_controller.initialized);
    try std.testing.expect(kernel.interrupt_controller.pending == 0);
    
    // Use a struct to hold mutable state (GrainStyle: no closures with mutable captures).
    const HandlerState = struct {
        called: bool = false,
        
        fn handle(state: *@This(), _: InterruptType, _: ?*anyopaque) void {
            state.called = true;
        }
    };
    
    var handler_state = HandlerState{};
    
    const handler: InterruptHandler = struct {
        fn handle_wrapper(interrupt_type: InterruptType, context: ?*anyopaque) void {
            const state = @as(*HandlerState, @ptrCast(context.?));
            HandlerState.handle(state, interrupt_type, null);
        }
    }.handle_wrapper;
    
    kernel.interrupt_controller.register_timer_handler(handler, &handler_state);
    
    // Assert: Handler must be registered.
    try std.testing.expect(kernel.interrupt_controller.timer_handler != null);
    
    // Test interrupt handling.
    kernel.interrupt_controller.handle_interrupt(.timer);
    
    // Assert: Handler must be called.
    try std.testing.expect(handler_state.called);
}

// Test multiple pending interrupts.
test "interrupt controller multiple pending" {
    var controller = InterruptController.init();
    
    var call_count: u32 = 0;
    
    const handler: InterruptHandler = struct {
        fn handle(_: InterruptType, ctx: ?*anyopaque) void {
            if (ctx) |c| {
                const count = @as(*u32, @ptrCast(@alignCast(c)));
                count.* += 1;
            }
        }
    }.handle;
    
    controller.register_timer_handler(handler, &call_count);
    
    // Mark timer interrupt as pending multiple times.
    controller.mark_pending(.timer);
    controller.mark_pending(.timer);
    
    // Process pending interrupts (should only call once per process).
    controller.process_pending();
    
    // Assert: Handler must be called once.
    try std.testing.expect(call_count == 1);
    try std.testing.expect(!controller.is_pending(.timer));
}

// Test interrupt type enum values.
test "interrupt type enum" {
    // Assert: Interrupt type enum values must match RISC-V interrupt IDs.
    try std.testing.expect(@intFromEnum(InterruptType.software) == 1);
    try std.testing.expect(@intFromEnum(InterruptType.timer) == 5);
    try std.testing.expect(@intFromEnum(InterruptType.external) == 9);
}

