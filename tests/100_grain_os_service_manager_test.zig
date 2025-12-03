//! Tests for Grain OS service management system.
//!
//! Why: Verify service management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const ServiceManager = grain_os.service_manager.ServiceManager;
const ServiceState = grain_os.service_manager.ServiceState;
const ServiceType = grain_os.service_manager.ServiceType;

test "service manager initialization" {
    const manager = ServiceManager.init();
    std.debug.assert(manager.services_len == 0);
    std.debug.assert(manager.next_service_id == 1);
}

test "add service" {
    var manager = ServiceManager.init();
    const service_id_opt = manager.add_service(
        "test_service",
        "Test service description",
        ServiceType.system,
    );
    std.debug.assert(service_id_opt != null);
    if (service_id_opt) |service_id| {
        std.debug.assert(service_id == 1);
        std.debug.assert(manager.get_service_count() == 1);
    }
}

test "start service" {
    var manager = ServiceManager.init();
    if (manager.add_service("test_service", "Test service", ServiceType.system)) |service_id| {
        const result = manager.start_service(service_id);
        std.debug.assert(result);
        if (manager.find_service(service_id)) |service| {
            std.debug.assert(service.state == ServiceState.running);
        }
    }
}

test "stop service" {
    var manager = ServiceManager.init();
    if (manager.add_service("test_service", "Test service", ServiceType.system)) |service_id| {
        _ = manager.start_service(service_id);
        const result = manager.stop_service(service_id);
        std.debug.assert(result);
        if (manager.find_service(service_id)) |service| {
            std.debug.assert(service.state == ServiceState.stopped);
        }
    }
}

test "restart service" {
    var manager = ServiceManager.init();
    if (manager.add_service("test_service", "Test service", ServiceType.system)) |service_id| {
        _ = manager.start_service(service_id);
        const result = manager.restart_service(service_id);
        std.debug.assert(result);
        if (manager.find_service(service_id)) |service| {
            std.debug.assert(service.state == ServiceState.running);
        }
    }
}

test "enable auto-start" {
    var manager = ServiceManager.init();
    if (manager.add_service("test_service", "Test service", ServiceType.system)) |service_id| {
        const result = manager.enable_auto_start(service_id);
        std.debug.assert(result);
        if (manager.find_service(service_id)) |service| {
            std.debug.assert(service.auto_start);
        }
    }
}

test "enable restart on failure" {
    var manager = ServiceManager.init();
    if (manager.add_service("test_service", "Test service", ServiceType.system)) |service_id| {
        const result = manager.enable_restart_on_failure(service_id);
        std.debug.assert(result);
        if (manager.find_service(service_id)) |service| {
            std.debug.assert(service.restart_on_failure);
        }
    }
}

test "add dependency" {
    var manager = ServiceManager.init();
    if (manager.add_service("service1", "Service 1", ServiceType.system)) |service_id_1| {
        if (manager.add_service("service2", "Service 2", ServiceType.system)) |service_id_2| {
            const result = manager.add_dependency(service_id_2, service_id_1);
            std.debug.assert(result);
        }
    }
}

test "remove dependency" {
    var manager = ServiceManager.init();
    if (manager.add_service("service1", "Service 1", ServiceType.system)) |service_id_1| {
        if (manager.add_service("service2", "Service 2", ServiceType.system)) |service_id_2| {
            _ = manager.add_dependency(service_id_2, service_id_1);
            const result = manager.remove_dependency(service_id_2, service_id_1);
            std.debug.assert(result);
        }
    }
}

test "remove service" {
    var manager = ServiceManager.init();
    if (manager.add_service("test_service", "Test service", ServiceType.system)) |service_id| {
        const result = manager.remove_service(service_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_service_count() == 0);
    }
}

test "get running service count" {
    var manager = ServiceManager.init();
    if (manager.add_service("service1", "Service 1", ServiceType.system)) |service_id_1| {
        if (manager.add_service("service2", "Service 2", ServiceType.system)) |service_id_2| {
            _ = manager.start_service(service_id_1);
            _ = manager.start_service(service_id_2);
            const count = manager.get_running_service_count();
            std.debug.assert(count == 2);
        }
    }
}

test "compositor add service" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const service_id_opt = comp.add_service(
        "test_service",
        "Test service description",
        ServiceType.system,
    );
    std.debug.assert(service_id_opt != null);
}

test "compositor start service" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_service("test_service", "Test service", ServiceType.system)) |service_id| {
        const result = comp.start_service(service_id);
        std.debug.assert(result);
    }
}

test "compositor stop service" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_service("test_service", "Test service", ServiceType.system)) |service_id| {
        _ = comp.start_service(service_id);
        const result = comp.stop_service(service_id);
        std.debug.assert(result);
    }
}

test "compositor restart service" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_service("test_service", "Test service", ServiceType.system)) |service_id| {
        _ = comp.start_service(service_id);
        const result = comp.restart_service(service_id);
        std.debug.assert(result);
    }
}

test "compositor enable auto-start" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_service("test_service", "Test service", ServiceType.system)) |service_id| {
        const result = comp.enable_service_auto_start(service_id);
        std.debug.assert(result);
    }
}

test "compositor add dependency" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_service("service1", "Service 1", ServiceType.system)) |service_id_1| {
        if (comp.add_service("service2", "Service 2", ServiceType.system)) |service_id_2| {
            const result = comp.add_service_dependency(service_id_2, service_id_1);
            std.debug.assert(result);
        }
    }
}

test "service states" {
    std.debug.assert(@intFromEnum(ServiceState.stopped) == 0);
    std.debug.assert(@intFromEnum(ServiceState.starting) == 1);
    std.debug.assert(@intFromEnum(ServiceState.running) == 2);
    std.debug.assert(@intFromEnum(ServiceState.stopping) == 3);
    std.debug.assert(@intFromEnum(ServiceState.failed) == 4);
    std.debug.assert(@intFromEnum(ServiceState.disabled) == 5);
}

test "service types" {
    std.debug.assert(@intFromEnum(ServiceType.system) == 0);
    std.debug.assert(@intFromEnum(ServiceType.user) == 1);
    std.debug.assert(@intFromEnum(ServiceType.network) == 2);
    std.debug.assert(@intFromEnum(ServiceType.filesystem) == 3);
    std.debug.assert(@intFromEnum(ServiceType.device) == 4);
    std.debug.assert(@intFromEnum(ServiceType.other) == 5);
}

test "service manager constants" {
    std.debug.assert(grain_os.service_manager.MAX_SERVICES == 64);
    std.debug.assert(grain_os.service_manager.MAX_SERVICE_NAME_LEN == 128);
    std.debug.assert(grain_os.service_manager.MAX_SERVICE_DESC_LEN == 256);
    std.debug.assert(grain_os.service_manager.MAX_DEPENDENCIES == 16);
}

