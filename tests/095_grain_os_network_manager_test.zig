//! Tests for Grain OS network management system.
//!
//! Why: Verify network management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const NetworkManager = grain_os.network_manager.NetworkManager;
const InterfaceType = grain_os.network_manager.InterfaceType;
const IpAddressType = grain_os.network_manager.IpAddressType;

test "network manager initialization" {
    const manager = NetworkManager.init();
    std.debug.assert(manager.interfaces_len == 0);
    std.debug.assert(manager.next_interface_id == 1);
    std.debug.assert(manager.active_interface_id == 0);
}

test "add network interface" {
    var manager = NetworkManager.init();
    const interface_id_opt = manager.add_interface("eth0", InterfaceType.ethernet);
    std.debug.assert(interface_id_opt != null);
    if (interface_id_opt) |interface_id| {
        std.debug.assert(interface_id == 1);
        std.debug.assert(manager.get_interface_count() == 1);
        std.debug.assert(manager.active_interface_id == interface_id);
    }
}

test "find interface by ID" {
    var manager = NetworkManager.init();
    if (manager.add_interface("eth0", InterfaceType.ethernet)) |interface_id| {
        const iface_opt = manager.find_interface(interface_id);
        std.debug.assert(iface_opt != null);
        if (iface_opt) |iface| {
            std.debug.assert(iface.interface_id == interface_id);
            std.debug.assert(iface.interface_type == InterfaceType.ethernet);
        }
    }
}

test "set interface IP address" {
    var manager = NetworkManager.init();
    if (manager.add_interface("eth0", InterfaceType.ethernet)) |interface_id| {
        const result = manager.set_interface_ip(interface_id, "192.168.1.100", IpAddressType.ipv4);
        std.debug.assert(result);
        if (manager.find_interface(interface_id)) |iface| {
            std.debug.assert(iface.ip_address_type == IpAddressType.ipv4);
        }
    }
}

test "set interface netmask" {
    var manager = NetworkManager.init();
    if (manager.add_interface("eth0", InterfaceType.ethernet)) |interface_id| {
        const result = manager.set_interface_netmask(interface_id, "255.255.255.0");
        std.debug.assert(result);
    }
}

test "set interface gateway" {
    var manager = NetworkManager.init();
    if (manager.add_interface("eth0", InterfaceType.ethernet)) |interface_id| {
        const result = manager.set_interface_gateway(interface_id, "192.168.1.1");
        std.debug.assert(result);
    }
}

test "bring interface up and down" {
    var manager = NetworkManager.init();
    if (manager.add_interface("eth0", InterfaceType.ethernet)) |interface_id| {
        _ = manager.bring_interface_up(interface_id);
        if (manager.find_interface(interface_id)) |iface| {
            std.debug.assert(iface.state == .up);
        }
        _ = manager.bring_interface_down(interface_id);
        if (manager.find_interface(interface_id)) |iface| {
            std.debug.assert(iface.state == .down);
        }
    }
}

test "set active interface" {
    var manager = NetworkManager.init();
    if (manager.add_interface("eth0", InterfaceType.ethernet)) |interface_id_1| {
        if (manager.add_interface("wlan0", InterfaceType.wifi)) |interface_id_2| {
            _ = manager.bring_interface_up(interface_id_2);
            const result = manager.set_active_interface(interface_id_2);
            std.debug.assert(result);
            std.debug.assert(manager.active_interface_id == interface_id_2);
        }
    }
}

test "remove interface" {
    var manager = NetworkManager.init();
    if (manager.add_interface("eth0", InterfaceType.ethernet)) |interface_id| {
        const result = manager.remove_interface(interface_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_interface_count() == 0);
    }
}

test "compositor add network interface" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const interface_id_opt = comp.add_network_interface("eth0", InterfaceType.ethernet);
    std.debug.assert(interface_id_opt != null);
}

test "compositor set interface IP" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_network_interface("eth0", InterfaceType.ethernet)) |interface_id| {
        const result = comp.set_network_interface_ip(interface_id, "192.168.1.100", IpAddressType.ipv4);
        std.debug.assert(result);
    }
}

test "compositor bring interface up" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_network_interface("eth0", InterfaceType.ethernet)) |interface_id| {
        const result = comp.bring_network_interface_up(interface_id);
        std.debug.assert(result);
    }
}

test "compositor get interface count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_network_interface_count() == 0);
    _ = comp.add_network_interface("eth0", InterfaceType.ethernet);
    std.debug.assert(comp.get_network_interface_count() == 1);
}

test "interface types" {
    std.debug.assert(@intFromEnum(InterfaceType.unknown) == 0);
    std.debug.assert(@intFromEnum(InterfaceType.ethernet) == 1);
    std.debug.assert(@intFromEnum(InterfaceType.wifi) == 2);
    std.debug.assert(@intFromEnum(InterfaceType.bluetooth) == 3);
}

test "network manager constants" {
    std.debug.assert(grain_os.network_manager.MAX_INTERFACES == 16);
    std.debug.assert(grain_os.network_manager.MAX_INTERFACE_NAME_LEN == 64);
    std.debug.assert(grain_os.network_manager.MAX_IP_LEN == 46);
}

