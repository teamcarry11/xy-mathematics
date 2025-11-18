# VM Shutdown, User Management & Nix-Like Build System

**Date**: 12025-11-16  
**Status**: Architecture Design Document  
**Vision**: Grain Basin kernel with referentially transparent immutable database (graindb) foundation, Nix-like reproducible builds, and TigerStyle-evolved user management.

## 1. VM Shutdown & Reboot

### Current Implementation
- **SBI LEGACY_SHUTDOWN (0x8)**: Already implemented in `src/kernel_vm/vm.zig`
- **VM State**: Sets VM state to `.halted` on shutdown
- **Kernel Syscall**: `exit` syscall (syscall number 2) also halts VM

### Architecture: Shutdown/Reboot Mechanism

```zig
/// VM Shutdown Types
pub const ShutdownType = enum(u32) {
    /// Halt VM (stop execution, no reboot)
    HALT = 0,
    /// Reboot VM (reset state, restart from entry point)
    REBOOT = 1,
    /// Power off VM (clean shutdown, release resources)
    POWER_OFF = 2,
};

/// Kernel Shutdown Syscall
/// Why: Allow userspace programs to request shutdown/reboot
/// Contract: Only root user can request reboot/power_off
pub fn syscall_shutdown(
    self: *BasinKernel,
    shutdown_type: ShutdownType,
) SyscallResult {
    // Assert: Only root user (uid=0) can request reboot/power_off
    if (shutdown_type != .HALT and self.current_user.uid != 0) {
        return .{ .error = .permission_denied };
    }
    
    // Route to SBI shutdown
    // In VM: Set VM state to .halted
    // On hardware: Call SBI LEGACY_SHUTDOWN
    return .{ .value = 0 };
}
```

### Implementation Plan
1. **Add shutdown syscall** to `basin_kernel.zig` (syscall number 18)
2. **VM Integration**: Route shutdown to VM halt/reboot logic
3. **Reboot Logic**: Reset VM state, reload kernel, restart from entry point
4. **Hardware Integration**: Future - route to SBI shutdown on Framework 13

## 2. User Management: Root & `xy` User

### Architecture: Single-Threaded User System

```zig
/// User ID (32-bit, explicit type per TigerStyle)
pub const UserId = u32;

/// Group ID (32-bit, explicit type per TigerStyle)
pub const GroupId = u32;

/// User Record
/// Why: Track user identity, permissions, home directory
/// Tiger Style: Explicit types (u32 not usize), static allocation
pub const User = struct {
    /// User ID (0 = root)
    uid: UserId,
    /// Group ID (primary group)
    gid: GroupId,
    /// Username (max 32 chars, static allocation)
    name: [32]u8,
    /// Home directory path (max 256 chars)
    home: [256]u8,
    /// Capabilities bitmap (future: fine-grained permissions)
    capabilities: u64,
    
    /// Assert: uid must be valid (< 65536)
    pub fn validate(self: *const User) void {
        std.debug.assert(self.uid < 65536);
        std.debug.assert(self.gid < 65536);
        std.debug.assert(self.name[0] != 0); // Name must be non-empty
    }
};

/// Current User Context
/// Why: Track current user for permission checks
/// Single-threaded: No locks needed, deterministic
pub const UserContext = struct {
    /// Current user ID
    uid: UserId,
    /// Current group ID
    gid: GroupId,
    /// Effective user ID (for setuid)
    euid: UserId,
    /// Effective group ID (for setgid)
    egid: GroupId,
    
    /// Check if current user is root
    pub fn is_root(self: *const UserContext) bool {
        return self.euid == 0;
    }
    
    /// Check if user has capability
    pub fn has_capability(self: *const UserContext, cap: u64) bool {
        if (self.is_root()) return true;
        // Future: Check capability bitmap
        return false;
    }
};

/// User Table (Static Allocation)
/// Why: Fixed-size user table, no dynamic allocation
/// Tiger Style: Static array, max 256 users
pub const MAX_USERS: u32 = 256;
pub var users: [MAX_USERS]User = undefined;
pub var user_count: u32 = 0;

/// Initialize Default Users
/// Why: Create root and xy users at kernel boot
pub fn init_users() void {
    // Root user (uid=0)
    users[0] = User{
        .uid = 0,
        .gid = 0,
        .name = "root".*,
        .home = "/root".*,
        .capabilities = 0xFFFFFFFFFFFFFFFF, // All capabilities
    };
    
    // xy user (uid=1000)
    users[1] = User{
        .uid = 1000,
        .gid = 1000,
        .name = "xy".*,
        .home = "/home/xy".*,
        .capabilities = 0x0000000000000001, // Basic user capabilities
    };
    
    user_count = 2;
    
    // Assert: Root user must exist
    std.debug.assert(users[0].uid == 0);
    std.debug.assert(users[1].uid == 1000);
}
```

### Sudo Permissions (Capability-Based)

```zig
/// Sudo Capability
/// Why: Allow non-root users to execute privileged operations
/// Tiger Style: Explicit capability flags, no magic numbers
pub const CAPABILITY_SUDO: u64 = 1 << 0;
pub const CAPABILITY_SHUTDOWN: u64 = 1 << 1;
pub const CAPABILITY_MOUNT: u64 = 1 << 2;

/// Check Sudo Permission
/// Why: Verify user can execute privileged operation
pub fn check_sudo(
    self: *const UserContext,
    capability: u64,
) bool {
    // Root always has all capabilities
    if (self.is_root()) return true;
    
    // Check user's capability bitmap
    const user = find_user(self.uid) orelse return false;
    return (user.capabilities & capability) != 0;
}

/// Sudo Syscall
/// Why: Execute command with elevated privileges
/// Contract: Requires CAPABILITY_SUDO
pub fn syscall_sudo(
    self: *BasinKernel,
    command_ptr: [*]const u8,
    command_len: u32,
    capability: u64,
) SyscallResult {
    // Assert: Current user must have sudo capability
    if (!check_sudo(&self.current_user, CAPABILITY_SUDO)) {
        return .{ .error = .permission_denied };
    }
    
    // Assert: Command pointer must be valid
    if (command_ptr == null or command_len == 0) {
        return .{ .error = .invalid_argument };
    }
    
    // Execute command with elevated privileges
    // Future: Spawn process with euid=0
    return .{ .value = 0 };
}
```

## 3. Path Structure (Unix-Like)

### Standard Path Layout

```
/                    # Root filesystem
├── bin/             # System binaries (static allocation)
├── sbin/            # System admin binaries
├── usr/             # User programs
│   ├── bin/         # User binaries
│   ├── lib/         # Libraries
│   └── local/       # Local installations
├── etc/             # Configuration files
│   ├── passwd       # User database (future)
│   └── sudoers      # Sudo configuration (future)
├── home/            # User home directories
│   ├── root/        # Root home
│   └── xy/          # xy user home
├── var/             # Variable data
│   ├── log/         # Log files
│   └── cache/       # Cache files
├── tmp/             # Temporary files
├── dev/             # Device files (future)
├── proc/            # Process filesystem (future)
└── sys/             # System filesystem (future)
```

### Path Resolution (Static Allocation)

```zig
/// Path Buffer (Static Allocation)
/// Why: Fixed-size path buffer, no dynamic allocation
/// Tiger Style: Explicit size (256), not usize
pub const MAX_PATH_LEN: u32 = 256;
pub const PathBuffer = [MAX_PATH_LEN]u8;

/// Resolve Path
/// Why: Convert relative path to absolute path
/// Contract: Returns canonicalized path, validates user permissions
pub fn resolve_path(
    self: *const UserContext,
    path: []const u8,
    cwd: []const u8,
) !PathBuffer {
    var result: PathBuffer = undefined;
    
    // Assert: Path must be valid
    if (path.len == 0 or path.len > MAX_PATH_LEN) {
        return error.InvalidPath;
    }
    
    // Handle absolute paths
    if (path[0] == '/') {
        // Copy absolute path
        @memcpy(result[0..path.len], path);
        result[path.len] = 0;
        return result;
    }
    
    // Handle relative paths (prepend cwd)
    // Future: Implement path resolution logic
    return result;
}
```

## 4. Zix Build System in Zig

**Name**: **Zix** - Zig + Nix-inspired build system
**Why**: Referentially transparent, content-addressed builds written in pure Zig
**Tiger Style**: Static allocation, deterministic, type-safe, single-threaded

### Architecture: Referentially Transparent Builds

```zig
/// Build Hash (SHA-256, 32 bytes)
/// Why: Content-addressed builds, referentially transparent
/// Tiger Style: Explicit size (32), not usize
pub const BuildHash = [32]u8;

/// Build Store Path
/// Why: Content-addressed store paths like Nix
        /// Format: /zix/store/{hash}-{name}
pub const StorePath = struct {
    /// Build hash (SHA-256 of build inputs)
    hash: BuildHash,
    /// Package name
    name: []const u8,
    /// Full path: /nix/store/{hash}-{name}
    path: PathBuffer,
    
    /// Compute Store Path
    /// Why: Generate deterministic store path from hash and name
    pub fn compute(self: *StorePath) void {
        // Format: /zix/store/{hash}-{name}
        const prefix = "/zix/store/";
        @memcpy(self.path[0..prefix.len], prefix);
        
        // Append hex-encoded hash
        var hash_str: [64]u8 = undefined;
        for (self.hash, 0..) |byte, i| {
            _ = std.fmt.bufPrint(
                hash_str[i*2..i*2+2],
                "{x:0>2}",
                .{byte},
            ) catch unreachable;
        }
        @memcpy(self.path[prefix.len..prefix.len+64], &hash_str);
        
        // Append dash and name
        self.path[prefix.len+64] = '-';
        @memcpy(
            self.path[prefix.len+65..prefix.len+65+self.name.len],
            self.name,
        );
        self.path[prefix.len+65+self.name.len] = 0;
    }
};

/// Build Input
/// Why: Track build dependencies for hash computation
/// Tiger Style: Static allocation, explicit types
pub const BuildInput = struct {
    /// Input type (source, dependency, etc.)
    input_type: enum { source, dependency, tool },
    /// Input hash (content-addressed)
    hash: BuildHash,
    /// Input path
    path: PathBuffer,
};

/// Build Recipe
/// Why: Define how to build a package
/// Tiger Style: Static allocation, deterministic
pub const BuildRecipe = struct {
    /// Package name
    name: []const u8,
    /// Build inputs (max 64 inputs)
    inputs: [64]BuildInput,
    /// Input count
    input_count: u32,
    /// Build script (Zig code or shell commands)
    build_script: []const u8,
    
    /// Compute Build Hash
    /// Why: Generate deterministic hash from inputs and script
    pub fn compute_hash(self: *const BuildRecipe) BuildHash {
        // Hash all inputs + build script
        // Future: Use SHA-256 hashing
        var hash: BuildHash = undefined;
        // Placeholder: actual hash computation
        return hash;
    }
};

/// Build Store (Static Allocation)
/// Why: Track all built packages in store
/// Tiger Style: Static array, max 1024 packages
pub const MAX_STORE_ENTRIES: u32 = 1024;
pub var store_entries: [MAX_STORE_ENTRIES]StorePath = undefined;
pub var store_count: u32 = 0;

/// Build Package
/// Why: Build package and store in content-addressed store
/// Contract: Deterministic builds, same inputs → same output
pub fn build_package(recipe: *const BuildRecipe) !StorePath {
    // Compute build hash
    const hash = recipe.compute_hash();
    
    // Check if already built
    for (store_entries[0..store_count]) |entry| {
        if (std.mem.eql(u8, &entry.hash, &hash)) {
            return entry; // Already built, return existing
        }
    }
    
    // Build package
    // Future: Execute build script, capture output
    
    // Store in build store
    var store_path = StorePath{
        .hash = hash,
        .name = recipe.name,
        .path = undefined,
    };
    store_path.compute();
    
    // Assert: Store path must be unique
    std.debug.assert(store_count < MAX_STORE_ENTRIES);
    store_entries[store_count] = store_path;
    store_count += 1;
    
    return store_path;
}
```

### Integration with GrainDB

```zig
/// GrainDB Store Integration
/// Why: Use graindb for immutable build store
/// Contract: All builds stored in referentially transparent database
pub const GrainDBBuildStore = struct {
    /// GrainDB connection (future)
    db: *graindb.Connection,
    
    /// Store Build Result
    /// Why: Store build output in immutable database
    pub fn store_build(
        self: *GrainDBBuildStore,
        hash: BuildHash,
        output: []const u8,
    ) !void {
        // Store in graindb with hash as key
        // Future: Use graindb's immutable storage
    }
    
    /// Retrieve Build Result
    /// Why: Fetch build output by hash
    pub fn retrieve_build(
        self: *const GrainDBBuildStore,
        hash: BuildHash,
    ) ![]const u8 {
        // Retrieve from graindb by hash
        // Future: Use graindb's content-addressed lookup
        return "";
    }
};
```

## 5. TigerStyle Evolution for Distributed Database

### Principles for GrainDB

1. **Referential Transparency**: Same inputs → same outputs (content-addressed)
2. **Immutability**: All writes create new versions, never modify existing
3. **Static Allocation**: Fixed-size structures, no dynamic allocation
4. **Single-Threaded**: No locks, deterministic execution
5. **Type Safety**: Explicit types (u32 not usize), comprehensive assertions
6. **Content Addressing**: SHA-256 hashes for all data
7. **Distributed**: Eventually consistent, conflict-free replicated data types

### GrainDB Architecture (Future)

```zig
/// GrainDB Node
/// Why: Distributed database node with immutable storage
/// Tiger Style: Static allocation, single-threaded
pub const GrainDBNode = struct {
    /// Node ID (unique identifier)
    node_id: u64,
    /// Local store (immutable, content-addressed)
    store: *ImmutableStore,
    /// Replication log (append-only)
    replication_log: *ReplicationLog,
    
    /// Write Operation
    /// Why: Create new version, never modify existing
    pub fn write(
        self: *GrainDBNode,
        key: []const u8,
        value: []const u8,
    ) !Version {
        // Compute content hash
        const hash = compute_hash(value);
        
        // Store in immutable store (never overwrites)
        try self.store.put(hash, value);
        
        // Append to replication log
        try self.replication_log.append(.{
            .op = .write,
            .key = key,
            .hash = hash,
        });
        
        return Version{
            .hash = hash,
            .timestamp = get_timestamp(),
        };
    }
    
    /// Read Operation
    /// Why: Read by content hash (referentially transparent)
    pub fn read(
        self: *const GrainDBNode,
        hash: BuildHash,
    ) ![]const u8 {
        // Retrieve from immutable store by hash
        return self.store.get(hash);
    }
};
```

## 6. Implementation Priority

### Phase 1: VM Shutdown (Immediate)
1. Add `shutdown` syscall to `basin_kernel.zig`
2. Implement VM reboot logic (reset state, reload kernel)
3. Add shutdown type enum (HALT, REBOOT, POWER_OFF)

### Phase 2: User Management (Short-term)
1. Implement `User` and `UserContext` structs
2. Initialize root and xy users at kernel boot
3. Add permission checks to syscalls (shutdown, mount, etc.)
4. Implement `sudo` syscall (capability-based)

### Phase 3: Path Structure (Short-term)
1. Implement path resolution (`resolve_path`)
2. Create standard directory structure (`/bin`, `/home`, `/etc`, etc.)
3. Add `chdir` syscall for current working directory

### Phase 4: Nix-Like Build System (Medium-term)
1. Implement `BuildHash` and `StorePath` structures
2. Create build store (`/nix/store` directory)
3. Implement `build_package` function
4. Add build syscalls (`build`, `query_store`)

### Phase 5: GrainDB Integration (Long-term)
1. Design GrainDB architecture (immutable, content-addressed)
2. Implement basic GrainDB node (write, read operations)
3. Integrate GrainDB with build store
4. Add replication and distributed features

## 7. z6: Process Supervision Daemon (s6-like)

### Architecture: Single-Threaded Process Supervision

```zig
/// z6: Process Supervision Daemon
/// Why: Manage long-running services, restart crashed processes
/// Inspired by: s6 process supervision suite
/// Tiger Style: Single-threaded, static allocation, deterministic

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

/// Service Definition
/// Why: Define how to run a service
/// Tiger Style: Static allocation, explicit types
pub const ServiceDef = struct {
    /// Service name (max 64 chars)
    name: [64]u8,
    /// Executable path (max 256 chars)
    executable: [256]u8,
    /// Arguments (max 16 args, each max 256 chars)
    args: [16][256]u8,
    /// Argument count
    arg_count: u32,
    /// Restart policy (always, never, on-failure)
    restart_policy: enum { always, never, on_failure },
    /// Restart delay (milliseconds)
    restart_delay_ms: u32,
    /// Dependencies (service names that must start first)
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
};

/// Service Instance
/// Why: Track running service instance
/// Tiger Style: Static allocation, explicit types
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
        const time_since_restart = now_ms - self.last_restart_ms;
        if (time_since_restart < self.def.restart_delay_ms) {
            return false; // Too soon to restart
        }
        
        // Check crash rate (max 10 crashes per minute)
        const one_minute_ms: u64 = 60 * 1000;
        if (time_since_restart < one_minute_ms and self.crash_count >= 10) {
            return false; // Too many crashes, give up
        }
        
        return true;
    }
};

/// z6 Supervisor Daemon
/// Why: Main supervision daemon that manages all services
/// Tiger Style: Single-threaded, static allocation, deterministic
pub const Z6Supervisor = struct {
    /// Service instances (max 64 services)
    services: [64]ServiceInstance,
    /// Service count
    service_count: u32,
    /// Kernel handle (for syscalls)
    kernel: *BasinKernel,
    /// Current time (milliseconds since boot)
    current_time_ms: u64,
    
    /// Initialize z6 Supervisor
    /// Why: Set up supervision daemon
    pub fn init(
        self: *Z6Supervisor,
        kernel: *BasinKernel,
    ) void {
        self.kernel = kernel;
        self.service_count = 0;
        self.current_time_ms = 0;
        
        // Assert: Kernel pointer must be valid
        std.debug.assert(@intFromPtr(kernel) != 0);
    }
    
    /// Register Service
    /// Why: Add service to supervision
    pub fn register_service(
        self: *Z6Supervisor,
        def: ServiceDef,
    ) !void {
        // Assert: Service definition must be valid
        def.validate();
        
        // Assert: Must have room for more services
        if (self.service_count >= 64) {
            return error.TooManyServices;
        }
        
        // Create service instance
        self.services[self.service_count] = ServiceInstance{
            .def = def,
            .state = .stopped,
            .pid = 0,
            .exit_status = 0,
            .crash_count = 0,
            .last_restart_ms = 0,
        };
        
        self.service_count += 1;
        
        // Assert: Service count must be valid
        std.debug.assert(self.service_count <= 64);
    }
    
    /// Start Service
    /// Why: Spawn service process via kernel
    pub fn start_service(
        self: *Z6Supervisor,
        service_idx: u32,
    ) !void {
        // Assert: Service index must be valid
        std.debug.assert(service_idx < self.service_count);
        
        var service = &self.services[service_idx];
        
        // Assert: Service must be stopped
        std.debug.assert(service.state == .stopped);
        
        // Check dependencies (all must be running)
        for (service.def.dependencies[0..service.def.dep_count]) |dep_name| {
            const dep_idx = self.find_service_by_name(dep_name) orelse {
                return error.DependencyNotFound;
            };
            const dep = &self.services[dep_idx];
            if (dep.state != .running) {
                return error.DependencyNotRunning;
            }
        }
        
        // Spawn process via kernel
        service.state = .starting;
        const pid_result = self.kernel.syscall_spawn(
            service.def.executable[0..std.mem.len(service.def.executable)],
            service.def.args[0..service.def.arg_count],
        );
        
        switch (pid_result) {
            .value => |pid| {
                service.pid = @as(u32, @intCast(pid));
                service.state = .running;
            },
            .error => |err| {
                service.state = .stopped;
                return err;
            },
        }
    }
    
    /// Stop Service
    /// Why: Terminate service process
    pub fn stop_service(
        self: *Z6Supervisor,
        service_idx: u32,
    ) !void {
        // Assert: Service index must be valid
        std.debug.assert(service_idx < self.service_count);
        
        var service = &self.services[service_idx];
        
        // Assert: Service must be running
        if (service.state != .running) {
            return error.ServiceNotRunning;
        }
        
        // Send exit signal to process (future: signal syscall)
        // For now: Use kernel exit syscall
        service.state = .stopping;
        
        // Wait for process to exit
        const wait_result = self.kernel.syscall_wait(service.pid);
        switch (wait_result) {
            .value => |exit_status| {
                service.exit_status = exit_status;
                service.state = .stopped;
            },
            .error => |err| {
                return err;
            },
        }
    }
    
    /// Check Service Health
    /// Why: Monitor running services, restart crashed ones
    pub fn check_services(self: *Z6Supervisor) !void {
        // Update current time
        const time_result = self.kernel.syscall_clock_gettime(.realtime);
        switch (time_result) {
            .value => |timespec| {
                self.current_time_ms = @as(u64, @intCast(
                    timespec.tv_sec * 1000 + timespec.tv_nsec / 1000000
                ));
            },
            .error => |_| {
                // Time unavailable, continue anyway
            },
        }
        
        // Check all running services
        for (0..self.service_count) |i| {
            const service = &self.services[i];
            
            if (service.state == .running) {
                // Check if process is still alive
                const wait_result = self.kernel.syscall_wait(service.pid);
                switch (wait_result) {
                    .value => |exit_status| {
                        // Process exited
                        service.exit_status = exit_status;
                        service.state = .crashed;
                        service.crash_count += 1;
                        service.last_restart_ms = self.current_time_ms;
                        
                        // Restart if needed
                        if (service.should_restart() and service.can_restart(self.current_time_ms)) {
                            try self.start_service(@as(u32, @intCast(i)));
                        }
                    },
                    .error => |err| {
                        // Process still running (wait returned error)
                        if (err != .process_not_found) {
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
    
    /// Find Service by Name
    /// Why: Look up service index by name
    pub fn find_service_by_name(
        self: *const Z6Supervisor,
        name: []const u8,
    ) ?u32 {
        for (0..self.service_count) |i| {
            const service = &self.services[i];
            const service_name = service.def.name[0..std.mem.len(service.def.name)];
            if (std.mem.eql(u8, service_name, name)) {
                return @as(u32, @intCast(i));
            }
        }
        return null;
    }
    
    /// Run Supervision Loop
    /// Why: Main daemon loop that checks services periodically
    pub fn run(self: *Z6Supervisor) !void {
        // Main supervision loop
        while (true) {
            // Check service health
            try self.check_services();
            
            // Sleep for 1 second before next check
            const sleep_result = self.kernel.syscall_sleep_until(
                self.current_time_ms + 1000,
            );
            switch (sleep_result) {
                .value => {},
                .error => |_| {
                    // Sleep failed, continue anyway
                },
            }
        }
    }
};
```

### Service Directory Structure (s6-like)

```
/etc/z6/
├── service1/
│   ├── run          # Service executable script
│   ├── finish       # Cleanup script (optional)
│   ├── log/         # Logging service (optional)
│   │   └── run      # Log service executable
│   └── dependencies # Service dependencies (one per line)
├── service2/
│   └── run
└── z6-supervisor/   # z6 daemon itself
    └── run
```

### Implementation Plan

1. **Phase 1: Core Supervision** (Short-term)
   - Implement `Z6Supervisor` struct
   - Add service registration and start/stop
   - Implement basic health checking (wait syscall)

2. **Phase 2: Restart Logic** (Short-term)
   - Implement restart policies (always, never, on-failure)
   - Add restart delay and crash rate limiting
   - Handle dependency resolution

3. **Phase 3: Logging** (Medium-term)
   - Capture stdout/stderr from services
   - Route logs to kernel logging syscall
   - Implement log rotation

4. **Phase 4: Service Directory** (Medium-term)
   - Parse service directories (`/etc/z6/service/`)
   - Load service definitions from files
   - Support `run` and `finish` scripts

5. **Phase 5: Integration** (Medium-term)
   - Integrate with kernel process management
   - Add z6 as system service (supervised by itself)
   - Add z6 control commands (`z6ctl start/stop/status`)

### TigerStyle Alignment
- Single-threaded: No locks, deterministic execution
- Static allocation: Fixed-size arrays (64 services max)
- Explicit types: u32 not usize, comprehensive assertions
- Safety-first: Validate all inputs, check all states

## 8. Integration with ray.md and plan.md

### Updates Needed
1. **ray.md**: Add VM shutdown, user management, Nix-like build system, z6 sections
2. **plan.md**: Add implementation phases for user management, build system, z6
3. **graindb.md**: Create new document for GrainDB architecture (future)

### TigerStyle Alignment
- All new code follows TigerStyle principles
- Static allocation, explicit types, comprehensive assertions
- Single-threaded, deterministic execution
- Safety-first, performance-second, joy-third

