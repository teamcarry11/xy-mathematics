//! Shared modules configuration.
//!
//! Why: Centralize shared module definitions used across multiple agents.
//! Architecture: Module definitions for vendor libraries and shared code.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-04-104301-pst: Grain OS Agent

const std = @import("std");
const Build = std.Build;
const helpers = @import("helpers.zig");
const kernel = @import("kernel.zig");

// Shared modules structure.
pub const SharedModules = struct {
    ray: *Build.Module,
    grainwrap: *Build.Module,
    grainvalidate: *Build.Module,
    zigimg: *Build.Module,
    grain_tls_impl: *Build.Module,
    tls: *Build.Module,
    grain_silo: *Build.Module,
    grain_field: *Build.Module,
    shared: *Build.Module,
    events: *Build.Module,
    grain_buffer_terminal: *Build.Module,
    macos_window_terminal: *Build.Module,
    grainscript: *Build.Module,
    grain_terminal: *Build.Module,
};

// Agent-specific modules structure.
pub const AgentModules = struct {
    grain_os: *Build.Module,
    grain_skate: *Build.Module,
    grain_workspace: *Build.Module,
    grain_mobile_core: *Build.Module,
    grain_database: *Build.Module,
    aurora_layout: *Build.Module,
};

// Create all shared modules.
pub fn create_shared_modules(ctx: helpers.BuildContext) SharedModules {
    const ray_mod = helpers.add_simple_module(ctx, "ray", "src/ray.zig");
    const grainwrap_mod = helpers.add_simple_module(
        ctx,
        "grainwrap",
        "vendor/grainwrap/src/grainwrap.zig",
    );
    const grainvalidate_mod = helpers.add_simple_module(
        ctx,
        "grainvalidate",
        "vendor/grainvalidate/src/grainvalidate.zig",
    );
    const zigimg_mod = helpers.add_simple_module(
        ctx,
        "zigimg",
        "grainstore/github/zigimg/zigimg/zigimg.zig",
    );
    const grain_tls_impl_mod = helpers.add_simple_module(
        ctx,
        "grain_tls_impl",
        "grainstore/github/kae3g/grain-tls/src/root.zig",
    );
    const tls_mod = helpers.add_module(
        ctx,
        "tls",
        "src/grain_tls/root.zig",
        &.{.{ .name = "grain_tls_impl", .module = grain_tls_impl_mod }},
    );
    const grain_silo_mod = helpers.add_simple_module(
        ctx,
        "grain_silo",
        "src/grain_silo/root.zig",
    );
    const grain_field_mod = helpers.add_simple_module(
        ctx,
        "grain_field",
        "src/grain_field/root.zig",
    );
    const shared_mod = helpers.add_simple_module(
        ctx,
        "shared",
        "src/shared/font_renderer.zig",
    );
    const events_mod = helpers.add_simple_module(
        ctx,
        "events",
        "src/platform/events.zig",
    );
    const grain_buffer_mod = helpers.add_simple_module(
        ctx,
        "grain_buffer_terminal",
        "src/grain_buffer.zig",
    );
    const macos_window_mod = helpers.add_module(
        ctx,
        "macos_window_terminal",
        "src/platform/macos_tahoe/window.zig",
        &.{.{ .name = "events", .module = events_mod }},
    );
    const grainscript_mod = helpers.add_simple_module(
        ctx,
        "grainscript",
        "src/grainscript/root.zig",
    );
    const grain_terminal_mod = helpers.add_module(
        ctx,
        "grain_terminal",
        "src/grain_terminal/root.zig",
        &.{
            .{ .name = "grain_buffer", .module = grain_buffer_mod },
            .{ .name = "macos_window", .module = macos_window_mod },
            .{ .name = "grainscript", .module = grainscript_mod },
        },
    );
    
    return SharedModules{
        .ray = ray_mod,
        .grainwrap = grainwrap_mod,
        .grainvalidate = grainvalidate_mod,
        .zigimg = zigimg_mod,
        .grain_tls_impl = grain_tls_impl_mod,
        .tls = tls_mod,
        .grain_silo = grain_silo_mod,
        .grain_field = grain_field_mod,
        .shared = shared_mod,
        .events = events_mod,
        .grain_buffer_terminal = grain_buffer_mod,
        .macos_window_terminal = macos_window_mod,
        .grainscript = grainscript_mod,
        .grain_terminal = grain_terminal_mod,
    };
}

// Create agent-specific modules.
pub fn create_agent_modules(
    ctx: helpers.BuildContext,
    shared_modules: SharedModules,
    kernel_modules: kernel.KernelModules,
) AgentModules {
    const grain_os_mod = helpers.add_module(
        ctx,
        "grain_os",
        "src/grain_os/root.zig",
        &.{.{ .name = "basin_kernel", .module = kernel_modules.basin_kernel }},
    );
    const grain_skate_mod = helpers.add_module(
        ctx,
        "grain_skate",
        "src/grain_skate/root.zig",
        &.{
            .{ .name = "macos_window", .module = shared_modules.macos_window_terminal },
            .{ .name = "events", .module = shared_modules.events },
        },
    );
    const grain_workspace_mod = helpers.add_module(
        ctx,
        "grain_workspace",
        "src/grain_workspace/root.zig",
        &.{
            .{ .name = "grain_silo", .module = shared_modules.grain_silo },
            .{ .name = "grain_skate", .module = grain_skate_mod },
            .{ .name = "grain_os", .module = grain_os_mod },
        },
    );
    const grain_mobile_core_mod = helpers.add_simple_module(
        ctx,
        "grain_mobile_core",
        "src/grain_mobile_core/root.zig",
    );
    const grain_database_mod = helpers.add_module(
        ctx,
        "grain_database",
        "src/grain_database/root.zig",
        &.{.{ .name = "grain_silo", .module = shared_modules.grain_silo }},
    );
    const aurora_layout_mod = helpers.add_simple_module(
        ctx,
        "aurora_layout",
        "src/aurora_layout/root.zig",
    );
    
    return AgentModules{
        .grain_os = grain_os_mod,
        .grain_skate = grain_skate_mod,
        .grain_workspace = grain_workspace_mod,
        .grain_mobile_core = grain_mobile_core_mod,
        .grain_database = grain_database_mod,
        .aurora_layout = aurora_layout_mod,
    };
}

