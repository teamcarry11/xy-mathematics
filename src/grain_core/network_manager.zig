//! Grain OS Network Manager: Network interface and connection management.
//!
//! Why: Provide network management for interface configuration and status.
//! Architecture: Network interface management, connection status, IP configuration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max network interfaces.
pub const MAX_INTERFACES: u32 = 16;

// Bounded: Max interface name length.
pub const MAX_INTERFACE_NAME_LEN: u32 = 64;

// Bounded: Max IP address length.
pub const MAX_IP_LEN: u32 = 46; // IPv6 max length.

// Network interface type.
pub const InterfaceType = enum(u8) {
    unknown,
    ethernet,
    wifi,
    bluetooth,
    cellular,
    loopback,
    virtual,
};

// Network interface state.
pub const InterfaceState = enum(u8) {
    down,
    up,
    unknown,
};

// IP address type.
pub const IpAddressType = enum(u8) {
    none,
    ipv4,
    ipv6,
};

// Network interface: represents a network interface.
pub const NetworkInterface = struct {
    interface_id: u32,
    name: [MAX_INTERFACE_NAME_LEN]u8,
    name_len: u32,
    interface_type: InterfaceType,
    state: InterfaceState,
    ip_address: [MAX_IP_LEN]u8,
    ip_address_len: u32,
    ip_address_type: IpAddressType,
    netmask: [MAX_IP_LEN]u8,
    netmask_len: u32,
    gateway: [MAX_IP_LEN]u8,
    gateway_len: u32,
    active: bool,

    pub fn init() NetworkInterface {
        var iface = NetworkInterface{
            .interface_id = 0,
            .name = undefined,
            .name_len = 0,
            .interface_type = InterfaceType.unknown,
            .state = InterfaceState.unknown,
            .ip_address = undefined,
            .ip_address_len = 0,
            .ip_address_type = IpAddressType.none,
            .netmask = undefined,
            .netmask_len = 0,
            .gateway = undefined,
            .gateway_len = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_INTERFACE_NAME_LEN) : (i += 1) {
            iface.name[i] = 0;
        }
        i = 0;
        while (i < MAX_IP_LEN) : (i += 1) {
            iface.ip_address[i] = 0;
            iface.netmask[i] = 0;
            iface.gateway[i] = 0;
        }
        return iface;
    }
};

// Network manager: manages network interfaces.
pub const NetworkManager = struct {
    interfaces: [MAX_INTERFACES]NetworkInterface,
    interfaces_len: u32,
    next_interface_id: u32,
    active_interface_id: u32,

    pub fn init() NetworkManager {
        var manager = NetworkManager{
            .interfaces = undefined,
            .interfaces_len = 0,
            .next_interface_id = 1,
            .active_interface_id = 0,
        };
        var i: u32 = 0;
        while (i < MAX_INTERFACES) : (i += 1) {
            manager.interfaces[i] = NetworkInterface.init();
        }
        return manager;
    }

    // Add network interface.
    pub fn add_interface(
        self: *NetworkManager,
        name: []const u8,
        interface_type: InterfaceType,
    ) ?u32 {
        if (self.interfaces_len >= MAX_INTERFACES) {
            return null;
        }
        if (name.len > MAX_INTERFACE_NAME_LEN) {
            return null;
        }
        const interface_id = self.next_interface_id;
        self.next_interface_id += 1;
        self.interfaces[self.interfaces_len] = NetworkInterface.init();
        self.interfaces[self.interfaces_len].interface_id = interface_id;
        self.interfaces[self.interfaces_len].interface_type = interface_type;
        self.interfaces[self.interfaces_len].state = InterfaceState.down;
        self.interfaces[self.interfaces_len].active = true;
        var i: u32 = 0;
        while (i < MAX_INTERFACE_NAME_LEN) : (i += 1) {
            self.interfaces[self.interfaces_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_INTERFACE_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.interfaces[self.interfaces_len].name[i] = name[i];
        }
        self.interfaces[self.interfaces_len].name_len = @intCast(name_len);
        if (self.active_interface_id == 0) {
            self.active_interface_id = interface_id;
        }
        self.interfaces_len += 1;
        return interface_id;
    }

    // Find interface by ID.
    pub fn find_interface(
        self: *NetworkManager,
        interface_id: u32,
    ) ?*NetworkInterface {
        std.debug.assert(interface_id > 0);
        var i: u32 = 0;
        while (i < self.interfaces_len) : (i += 1) {
            if (self.interfaces[i].interface_id == interface_id and self.interfaces[i].active) {
                return &self.interfaces[i];
            }
        }
        return null;
    }

    // Set interface IP address.
    pub fn set_interface_ip(
        self: *NetworkManager,
        interface_id: u32,
        ip_address: []const u8,
        ip_type: IpAddressType,
    ) bool {
        std.debug.assert(interface_id > 0);
        if (ip_address.len > MAX_IP_LEN) {
            return false;
        }
        if (self.find_interface(interface_id)) |iface| {
            var i: u32 = 0;
            while (i < MAX_IP_LEN) : (i += 1) {
                iface.ip_address[i] = 0;
            }
            const ip_len = @min(ip_address.len, MAX_IP_LEN);
            i = 0;
            while (i < ip_len) : (i += 1) {
                iface.ip_address[i] = ip_address[i];
            }
            iface.ip_address_len = @intCast(ip_len);
            iface.ip_address_type = ip_type;
            return true;
        }
        return false;
    }

    // Set interface netmask.
    pub fn set_interface_netmask(
        self: *NetworkManager,
        interface_id: u32,
        netmask: []const u8,
    ) bool {
        std.debug.assert(interface_id > 0);
        if (netmask.len > MAX_IP_LEN) {
            return false;
        }
        if (self.find_interface(interface_id)) |iface| {
            var i: u32 = 0;
            while (i < MAX_IP_LEN) : (i += 1) {
                iface.netmask[i] = 0;
            }
            const netmask_len = @min(netmask.len, MAX_IP_LEN);
            i = 0;
            while (i < netmask_len) : (i += 1) {
                iface.netmask[i] = netmask[i];
            }
            iface.netmask_len = @intCast(netmask_len);
            return true;
        }
        return false;
    }

    // Set interface gateway.
    pub fn set_interface_gateway(
        self: *NetworkManager,
        interface_id: u32,
        gateway: []const u8,
    ) bool {
        std.debug.assert(interface_id > 0);
        if (gateway.len > MAX_IP_LEN) {
            return false;
        }
        if (self.find_interface(interface_id)) |iface| {
            var i: u32 = 0;
            while (i < MAX_IP_LEN) : (i += 1) {
                iface.gateway[i] = 0;
            }
            const gateway_len = @min(gateway.len, MAX_IP_LEN);
            i = 0;
            while (i < gateway_len) : (i += 1) {
                iface.gateway[i] = gateway[i];
            }
            iface.gateway_len = @intCast(gateway_len);
            return true;
        }
        return false;
    }

    // Bring interface up.
    pub fn bring_interface_up(self: *NetworkManager, interface_id: u32) bool {
        std.debug.assert(interface_id > 0);
        if (self.find_interface(interface_id)) |iface| {
            iface.state = InterfaceState.up;
            return true;
        }
        return false;
    }

    // Bring interface down.
    pub fn bring_interface_down(self: *NetworkManager, interface_id: u32) bool {
        std.debug.assert(interface_id > 0);
        if (self.find_interface(interface_id)) |iface| {
            iface.state = InterfaceState.down;
            return true;
        }
        return false;
    }

    // Set active interface.
    pub fn set_active_interface(self: *NetworkManager, interface_id: u32) bool {
        std.debug.assert(interface_id > 0);
        if (self.find_interface(interface_id)) |iface| {
            if (iface.state == InterfaceState.up) {
                self.active_interface_id = interface_id;
                return true;
            }
        }
        return false;
    }

    // Get active interface.
    pub fn get_active_interface(self: *const NetworkManager) ?*const NetworkInterface {
        if (self.active_interface_id == 0) {
            return null;
        }
        var i: u32 = 0;
        while (i < self.interfaces_len) : (i += 1) {
            if (self.interfaces[i].interface_id == self.active_interface_id) {
                return &self.interfaces[i];
            }
        }
        return null;
    }

    // Remove interface.
    pub fn remove_interface(self: *NetworkManager, interface_id: u32) bool {
        std.debug.assert(interface_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.interfaces_len) : (i += 1) {
            if (self.interfaces[i].interface_id == interface_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        if (self.active_interface_id == interface_id) {
            self.active_interface_id = 0;
        }
        // Shift remaining interfaces left.
        while (i < self.interfaces_len - 1) : (i += 1) {
            self.interfaces[i] = self.interfaces[i + 1];
        }
        self.interfaces_len -= 1;
        return true;
    }

    // Get interface count.
    pub fn get_interface_count(self: *const NetworkManager) u32 {
        return self.interfaces_len;
    }
};

