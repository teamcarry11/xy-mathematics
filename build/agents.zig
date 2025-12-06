//! Agent modules build configuration.
//!
//! Why: Centralize agent module definitions (Grain OS, Skate, Workspace, Mobile, Database).
//! Architecture: Agent module definitions with dependencies.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-04-104301-pst: Grain OS Agent

const std = @import("std");
const Build = std.Build;
const helpers = @import("helpers.zig");
const modules = @import("modules.zig");
const kernel = @import("kernel.zig");

// Agent modules structure.
pub const AgentModules = struct {
    grain_skate: *Build.Module,
    grain_core: *Build.Module,
    grain_mobile_core: *Build.Module,
    grain_workspace: *Build.Module,
    grain_database: *Build.Module,
};

// Create all agent modules.
pub fn create_agent_modules(
    ctx: helpers.BuildContext,
    shared_modules: modules.SharedModules,
    kernel_modules: kernel.KernelModules,
) AgentModules {
    const grain_skate_mod = helpers.add_module(
        ctx,
        "grain_skate",
        "src/grain_skate/root.zig",
        &.{
            .{ .name = "macos_window", .module = shared_modules.macos_window_terminal },
            .{ .name = "events", .module = shared_modules.events },
        },
    );
    const grain_core_mod = helpers.add_module(
        ctx,
        "grain_core",
        "src/grain_core/root.zig",
        &.{
            .{ .name = "basin_kernel", .module = kernel_modules.basin_kernel },
        },
    );
    const grain_mobile_core_mod = helpers.add_simple_module(
        ctx,
        "grain_mobile_core",
        "src/grain_mobile_core/root.zig",
    );
    const grain_workspace_mod = helpers.add_module(
        ctx,
        "grain_workspace",
        "src/grain_workspace/root.zig",
        &.{
            .{ .name = "grain_silo", .module = shared_modules.grain_silo },
            .{ .name = "grain_skate", .module = grain_skate_mod },
            .{ .name = "grain_core", .module = grain_core_mod },
        },
    );
    const grain_database_mod = helpers.add_module(
        ctx,
        "grain_database",
        "src/grain_database/root.zig",
        &.{
            .{ .name = "grain_silo", .module = shared_modules.grain_silo },
        },
    );
    
    return AgentModules{
        .grain_skate = grain_skate_mod,
        .grain_core = grain_core_mod,
        .grain_mobile_core = grain_mobile_core_mod,
        .grain_workspace = grain_workspace_mod,
        .grain_database = grain_database_mod,
    };
}

