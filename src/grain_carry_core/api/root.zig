// Grain Mobile Core API module root
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Re-exports all API client components

pub const client = @import("client.zig");
pub const endpoints = @import("endpoints.zig");
pub const models = @import("models.zig");
pub const responses = @import("responses.zig");
pub const validation = @import("validation.zig");
pub const handlers = @import("handlers.zig");
pub const middleware = @import("middleware.zig");
pub const integration = @import("integration.zig");
pub const middleware_integration = @import("middleware_integration.zig");
pub const route_registration = @import("route_registration.zig");
pub const os_integration = @import("os_integration.zig");
pub const handler_adapters = @import("handler_adapters.zig");
pub const auth_integration = @import("auth_integration.zig");
pub const auth_service_integration = @import("auth_service_integration.zig");

