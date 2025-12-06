//! Tests for Grain Mobile Core API handler structures.
//!
//! Why: Verify API handler function structures and registry.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_carry_core = @import("grain_carry_core");
const api = grain_carry_core.api;

test "handler context initialization" {
    const context = api.handlers.HandlerContext.init();
    
    std.debug.assert(context != null);
}

test "handler registry initialization" {
    const registry = api.handlers.HandlerRegistry.init();
    
    std.debug.assert(registry.handlers_len == 0);
}

test "handler registry register handler" {
    var registry = api.handlers.HandlerRegistry.init();
    
    const success = registry.register_handler(1, api.endpoints.AUTH_REGISTER_PATH, api.handlers.handle_register);
    
    std.debug.assert(success);
    std.debug.assert(registry.handlers_len == 1);
}

test "handler registry init with all handlers" {
    const registry = api.handlers.init_handler_registry();
    
    std.debug.assert(registry.handlers_len == 10);
}

test "handle register returns success" {
    var context = api.handlers.HandlerContext.init();
    const result = api.handlers.handle_register(&context);
    
    std.debug.assert(result == api.handlers.HandlerResult.success);
}

test "handle login returns success" {
    var context = api.handlers.HandlerContext.init();
    const result = api.handlers.handle_login(&context);
    
    std.debug.assert(result == api.handlers.HandlerResult.success);
}

test "handler result enum values" {
    std.debug.assert(@intFromEnum(api.handlers.HandlerResult.success) == 0);
    std.debug.assert(@intFromEnum(api.handlers.HandlerResult.validation_error) == 1);
    std.debug.assert(@intFromEnum(api.handlers.HandlerResult.authentication_error) == 2);
}

