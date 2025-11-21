//! VM-Kernel Integration Layer
//! Why: Bridge VM syscall interface (u64 return) with kernel syscall interface (SyscallResult).
//! Grain Style: Comprehensive contracts, explicit types, input/output validation.

const std = @import("std");
const VM = @import("vm.zig").VM;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const BasinError = basin_kernel.BasinError;
const SyscallResult = basin_kernel.SyscallResult;
const loadKernel = @import("loader.zig").loadKernel;

/// Module-level kernel pointer for syscall handler access.
/// Why: VM syscall handler interface doesn't support closures, so we use module-level storage.
/// Contract: Must be set before syscall_handler_wrapper is called (set by Integration.finish_init).
/// Note: Safe for single-threaded execution only.
var global_kernel_ptr: ?*BasinKernel = null;

/// VM-Kernel integration state.
/// Why: Encapsulate VM and kernel instances, manage lifecycle.
/// Grain Style: Static allocation, explicit state tracking.
/// Note: Stores VM and kernel pointers instead of values to avoid copying large structs (stack overflow prevention).
pub const Integration = struct {
    /// VM instance pointer (RISC-V64 emulator).
    /// Why: Store pointer instead of value to avoid copying 4MB struct.
    vm: *VM,
    /// Kernel instance pointer (Grain Basin kernel).
    /// Why: Store pointer instead of value to avoid copying ~75KB struct (users array).
    kernel: *BasinKernel,
    /// Whether integration is initialized.
    initialized: bool,

    const Self = @This();

    /// Initialize integration with kernel ELF.
    /// Contract:
    ///   Input: vm_ptr must point to uninitialized VM struct, elf_data must be non-empty, valid RISC-V64 ELF
    ///   Output: Initialized Integration instance, VM PC set to entry point
    ///   Errors: Invalid ELF format, memory allocation failure
    /// Why: Load kernel into VM, initialize kernel state.
    /// Note: Returns uninitialized Self, caller must call finish_init() to complete setup.
    /// Note: Caller must ensure vm_ptr lives for the lifetime of Integration.
    /// GrainStyle: In-place initialization pattern - caller provides storage.
    pub fn init(vm_ptr: *VM, elf_data: []const u8) !Self {
        // Contract: ELF data must be non-empty.
        if (elf_data.len == 0) {
            return error.EmptyElfData;
        }

        // Contract: ELF data must be large enough for ELF header (64 bytes minimum).
        const MIN_ELF_HEADER_SIZE: u32 = 64;
        if (elf_data.len < MIN_ELF_HEADER_SIZE) {
            return error.InvalidElfHeader;
        }

        // Load kernel ELF into VM (in-place initialization).
        // Contract: loadKernel validates ELF format, initializes VM in-place.
        // GrainStyle: Use in-place initialization to avoid stack overflow.
        try loadKernel(vm_ptr, std.heap.page_allocator, elf_data);

        // Contract: VM must be in halted state after loading.
        std.debug.assert(vm_ptr.state == .halted);

        // Note: finish_init() will complete the setup.
        // Note: Kernel will be initialized by caller and passed as pointer.

        // Return uninitialized Integration (will be finished by finish_init).
        // Note: Store pointers to VM and kernel to avoid copying large structs.
        // Caller must provide kernel pointer.
        unreachable; // Use init_with_kernel instead
    }

    /// Initialize integration with VM and kernel pointers.
    /// Contract:
    ///   Input: vm_ptr and kernel_ptr must point to initialized VM and kernel instances
    ///   Output: Uninitialized Integration instance (caller must call finish_init())
    /// Why: Allow caller to allocate kernel on heap to avoid stack overflow.
    /// GrainStyle: In-place initialization pattern - caller provides storage.
    pub fn init_with_kernel(vm_ptr: *VM, kernel_ptr: *BasinKernel) Self {
        // Contract: VM and kernel pointers must be valid.
        const vm_addr = @intFromPtr(vm_ptr);
        const kernel_addr = @intFromPtr(kernel_ptr);
        std.debug.assert(vm_addr != 0);
        std.debug.assert(kernel_addr != 0);
        std.debug.assert(vm_addr % @alignOf(VM) == 0);
        std.debug.assert(kernel_addr % @alignOf(BasinKernel) == 0);

        return Self{
            .vm = vm_ptr,
            .kernel = kernel_ptr,
            .initialized = false,
        };
    }

    /// Finish initialization (set up syscall handler and framebuffer).
    /// Contract:
    ///   Input: Self must be partially initialized (VM and kernel set)
    ///   Output: Integration fully initialized, syscall handler registered, framebuffer initialized
    /// Why: Complete initialization after Self is created (needed for thread-local storage).
    /// Note: Framebuffer is initialized before kernel execution starts (host-side initialization).
    pub fn finish_init(self: *Self) void {
        // Contract: Integration must not be already initialized.
        std.debug.assert(!self.initialized);

        // Set module-level kernel pointer for syscall handler access.
        // Contract: kernel pointer must be valid.
        const kernel_ptr = @intFromPtr(self.kernel);
        std.debug.assert(kernel_ptr != 0);
        std.debug.assert(kernel_ptr % @alignOf(BasinKernel) == 0);
        
        // Set module-level storage (accessed by syscall_handler_wrapper).
        // Note: Allow resetting if already set (for testing scenarios).
        // In production, this should be null, but in tests we may need to reset.
        global_kernel_ptr = self.kernel;

        // Register kernel as VM syscall handler.
        // Contract: syscall_handler_wrapper will access kernel via thread-local storage.
        self.vm.*.set_syscall_handler(syscall_handler_wrapper, null);

        // Initialize framebuffer from host-side (before kernel execution starts).
        // Why: Set up framebuffer with test pattern for visual verification.
        // Contract: VM must be initialized and kernel loaded before framebuffer initialization.
        self.vm.*.init_framebuffer();

        // Contract: Integration must be initialized after finish_init.
        self.initialized = true;
        std.debug.assert(self.initialized);
    }

    /// Cleanup integration (reset module-level state).
    /// Contract:
    ///   Input: Integration must be initialized
    ///   Output: Module-level state reset, safe for creating new Integration instance
    /// Why: Allow multiple Integration instances in tests (reset global_kernel_ptr).
    pub fn cleanup(self: *Self) void {
        // Contract: Integration must be initialized.
        std.debug.assert(self.initialized);

        // Reset module-level storage (allows creating new Integration instance).
        // Contract: Only reset if this Integration instance owns the global pointer.
        if (global_kernel_ptr) |ptr| {
            if (ptr == self.kernel) {
                global_kernel_ptr = null;
            }
        }

        // Reset initialization flag.
        self.initialized = false;
    }

    /// Run VM execution loop until halted or error.
    /// Contract:
    ///   Input: Integration must be initialized
    ///   Output: VM execution completes (halted or errored)
    ///   Errors: VM execution errors (invalid instruction, memory access)
    /// Why: Execute VM instructions, handle syscalls via kernel.
    pub fn run(self: *Self) !void {
        // Contract: Integration must be initialized.
        std.debug.assert(self.initialized);

        // Contract: VM must be in halted state before starting.
        std.debug.assert(self.vm.*.state == .halted);

        // Start VM execution.
        self.vm.*.start();

        // Contract: VM must be in running state after start.
        std.debug.assert(self.vm.*.state == .running);

        // Execute VM instructions until halted or error.
        while (self.vm.*.state == .running) {
            // Contract: VM step may return error (invalid instruction, memory access).
            try self.vm.*.step();
        }

        // Contract: VM must be halted or errored after loop.
        std.debug.assert(self.vm.*.state == .halted or self.vm.*.state == .errored);
    }

    /// Get VM state.
    /// Contract:
    ///   Input: Integration must be initialized
    ///   Output: Current VM state (running, halted, errored)
    /// Why: Query VM execution state.
    pub fn get_vm_state(self: *const Self) VM.VMState {
        // Contract: Integration must be initialized.
        std.debug.assert(self.initialized);

        return self.vm.*.state;
    }

    /// Get kernel instance (for testing/debugging).
    /// Contract:
    ///   Input: Integration must be initialized
    ///   Output: Non-null pointer to kernel instance
    /// Why: Allow external access to kernel for testing/debugging.
    pub fn get_kernel(self: *Self) *BasinKernel {
        // Contract: Integration must be initialized.
        std.debug.assert(self.initialized);

        // Contract: Kernel pointer must be valid.
        const kernel_ptr = @intFromPtr(&self.kernel);
        std.debug.assert(kernel_ptr != 0);
        std.debug.assert(kernel_ptr % @alignOf(BasinKernel) == 0);

        return &self.kernel;
    }

    /// Get VM instance (for testing/debugging).
    /// Contract:
    ///   Input: Integration must be initialized
    ///   Output: Non-null pointer to VM instance
    /// Why: Allow external access to VM for testing/debugging.
    pub fn get_vm(self: *Self) *VM {
        // Contract: Integration must be initialized.
        std.debug.assert(self.initialized);

        // Contract: VM pointer must be valid.
        const vm_ptr = @intFromPtr(self.vm);
        std.debug.assert(vm_ptr != 0);
        std.debug.assert(vm_ptr % @alignOf(VM) == 0);

        return self.vm;
    }
};

/// Syscall handler wrapper (converts SyscallResult to u64).
/// Contract:
///   Input: syscall_num >= 10 (kernel syscalls), user_data must be valid Integration pointer
///   Output: u64 result (negative = error code, non-negative = success value)
///   Errors: Panic if user_data is null or invalid
/// Why: Bridge VM syscall interface (u64) with kernel interface (SyscallResult).
/// RISC-V Convention: Negative values = error codes, non-negative = success values.
/// Note: VM passes user_data (set via set_syscall_handler) to handler.
///       We cast user_data to Integration* and extract kernel from it.
fn syscall_handler_wrapper(
    syscall_num: u32,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
) u64 {
    // Contract: syscall_num must be >= 10 (kernel syscalls, not SBI).
    std.debug.assert(syscall_num >= 10);

    // Get Integration instance from VM's user_data.
    // Contract: VM must have set user_data to Integration pointer.
    // Note: We need to access VM's user_data, but VM interface doesn't expose it directly.
    // We'll use a workaround: VM stores user_data internally, we access it via closure.
    // Actually, VM's execute_ecall calls handler directly, so we can't access user_data here.
    // Solution: Use thread-local storage or global variable (not ideal, but works for single-threaded).
    
    // Better solution: Refactor to use closure pattern or pass kernel directly.
    // For now, we'll use a static variable set by Integration.init().
    // This is safe for single-threaded execution.
    
    // Get kernel pointer from module-level storage (set by Integration.finish_init).
    // Contract: global_kernel_ptr must be set before syscall_handler_wrapper is called.
    const kernel = global_kernel_ptr orelse {
        @panic("syscall_handler_wrapper called before Integration.finish_init");
    };

    // Contract: kernel pointer must be valid.
    const kernel_addr = @intFromPtr(kernel);
    std.debug.assert(kernel_addr != 0);
    std.debug.assert(kernel_addr % @alignOf(BasinKernel) == 0);

    return syscall_handler_wrapper_impl(kernel, syscall_num, arg1, arg2, arg3, arg4);
}

/// Internal syscall handler implementation.
/// Contract:
///   Input: kernel must be valid BasinKernel pointer, syscall_num >= 10
///   Output: u64 result (negative = error code, non-negative = success value)
/// Why: Separate implementation from wrapper for clarity.
fn syscall_handler_wrapper_impl(
    kernel: *BasinKernel,
    syscall_num: u32,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
) u64 {
    // Contract: syscall_num must be >= 10 (kernel syscalls, not SBI).
    std.debug.assert(syscall_num >= 10);

    // Contract: kernel pointer must be valid.
    const kernel_ptr = @intFromPtr(kernel);
    std.debug.assert(kernel_ptr != 0);
    std.debug.assert(kernel_ptr % @alignOf(BasinKernel) == 0);

    // Call kernel syscall handler.
    // Contract: handle_syscall returns BasinError!SyscallResult.
    const result = kernel.handle_syscall(syscall_num, arg1, arg2, arg3, arg4) catch |err| {
        // Contract: BasinError must be converted to negative u64.
        // RISC-V convention: Negative values = error codes.
        // Error codes: -1 = invalid_handle, -2 = invalid_argument, etc.
        const error_code: i64 = switch (err) {
            BasinError.invalid_handle => -1,
            BasinError.invalid_argument => -2,
            BasinError.permission_denied => -3,
            BasinError.not_found => -4,
            BasinError.out_of_memory => -5,
            BasinError.would_block => -6,
            BasinError.interrupted => -7,
            BasinError.invalid_syscall => -8,
            BasinError.invalid_address => -9,
            BasinError.unaligned_access => -10,
            BasinError.out_of_bounds => -11,
            BasinError.user_not_found => -12,
            BasinError.invalid_user => -13,
        };
        return @as(u64, @bitCast(error_code));
    };

    // Contract: SyscallResult must be success or error.
    return switch (result) {
        .success => |value| {
            // Contract: Success value must be non-negative (RISC-V convention).
            std.debug.assert(value >= 0);
            return value;
        },
        .err => |err| {
            // Contract: Error must be converted to negative u64.
            const error_code: i64 = switch (err) {
            BasinError.invalid_handle => -1,
            BasinError.invalid_argument => -2,
            BasinError.permission_denied => -3,
            BasinError.not_found => -4,
            BasinError.out_of_memory => -5,
            BasinError.would_block => -6,
            BasinError.interrupted => -7,
            BasinError.invalid_syscall => -8,
            BasinError.invalid_address => -9,
            BasinError.unaligned_access => -10,
            BasinError.out_of_bounds => -11,
            BasinError.user_not_found => -12,
            BasinError.invalid_user => -13,
            };
            return @as(u64, @bitCast(error_code));
        },
    };
}

/// Load userspace ELF program into VM.
/// Contract:
///   Input: elf_data must be non-empty, valid RISC-V64 ELF executable
///   Output: VM with userspace program loaded, PC set to entry point, SP set to stack address
///   Errors: Invalid ELF format, address out of bounds, memory allocation failure
/// Why: Load userspace programs (not kernel) into VM memory.
/// Note: Userspace programs typically load at addresses like 0x10000+ (different from kernel at 0x1000).
/// Note: RISC-V ELF executables are typically position-independent and use their own virtual addresses.
pub fn loadUserspaceELF(
    target: *VM,
    allocator: std.mem.Allocator,
    elf_data: []const u8,
    argv: []const []const u8,
) !void {
    
    // Contract: ELF data must be non-empty.
    if (elf_data.len == 0) {
        std.debug.print("DEBUG integration.zig: ELF data is empty\n", .{});
        return error.EmptyElfData;
    }

    // Contract: ELF data must be large enough for ELF header (64 bytes minimum).
    const MIN_ELF_HEADER_SIZE: u32 = 64;
    if (elf_data.len < MIN_ELF_HEADER_SIZE) {
        std.debug.print("DEBUG integration.zig: ELF data too small ({} < {})\n", .{ elf_data.len, MIN_ELF_HEADER_SIZE });
        return error.InvalidElfHeader;
    }

    // Use existing loadKernel function (it's generic enough for userspace too).
    // Contract: loadKernel validates ELF format and loads segments at their virtual addresses.
    // Note: RISC-V ELF executables specify their own load addresses in p_vaddr.
    std.debug.print("DEBUG integration.zig: About to call loadKernel, allocator.ptr=0x{x}\n", .{@intFromPtr(allocator.ptr)});
    std.debug.print("DEBUG integration.zig: elf_data.ptr=0x{x}, elf_data.len={}\n", .{ @intFromPtr(elf_data.ptr), elf_data.len });
    
    // GrainStyle: Use in-place initialization to avoid stack overflow.
    std.debug.print("DEBUG integration.zig: Calling loadKernel...\n", .{});
    loadKernel(target, allocator, elf_data) catch |err| {
        std.debug.print("DEBUG integration.zig: loadKernel failed: {}\n", .{err});
        // Convert LoaderError to IntegrationError.
        return switch (err) {
            error.SegmentOutOfBounds => error.AddressOutOfBounds,
            error.InvalidElfFormat => error.InvalidElfHeader,
        };
    };
    std.debug.print("DEBUG integration.zig: loadKernel completed successfully\n", .{});

    // Contract: VM must be in halted state after loading.
    // Check: VM state must be halted (return error instead of asserting for userspace programs).
    std.debug.print("DEBUG integration.zig: Checking VM state...\n", .{});
    if (target.state != .halted) {
        std.debug.print("DEBUG integration.zig: VM state is {}, expected halted\n", .{target.state});
        return error.InvalidState;
    }
    std.debug.print("DEBUG integration.zig: VM state is halted\n", .{});

    // Contract: PC must be set to entry point (done by loadKernel).
    // Note: Entry point can be 0x0 for some programs (e.g., position-independent executables).
    // We only check that it's within VM memory bounds (done in loadKernel).
    std.debug.print("DEBUG integration.zig: PC=0x{x}\n", .{target.regs.pc});
    _ = target.regs.pc; // PC is set by loadKernel

    // Set up userspace stack pointer (SP register = x2).
    std.debug.print("DEBUG integration.zig: Setting up stack...\n", .{});
    // Contract: Stack address must be page-aligned and within VM memory.
    const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB
    const PAGE_SIZE: u64 = 4096;
    const STACK_ADDRESS: u64 = VM_MEMORY_SIZE - PAGE_SIZE; // Top of memory, page-aligned
    std.debug.print("DEBUG integration.zig: STACK_ADDRESS=0x{x}, target.memory_size=0x{x}\n", .{ STACK_ADDRESS, target.memory_size });
    // Check: Stack address must be page-aligned and within VM memory.
    if (STACK_ADDRESS % PAGE_SIZE != 0 or STACK_ADDRESS >= target.memory_size) {
        std.debug.print("DEBUG integration.zig: Stack address validation failed\n", .{});
        return error.AddressOutOfBounds;
    }
    std.debug.print("DEBUG integration.zig: Stack address validated, setting SP register...\n", .{});

    target.regs.set(2, STACK_ADDRESS); // x2 = SP register
    std.debug.print("DEBUG integration.zig: SP register set successfully\n", .{});

    // Contract: SP register must be set correctly (verified by regs.set above).
    // Note: We don't assert here to avoid crashes during userspace program loading.

    // Set up argv/argc on stack (RISC-V calling convention).
    // Contract: argv array and strings must fit in stack space.
    // Note: RISC-V calling convention: a0 = argc, a1 = argv pointer
    // Stack layout (from high to low, growing downward):
    //   [argc][argv_ptr][argv[0] ptr][argv[1] ptr]...[argv[N] ptr][null terminator][argv[0] string][argv[1] string]...
    //   High address (STACK_ADDRESS)                                    Low address (sp after setup)
    if (argv.len > 0) {
        var sp: u64 = STACK_ADDRESS;
        
        // Calculate total space needed:
        // - argv array: (argv.len + 1) * 8 bytes (pointers + null terminator)
        // - strings: sum of all string lengths + null terminators
        var total_string_len: u64 = 0;
        for (argv) |arg| {
            total_string_len += arg.len + 1; // +1 for null terminator
        }
        
        // Align string data to 8-byte boundary
        const string_data_size = (total_string_len + 7) & ~@as(u64, 7);
        
        // Calculate argv array address (before strings)
        const argv_array_size = (argv.len + 1) * 8; // +1 for null terminator
        const argv_array_addr = sp - 16 - argv_array_size; // Reserve 16 bytes for argc/argv_ptr
        
        // Calculate string data start address (after argv array)
        const string_data_start = argv_array_addr - string_data_size;
        
        // Check: All addresses must be within VM memory bounds.
        // Note: Stack grows downward, so string_data_start should be less than STACK_ADDRESS.
        if (string_data_start >= STACK_ADDRESS or string_data_start + string_data_size > target.memory_size) {
            std.debug.print("DEBUG integration.zig: argv setup would exceed stack bounds: string_data_start=0x{x}, STACK_ADDRESS=0x{x}, memory_size=0x{x}\n", .{ string_data_start, STACK_ADDRESS, target.memory_size });
            return error.AddressOutOfBounds;
        }
        
        // Write strings to stack (from low to high address)
        var current_string_addr = string_data_start;
        var argv_ptrs: [256]u64 = undefined; // Max 256 arguments
        if (argv.len > 256) {
            return error.TooManyArguments;
        }
        
        for (argv, 0..) |arg, i| {
            // Store string address in argv_ptrs array
            argv_ptrs[i] = current_string_addr;
            
            // Write string data (with null terminator)
            if (current_string_addr + arg.len + 1 > target.memory_size) {
                return error.AddressOutOfBounds;
            }
            @memcpy(target.memory[@intCast(current_string_addr)..@intCast(current_string_addr + arg.len)], arg);
            target.memory[@intCast(current_string_addr + arg.len)] = 0; // Null terminator
            
            // Move to next string (aligned to 8 bytes)
            current_string_addr += (arg.len + 1 + 7) & ~@as(u64, 7);
        }
        
        // Write argv array (pointers to strings, followed by null terminator)
        var argv_array_current = argv_array_addr;
        for (0..argv.len) |i| {
            if (argv_array_current + 8 > target.memory_size) {
                return error.AddressOutOfBounds;
            }
            @memcpy(target.memory[@intCast(argv_array_current)..@intCast(argv_array_current + 8)], &std.mem.toBytes(argv_ptrs[i]));
            argv_array_current += 8;
        }
        
        // Write null terminator for argv array
        if (argv_array_current + 8 > target.memory_size) {
            return error.AddressOutOfBounds;
        }
        @memcpy(target.memory[@intCast(argv_array_current)..@intCast(argv_array_current + 8)], &[_]u8{0} ** 8);
        
        // Reserve space for argc and argv pointer (16 bytes, 8-byte aligned)
        sp -= 16;
        
        // Write argc (argument count) at sp
        if (sp + 8 > target.memory_size) {
            return error.AddressOutOfBounds;
        }
        const argc: u64 = argv.len;
        @memcpy(target.memory[@intCast(sp)..@intCast(sp + 8)], &std.mem.toBytes(argc));
        
        // Write argv pointer (points to array of string pointers) at sp + 8
        if (sp + 16 > target.memory_size) {
            return error.AddressOutOfBounds;
        }
        @memcpy(target.memory[@intCast(sp + 8)..@intCast(sp + 16)], &std.mem.toBytes(argv_array_addr));
        
        // Set registers according to RISC-V calling convention
        target.regs.set(10, argc); // a0 = argc
        target.regs.set(11, argv_array_addr); // a1 = argv (pointer to array of string pointers)
        
        // Update SP to point to new stack top (after argc/argv_ptr)
        target.regs.set(2, sp);
        
        std.debug.print("DEBUG integration.zig: argv setup complete: argc={}, argv_ptr=0x{x}, sp=0x{x}\n", .{ argc, argv_array_addr, sp });
    } else {
        // No arguments: argc = 0, argv = null
        target.regs.set(10, 0); // a0 = argc = 0
        target.regs.set(11, 0); // a1 = argv = null
        std.debug.print("DEBUG integration.zig: No argv provided, argc=0, argv=null\n", .{});
    }

    // Assert: VM must be in halted state after loading.
    std.debug.print("DEBUG integration.zig: Final check: VM state={}\n", .{target.state});
    std.debug.assert(target.state == .halted);
    std.debug.print("DEBUG integration.zig: loadUserspaceELF completed successfully\n", .{});
}

/// Integration errors.
/// Why: Explicit error types for VM-kernel integration.
pub const IntegrationError = error{
    EmptyElfData,
    InvalidElfHeader,
    AddressOutOfBounds,
    InvalidState,
    UnalignedAddress,
    TooManyArguments,
    UserNotFound,
    InvalidUser,
};
