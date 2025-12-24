//! Network Interface Management
//! Why: Manage network interfaces for TCP/UDP syscalls.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const NetworkInterfaceStats = @import("network_interface_stats.zig").NetworkInterfaceStats;

/// Maximum number of network interfaces.
/// Why: Bounded allocation for interface tracking.
const MAX_NETWORK_INTERFACES: u32 = 8;

/// Maximum interface name length.
/// Why: Bounded string storage for interface names.
const MAX_INTERFACE_NAME_LEN: u32 = 16;

/// Network interface state.
/// Why: Track interface state (up/down).
pub const InterfaceState = enum(u8) {
    down = 0,
    up = 1,
};

/// Network interface entry.
/// Why: Track network interface configuration and state.
/// Grain Style: Static allocation, explicit types.
pub const NetworkInterface = struct {
    /// Interface name (null-terminated).
    name: [MAX_INTERFACE_NAME_LEN]u8,
    
    /// Interface state (up/down).
    state: InterfaceState,
    
    /// IPv4 address (network byte order).
    ipv4_addr: u32,
    
    /// IPv4 netmask (network byte order).
    ipv4_netmask: u32,
    
    /// IPv4 gateway (network byte order).
    ipv4_gateway: u32,
    
    /// IPv6 address (128 bits, network byte order).
    ipv6_addr: [16]u8,
    
    /// Whether this entry is allocated (in use).
    allocated: bool,
    
    /// Initialize empty network interface entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() NetworkInterface {
        return NetworkInterface{
            .name = [_]u8{0} ** MAX_INTERFACE_NAME_LEN,
            .state = .down,
            .ipv4_addr = 0,
            .ipv4_netmask = 0,
            .ipv4_gateway = 0,
            .ipv6_addr = [_]u8{0} ** 16,
            .allocated = false,
        };
    }
    
    /// Set interface name.
    /// Why: Configure interface name.
    /// Contract: name must be valid, non-empty, null-terminated.
    pub fn set_name(self: *NetworkInterface, name: []const u8) bool {
        // Assert: Entry must be allocated.
        Debug.kassert(self.allocated, "Entry not allocated", .{});
        
        // Assert: Name must be non-empty.
        if (name.len == 0) {
            return false;
        }
        
        // Assert: Name must fit in buffer (including null terminator).
        if (name.len >= MAX_INTERFACE_NAME_LEN) {
            return false;
        }
        
        // Copy name to buffer.
        std.mem.set(u8, &self.name, 0);
        std.mem.copyForwards(u8, self.name[0..name.len], name);
        self.name[name.len] = 0; // Null terminator
        
        return true;
    }
    
    /// Get interface name.
    /// Why: Retrieve interface name.
    /// Contract: Returns null-terminated string.
    pub fn get_name(self: *const NetworkInterface) []const u8 {
        // Assert: Entry must be allocated.
        Debug.kassert(self.allocated, "Entry not allocated", .{});
        
        // Find null terminator.
        var len: u32 = 0;
        while (len < MAX_INTERFACE_NAME_LEN) : (len += 1) {
            if (self.name[len] == 0) {
                break;
            }
        }
        
        return self.name[0..len];
    }
};

/// Network interface manager.
/// Why: Manage all network interfaces.
/// Grain Style: Static allocation, bounded operations.
pub const NetworkInterfaceManager = struct {
    /// Interface entries.
    interfaces: [MAX_NETWORK_INTERFACES]NetworkInterface,
    
    /// Whether manager is initialized.
    initialized: bool,
    
    /// Network interface statistics tracker.
    /// Why: Track interface operations and state changes.
    stats: NetworkInterfaceStats,
    
    /// Initialize network interface manager.
    /// Why: Set up manager state.
    pub fn init() NetworkInterfaceManager {
        const manager = NetworkInterfaceManager{
            .interfaces = [_]NetworkInterface{NetworkInterface.init()} ** MAX_NETWORK_INTERFACES,
            .initialized = true,
            .stats = NetworkInterfaceStats.init(),
        };
        
        return manager;
    }
    
    /// Create a new network interface.
    /// Why: Add a new network interface.
    /// Contract: name must be valid, non-empty, null-terminated.
    /// Returns: Interface index, or null if no free slot.
    pub fn create_interface(
        self: *NetworkInterfaceManager,
        name: []const u8,
    ) ?u32 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Name must be non-empty.
        if (name.len == 0) {
            self.stats.record_creation_error();
            return null;
        }
        
        // Assert: Name must fit in buffer.
        if (name.len >= MAX_INTERFACE_NAME_LEN) {
            self.stats.record_creation_error();
            return null;
        }
        
        // Find free slot.
        var idx: u32 = 0;
        while (idx < MAX_NETWORK_INTERFACES) : (idx += 1) {
            if (!self.interfaces[idx].allocated) {
                // Initialize interface.
                self.interfaces[idx] = NetworkInterface.init();
                self.interfaces[idx].allocated = true;
                
                // Set name.
                if (!self.interfaces[idx].set_name(name)) {
                    self.interfaces[idx].allocated = false;
                    self.stats.record_creation_error();
                    return null;
                }
                
                // Record statistics.
                self.stats.record_interface_created();
                
                return idx;
            }
        }
        
        // No free slot found.
        self.stats.record_creation_error();
        return null;
    }
    
    /// Get interface by index.
    /// Why: Retrieve interface entry.
    /// Contract: idx must be valid (within bounds).
    /// Returns: Pointer to interface entry, or null if not found.
    pub fn get_interface(
        self: *NetworkInterfaceManager,
        idx: u32,
    ) ?*NetworkInterface {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Index must be within bounds.
        if (idx >= MAX_NETWORK_INTERFACES) {
            return null;
        }
        
        // Check if interface is allocated.
        if (!self.interfaces[idx].allocated) {
            return null;
        }
        
        return &self.interfaces[idx];
    }
    
    /// Find interface by name.
    /// Why: Look up interface by name.
    /// Contract: name must be valid, non-empty.
    /// Returns: Interface index, or null if not found.
    pub fn find_interface_by_name(
        self: *const NetworkInterfaceManager,
        name: []const u8,
    ) ?u32 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Name must be non-empty.
        if (name.len == 0) {
            return null;
        }
        
        // Search for interface with matching name.
        var idx: u32 = 0;
        while (idx < MAX_NETWORK_INTERFACES) : (idx += 1) {
            if (self.interfaces[idx].allocated) {
                const iface_name = self.interfaces[idx].get_name();
                if (std.mem.eql(u8, iface_name, name)) {
                    return idx;
                }
            }
        }
        
        // Interface not found.
        return null;
    }
    
    /// Set interface state (up/down).
    /// Why: Control interface state.
    /// Contract: idx must be valid, state must be valid.
    pub fn set_interface_state(
        self: *NetworkInterfaceManager,
        idx: u32,
        state: InterfaceState,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const iface = self.get_interface(idx) orelse {
            self.stats.record_configuration_error();
            return false;
        };
        
        // Record state transition.
        const old_state = iface.state;
        iface.state = state;
        if (old_state != state) {
            if (state == .up) {
                self.stats.record_up_transition();
            } else if (state == .down) {
                self.stats.record_down_transition();
            }
        }
        
        return true;
    }
    
    /// Set IPv4 address.
    /// Why: Configure IPv4 address.
    /// Contract: idx must be valid, addr must be in network byte order.
    pub fn set_ipv4_address(
        self: *NetworkInterfaceManager,
        idx: u32,
        addr: u32,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const iface = self.get_interface(idx) orelse {
            self.stats.record_configuration_error();
            return false;
        };
        
        iface.ipv4_addr = addr;
        
        // Record statistics.
        self.stats.record_ipv4_configuration();
        
        return true;
    }
    
    /// Set IPv4 netmask.
    /// Why: Configure IPv4 netmask.
    /// Contract: idx must be valid, netmask must be in network byte order.
    pub fn set_ipv4_netmask(
        self: *NetworkInterfaceManager,
        idx: u32,
        netmask: u32,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const iface = self.get_interface(idx) orelse {
            return false;
        };
        
        iface.ipv4_netmask = netmask;
        return true;
    }
    
    /// Set IPv4 gateway.
    /// Why: Configure IPv4 gateway.
    /// Contract: idx must be valid, gateway must be in network byte order.
    pub fn set_ipv4_gateway(
        self: *NetworkInterfaceManager,
        idx: u32,
        gateway: u32,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const iface = self.get_interface(idx) orelse {
            return false;
        };
        
        iface.ipv4_gateway = gateway;
        return true;
    }
    
    /// Set IPv6 address.
    /// Why: Configure IPv6 address.
    /// Contract: idx must be valid, addr must be 16 bytes (128 bits).
    pub fn set_ipv6_address(
        self: *NetworkInterfaceManager,
        idx: u32,
        addr: [16]u8,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const iface = self.get_interface(idx) orelse {
            self.stats.record_configuration_error();
            return false;
        };
        
        // Copy IPv6 address (16 bytes).
        @memcpy(&iface.ipv6_addr, &addr);
        
        // Record statistics.
        self.stats.record_ipv6_configuration();
        
        return true;
    }
    
    /// Enumerate all network interfaces.
    /// Why: Get list of all allocated interfaces.
    /// Contract: indices array must be large enough (MAX_NETWORK_INTERFACES).
    /// Returns: Number of interfaces found.
    pub fn enumerate_interfaces(
        self: *NetworkInterfaceManager,
        indices: []u32,
    ) u32 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Indices array must be large enough.
        Debug.kassert(indices.len >= MAX_NETWORK_INTERFACES, "Indices array too small", .{});
        
        var count: u32 = 0;
        var idx: u32 = 0;
        while (idx < MAX_NETWORK_INTERFACES) : (idx += 1) {
            if (self.interfaces[idx].allocated) {
                indices[count] = idx;
                count += 1;
            }
        }
        
        return count;
    }
    
    /// Delete interface.
    /// Why: Remove network interface.
    /// Contract: idx must be valid.
    pub fn delete_interface(
        self: *NetworkInterfaceManager,
        idx: u32,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Index must be within bounds.
        if (idx >= MAX_NETWORK_INTERFACES) {
            self.stats.record_deletion_error();
            return false;
        }
        
        // Check if interface is allocated.
        if (!self.interfaces[idx].allocated) {
            self.stats.record_deletion_error();
            return false;
        }
        
        // Deallocate interface.
        self.interfaces[idx] = NetworkInterface.init();
        
        // Record statistics.
        self.stats.record_interface_deleted();
        
        return true;
    }
    
    /// Get network interface statistics snapshot.
    /// Why: Provide statistics for userspace queries.
    /// Returns: Reference to statistics tracker.
    pub fn get_stats(self: *const NetworkInterfaceManager) *const NetworkInterfaceStats {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        return &self.stats;
    }
};

