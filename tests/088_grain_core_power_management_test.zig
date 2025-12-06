//! Tests for Grain OS power management system.
//!
//! Why: Verify power management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_core = @import("grain_core");
const Compositor = grain_core.compositor.Compositor;
const PowerManagementManager = grain_core.power_management.PowerManagementManager;
const PowerState = grain_core.power_management.PowerState;
const BatteryState = grain_core.power_management.BatteryState;

test "power management manager initialization" {
    const manager = PowerManagementManager.init();
    std.debug.assert(manager.get_power_state() == PowerState.on);
    std.debug.assert(manager.get_battery_level() == 100);
    std.debug.assert(manager.get_battery_state() == BatteryState.unknown);
    std.debug.assert(!manager.is_auto_suspend_enabled());
}

test "suspend system" {
    var manager = PowerManagementManager.init();
    const result = manager.suspend_system();
    std.debug.assert(result);
    std.debug.assert(manager.get_power_state() == PowerState.suspended);
}

test "hibernate system" {
    var manager = PowerManagementManager.init();
    const result = manager.hibernate_system();
    std.debug.assert(result);
    std.debug.assert(manager.get_power_state() == PowerState.hibernated);
}

test "shutdown system" {
    var manager = PowerManagementManager.init();
    const result = manager.shutdown_system();
    std.debug.assert(result);
    std.debug.assert(manager.get_power_state() == PowerState.shutdown);
}

test "set battery level" {
    var manager = PowerManagementManager.init();
    manager.set_battery_level(75);
    std.debug.assert(manager.get_battery_level() == 75);
}

test "set battery state" {
    var manager = PowerManagementManager.init();
    manager.set_battery_state(BatteryState.charging);
    std.debug.assert(manager.get_battery_state() == BatteryState.charging);
}

test "enable auto-suspend" {
    var manager = PowerManagementManager.init();
    manager.enable_auto_suspend(300000); // 5 minutes.
    std.debug.assert(manager.is_auto_suspend_enabled());
    std.debug.assert(manager.get_auto_suspend_timeout() == 300000);
}

test "disable auto-suspend" {
    var manager = PowerManagementManager.init();
    manager.enable_auto_suspend(300000);
    manager.disable_auto_suspend();
    std.debug.assert(!manager.is_auto_suspend_enabled());
    std.debug.assert(manager.get_auto_suspend_timeout() == 0);
}

test "compositor suspend system" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const result = comp.suspend_system();
    std.debug.assert(result);
    std.debug.assert(comp.get_power_state() == PowerState.suspended);
}

test "compositor shutdown system" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const result = comp.shutdown_system();
    std.debug.assert(result);
    std.debug.assert(comp.get_power_state() == PowerState.shutdown);
}

test "compositor battery management" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_battery_level(50);
    std.debug.assert(comp.get_battery_level() == 50);
    comp.set_battery_state(BatteryState.discharging);
    std.debug.assert(comp.get_battery_state() == BatteryState.discharging);
}

test "compositor auto-suspend" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.enable_auto_suspend(600000); // 10 minutes.
    std.debug.assert(comp.is_auto_suspend_enabled());
    std.debug.assert(comp.get_auto_suspend_timeout() == 600000);
    comp.disable_auto_suspend();
    std.debug.assert(!comp.is_auto_suspend_enabled());
}

test "power states" {
    var manager = PowerManagementManager.init();
    std.debug.assert(manager.get_power_state() == PowerState.on);
    _ = manager.suspend_system();
    std.debug.assert(manager.get_power_state() == PowerState.suspended);
    manager.set_power_state(PowerState.on);
    _ = manager.hibernate_system();
    std.debug.assert(manager.get_power_state() == PowerState.hibernated);
}

test "battery states" {
    var manager = PowerManagementManager.init();
    manager.set_battery_state(BatteryState.charging);
    std.debug.assert(manager.get_battery_state() == BatteryState.charging);
    manager.set_battery_state(BatteryState.discharging);
    std.debug.assert(manager.get_battery_state() == BatteryState.discharging);
    manager.set_battery_state(BatteryState.full);
    std.debug.assert(manager.get_battery_state() == BatteryState.full);
}

