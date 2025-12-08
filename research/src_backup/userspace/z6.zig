//! z6: Process Supervision Daemon for Grain Basin Kernel
//! Why: Manage long-running services, restart crashed processes, handle dependencies.
//! Inspired by: s6 process supervision suite
//! Grain Style: Single-threaded, static allocation, deterministic, comprehensive assertions.

const std = @import("std");
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const BasinError = basin_kernel.BasinError;

/// Service State
/// Why: Track service lifecycle states
pub const ServiceState = enum {
    /// Service not started
    stopped,
    /// Service starting up
    starting,
    /// Service running normally
    running,
    /// Service crashed, waiting to restart
    crashed,
    /// Service stopping
    stopping,
};

/// Restart Policy
/// Why: Define when services should be restarted
pub const RestartPolicy = enum {
    /// Always restart when service exits
    always,
    /// Never restart (one-shot services)
    never,
    /// Restart only on failure (non-zero exit code)
    on_failure,
};

/// Service Definition
/// Why: Define how to run a service
/// Grain Style: Static allocation, explicit types
pub const ServiceDef = struct {
    /// Service name (max 64 chars, null-terminated)
    name: [64]u8,
    /// Executable path (max 256 chars, null-terminated)
    executable: [256]u8,
    /// Arguments (max 16 args, each max 256 chars)
    args: [16][256]u8,
    /// Argument count
    arg_count: u32,
    /// Restart policy
    restart_policy: RestartPolicy,
    /// Restart delay (milliseconds)
    restart_delay_ms: u32,
    /// Dependencies (service names that must start first, max 8)
    dependencies: [8][64]u8,
    /// Dependency count
    dep_count: u32,
    
    /// Validate Service Definition
    /// Why: Ensure service definition is valid
    pub fn validate(self: *const ServiceDef) void {
        std.debug.assert(self.name[0] != 0); // Name must be non-empty
        std.debug.assert(self.executable[0] != 0); // Executable must be set
        std.debug.assert(self.arg_count <= 16); // Max 16 args
        std.debug.assert(self.dep_count <= 8); // Max 8 dependencies
    }
    
    /// Initialize empty service definition
    /// Why: Explicit initialization, clear state
    pub fn init() ServiceDef {
        return ServiceDef{
            .name = [_]u8{0} ** 64,
            .executable = [_]u8{0} ** 256,
            .args = [_][256]u8{[_]u8{0} ** 256} ** 16,
            .arg_count = 0,
            .restart_policy = .never,
            .restart_delay_ms = 1000,
            .dependencies = [_][64]u8{[_]u8{0} ** 64} ** 8,
            .dep_count = 0,
        };
    }
};

/// Service Instance
/// Why: Track running service instance
/// Grain Style: Static allocation, explicit types
pub const ServiceInstance = struct {
    /// Service definition
    def: ServiceDef,
    /// Current state
    state: ServiceState,
    /// Process ID (from kernel spawn syscall)
    pid: u32,
    /// Exit status (if crashed)
    exit_status: i32,
    /// Crash count (for restart limits)
    crash_count: u32,
    /// Last restart time (milliseconds since boot)
    last_restart_ms: u64,
    
    /// Initialize empty service instance
    /// Why: Explicit initialization, clear state
    pub fn init() ServiceInstance {
        return ServiceInstance{
            .def = ServiceDef.init(),
            .state = .stopped,
            .pid = 0,
            .exit_status = 0,
            .crash_count = 0,
            .last_restart_ms = 0,
        };
    }
    
    /// Check if Service Should Restart
    /// Why: Determine if crashed service should be restarted
    pub fn should_restart(self: *const ServiceInstance) bool {
        switch (self.def.restart_policy) {
            .always => return true,
            .never => return false,
            .on_failure => return self.exit_status != 0,
        }
    }
    
    /// Check if Service Can Restart
    /// Why: Enforce restart limits (max 10 crashes per minute)
    pub fn can_restart(self: *const ServiceInstance, now_ms: u64) bool {
        if (self.crash_count == 0) return true;
        
        // Check if enough time has passed since last restart
        const one_minute_ms: u64 = 60 * 1000;
        if (self.crash_count >= 10 and (now_ms - self.last_restart_ms) < one_minute_ms) {
            return false; // Too many crashes in a short period
        }
        
        return true;
    }
};

/// Maximum number of services
/// Why: Static allocation limit
const MAX_SERVICES: u32 = 64;

/// z6 Supervisor Daemon
/// Why: Main supervision daemon that manages all services
/// Grain Style: Single-threaded, static allocation, deterministic
pub const Z6Supervisor = struct {
    /// Service instances (max 64 services)
    services: [MAX_SERVICES]ServiceInstance,
    /// Service count
    service_count: u32,
    /// Kernel handle (for syscalls)
    kernel: *BasinKernel,
    /// Current time (milliseconds since boot)
    current_time_ms: u64,
    
    /// Initialize z6 Supervisor
    /// Why: Set up supervision daemon
    pub fn init(self: *Z6Supervisor, kernel: *BasinKernel) void {
        // Assert: Kernel pointer must be valid
        std.debug.assert(@intFromPtr(kernel) != 0);
        
        self.kernel = kernel;
        self.service_count = 0;
        self.current_time_ms = 0;
        
        // Initialize all service instances
        for (&self.services) |*service| {
            service.* = ServiceInstance.init();
        }
        
        // Assert: Service count must be zero initially
        std.debug.assert(self.service_count == 0);
    }
    
    /// Register Service
    /// Why: Add service to supervision
    pub fn register_service(self: *Z6Supervisor, def: ServiceDef) !void {
        // Assert: Service definition must be valid
        def.validate();
        
        // Assert: Must have room for more services
        if (self.service_count >= MAX_SERVICES) {
            return BasinError.out_of_memory; // Service table full
        }
        
        // Create service instance
        var instance = ServiceInstance.init();
        instance.def = def;
        instance.state = .stopped;
        
        self.services[self.service_count] = instance;
        self.service_count += 1;
        
        // Assert: Service count must be valid
        std.debug.assert(self.service_count <= MAX_SERVICES);
    }
    
    /// Find Service by Name
    /// Why: Look up service index by name
    pub fn find_service_by_name(self: *const Z6Supervisor, name: []const u8) ?u32 {
        for (0..self.service_count) |i| {
            const service = &self.services[i];
            const service_name = service.def.name[0..std.mem.len(service.def.name[0..])];
            if (service_name.len == 0) continue; // Skip uninitialized entries
            
            // Find null terminator
            var name_len: u32 = 0;
            for (service_name, 0..) |byte, idx| {
                if (byte == 0) {
                    name_len = @as(u32, @intCast(idx));
                    break;
                }
            }
            if (name_len == 0) continue;
            
            const actual_name = service_name[0..name_len];
            if (std.mem.eql(u8, actual_name, name)) {
                return @as(u32, @intCast(i));
            }
        }
        return null;
    }
    
    /// Start Service
    /// Why: Spawn service process via kernel
    pub fn start_service(self: *Z6Supervisor, service_idx: u32) !void {
        // Assert: Service index must be valid
        std.debug.assert(service_idx < self.service_count);
        
        var service = &self.services[service_idx];
        
        // Assert: Service must be stopped
        if (service.state != .stopped) {
            return BasinError.invalid_argument; // Service already running
        }
        
        // Check dependencies (all must be running)
        for (service.def.dependencies[0..service.def.dep_count]) |dep_name| {
            // Find null terminator
            var dep_name_len: u32 = 0;
            for (dep_name, 0..) |byte, idx| {
                if (byte == 0) {
                    dep_name_len = @as(u32, @intCast(idx));
                    break;
                }
            }
            if (dep_name_len == 0) continue;
            
            const dep_name_slice = dep_name[0..dep_name_len];
            const dep_idx = self.find_service_by_name(dep_name_slice) orelse {
                return BasinError.not_found; // Dependency not found
            };
            const dep = &self.services[dep_idx];
            if (dep.state != .running) {
                return BasinError.would_block; // Dependency not running
            }
        }
        
        // Spawn process via kernel
        service.state = .starting;
        
        // Prepare executable path
        var exec_path_len: u32 = 0;
        for (service.def.executable, 0..) |byte, idx| {
            if (byte == 0) {
                exec_path_len = @as(u32, @intCast(idx));
                break;
            }
        }
        const exec_path = service.def.executable[0..exec_path_len];
        
        // Prepare arguments
        var args: [16][]const u8 = undefined;
        var arg_count: u32 = 0;
        for (0..service.def.arg_count) |i| {
            var arg_len: u32 = 0;
            for (service.def.args[i], 0..) |byte, idx| {
                if (byte == 0) {
                    arg_len = @as(u32, @intCast(idx));
                    break;
                }
            }
            if (arg_len > 0) {
                args[arg_count] = service.def.args[i][0..arg_len];
                arg_count += 1;
            }
        }
        
        // Call spawn syscall via handle_syscall
        // Note: syscall_spawn takes executable pointer (u64) and args pointer (u64)
        // For now, we'll use handle_syscall with raw arguments
        // Future: Add public wrapper functions for convenience
        const spawn_result = self.kernel.handle_syscall(
            @intFromEnum(basin_kernel.Syscall.spawn),
            @intFromPtr(exec_path.ptr),
            @intFromPtr(args.ptr),
            arg_count,
            0,
        );
        
        switch (spawn_result) {
            .success => |pid| {
                service.pid = @as(u32, @intCast(pid));
                service.state = .running;
            },
            .err => |err| {
                service.state = .stopped;
                return err;
            },
        }
    }
    
    /// Stop Service
    /// Why: Terminate service process
    pub fn stop_service(self: *Z6Supervisor, service_idx: u32) !void {
        // Assert: Service index must be valid
        std.debug.assert(service_idx < self.service_count);
        
        var service = &self.services[service_idx];
        
        // Assert: Service must be running
        if (service.state != .running) {
            return BasinError.invalid_argument; // Service not running
        }
        
        // Send exit signal to process (future: signal syscall)
        // For now: Use kernel exit syscall
        service.state = .stopping;
        
        // Wait for process to exit
        const wait_result = self.kernel.handle_syscall(
            @intFromEnum(basin_kernel.Syscall.wait),
            service.pid,
            0,
            0,
            0,
        );
        switch (wait_result) {
            .success => |exit_status| {
                service.exit_status = @as(i32, @intCast(exit_status));
                service.state = .stopped;
            },
            .err => |err| {
                return err;
            },
        }
    }
    
    /// Check Service Health
    /// Why: Monitor running services, restart crashed ones
    pub fn check_services(self: *Z6Supervisor) !void {
        // Update current time
        // Note: clock_gettime requires a timespec pointer in VM memory
        // For now, we'll use a simplified approach - just increment time
        // Future: Properly implement clock_gettime with VM memory access
        // For now, increment time by 1 second per check
        self.current_time_ms += 1000;
        
        // Check all running services
        for (0..self.service_count) |i| {
            const service = &self.services[i];
            
            if (service.state == .running) {
                // Check if process is still alive
                const wait_result = self.kernel.handle_syscall(
                    @intFromEnum(basin_kernel.Syscall.wait),
                    service.pid,
                    0,
                    0,
                    0,
                );
                switch (wait_result) {
                    .success => |exit_status| {
                        // Process exited
                        service.exit_status = @as(i32, @intCast(exit_status));
                        service.state = .crashed;
                        service.crash_count += 1;
                        service.last_restart_ms = self.current_time_ms;
                        
                        // Restart if needed
                        if (service.should_restart() and service.can_restart(self.current_time_ms)) {
                            try self.start_service(@as(u32, @intCast(i)));
                        }
                    },
                    .err => |err| {
                        // Process still running (wait returned error)
                        if (err != .not_found) {
                            // Unexpected error
                            return err;
                        }
                    },
                }
            } else if (service.state == .crashed) {
                // Try to restart crashed service
                if (service.should_restart() and service.can_restart(self.current_time_ms)) {
                    try self.start_service(@as(u32, @intCast(i)));
                }
            }
        }
    }
    
    /// Run Supervision Loop
    /// Why: Main daemon loop that checks services periodically
    pub fn run(self: *Z6Supervisor) !void {
        // Main supervision loop
        while (true) {
            // Check service health
            try self.check_services();
            
            // Sleep for 1 second before next check
            // Note: sleep_until requires timestamp in nanoseconds
            const sleep_timestamp_ns = (self.current_time_ms + 1000) * 1000000;
            const sleep_result = self.kernel.handle_syscall(
                @intFromEnum(basin_kernel.Syscall.sleep_until),
                sleep_timestamp_ns,
                0,
                0,
                0,
            );
            switch (sleep_result) {
                .success => {},
                .err => |_| {
                    // Sleep failed, continue anyway
                },
            }
        }
    }
};

