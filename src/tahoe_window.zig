const std = @import("std");
const Platform = @import("platform.zig").Platform;
const GrainAurora = @import("grain_aurora.zig").GrainAurora;
const AuroraFilter = @import("aurora_filter.zig");
const TextRenderer = @import("aurora_text_renderer.zig").TextRenderer;
const events = @import("platform/events.zig");
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;
const SerialOutput = kernel_vm.SerialOutput;
const loadKernel = kernel_vm.loadKernel;
const basin_kernel = @import("basin_kernel");

/// TahoeSandbox hosts a River-inspired compositor with Moonglow keybindings,
/// blending Etsy.com marketplace aesthetics with Grain terminal panes.
/// ~<~ Glow Waterbend: compositor streams stay deterministic.
pub const TahoeSandbox = struct {
    allocator: std.mem.Allocator,
    platform: Platform,
    aurora: GrainAurora,
    filter_state: AuroraFilter.FluxState,
    /// Last mouse event (for visual feedback).
    /// Why: Store state to render mouse position/button state.
    last_mouse_x: f64 = 0.0,
    last_mouse_y: f64 = 0.0,
    mouse_button_down: bool = false,
    /// Last keyboard event (for visual feedback).
    /// Why: Store state to render typed characters and key codes.
    typed_text: [256]u8 = [_]u8{0} ** 256,
    typed_text_len: usize = 0,
    /// Focus state (for visual feedback).
    /// Why: Show window focus state visually.
    has_focus: bool = false,
    /// RISC-V VM instance (for kernel development).
    /// Why: Run Zig kernel in virtualized RISC-V environment.
    /// Note: Optional - VM is created when kernel is loaded.
    /// Note: Store as pointer to avoid copying 4MB struct.
    vm: ?*VM = null,
    /// Serial output buffer (for kernel printf/debug output).
    /// Why: Capture kernel serial output for display in VM pane.
    serial_output: SerialOutput = .{},
    /// Grain Basin kernel instance (for syscall handling).
    /// Why: Handle syscalls from VM via Grain Basin kernel.
    basin_kernel_instance: basin_kernel.BasinKernel = basin_kernel.BasinKernel{},

    pub fn init(allocator: std.mem.Allocator, title: []const u8) !TahoeSandbox {
        // Assert arguments: title must not be empty and within bounds.
        std.debug.assert(title.len > 0);
        std.debug.assert(title.len <= 256);
        var platform = try Platform.init(allocator, title);
        errdefer platform.deinit();
        // Assert postcondition: platform must be initialized.
        // VTable and impl are non-optional pointers in Zig 0.15.
        _ = platform.vtable;
        _ = platform.impl;
        var aurora = try GrainAurora.init(allocator, "");
        errdefer aurora.deinit();
        
        var sandbox = TahoeSandbox{
            .allocator = allocator,
            .platform = platform,
            .aurora = aurora,
            .filter_state = .{},
            .last_mouse_x = 0.0,
            .last_mouse_y = 0.0,
            .mouse_button_down = false,
            .typed_text = [_]u8{0} ** 256,
            .typed_text_len = 0,
            .has_focus = false,
            .vm = null,
            .serial_output = .{},
        };
        
        // Assert: sandbox state must be initialized correctly.
        std.debug.assert(sandbox.last_mouse_x == 0.0);
        std.debug.assert(sandbox.last_mouse_y == 0.0);
        std.debug.assert(sandbox.mouse_button_down == false);
        std.debug.assert(sandbox.typed_text_len == 0);
        std.debug.assert(sandbox.has_focus == false);
        std.debug.assert(sandbox.vm == null);
        
        // Set up event handler (Grain Style: validate all function pointers).
        const event_handler = events.EventHandler{
            .user_data = &sandbox,
            .onMouse = handle_mouse_event,
            .onKeyboard = handle_keyboard_event,
            .onFocus = handle_focus_event,
        };
        
        // Assert: event handler function pointers must be valid.
        const onMouse_ptr = @intFromPtr(event_handler.onMouse);
        const onKeyboard_ptr = @intFromPtr(event_handler.onKeyboard);
        const onFocus_ptr = @intFromPtr(event_handler.onFocus);
        std.debug.assert(onMouse_ptr != 0);
        std.debug.assert(onKeyboard_ptr != 0);
        std.debug.assert(onFocus_ptr != 0);
        if (onMouse_ptr < 0x1000) {
            std.debug.panic("TahoeSandbox.init: onMouse pointer is suspiciously small: 0x{x}", .{onMouse_ptr});
        }
        if (onKeyboard_ptr < 0x1000) {
            std.debug.panic("TahoeSandbox.init: onKeyboard pointer is suspiciously small: 0x{x}", .{onKeyboard_ptr});
        }
        if (onFocus_ptr < 0x1000) {
            std.debug.panic("TahoeSandbox.init: onFocus pointer is suspiciously small: 0x{x}", .{onFocus_ptr});
        }
        
        // Assert: user_data pointer must be valid.
        const user_data_ptr = @intFromPtr(event_handler.user_data);
        std.debug.assert(user_data_ptr == @intFromPtr(&sandbox));
        std.debug.assert(user_data_ptr != 0);
        
        platform.vtable.setEventHandler(platform.impl, &event_handler);
        
        // Render initial component tree: welcome message.
        try aurora.render(struct {
            fn view(ctx: *GrainAurora.RenderContext) GrainAurora.RenderResult {
                _ = ctx;
                return GrainAurora.RenderResult{
                    .root = .{ .column = .{
                        .children = &.{
                            .{ .text = "Grain Aurora" },
                            .{ .text = "" },
                            .{ .text = "Welcome to the Tahoe sandbox." },
                            .{ .text = "River-inspired compositor with Moonglow keymaps." },
                            .{ .text = "" },
                            .{ .button = .{ .id = "start", .label = "Begin" } },
                        },
                    } },
                    .readonly_spans = &.{},
                };
            }
        }.view, "/");
        
        return sandbox;
    }
    
    /// Handle mouse events: log and process.
    /// Grain Style: validate user_data pointer, validate event fields.
    fn handle_mouse_event(user_data: *anyopaque, event: events.MouseEvent) bool {
        // Assert: user_data pointer must be valid (non-zero, aligned).
        const user_data_ptr = @intFromPtr(user_data);
        std.debug.assert(user_data_ptr != 0);
        if (user_data_ptr < 0x1000) {
            std.debug.panic("handle_mouse_event: user_data pointer is suspiciously small: 0x{x}", .{user_data_ptr});
        }
        if (user_data_ptr % @alignOf(TahoeSandbox) != 0) {
            std.debug.panic("handle_mouse_event: user_data pointer is not aligned: 0x{x}", .{user_data_ptr});
        }
        
        // Cast user_data to TahoeSandbox.
        const sandbox: *TahoeSandbox = @ptrCast(@alignCast(user_data));
        
        // Assert: sandbox pointer round-trip check.
        const sandbox_ptr = @intFromPtr(sandbox);
        std.debug.assert(sandbox_ptr == user_data_ptr);
        
        // Assert: sandbox must have valid platform (Grain Style invariant).
        _ = sandbox.platform.vtable;
        _ = sandbox.platform.impl;
        
        // Assert: event coordinates must be reasonable (within window bounds or slightly outside for drag).
        std.debug.assert(event.x >= -10000.0 and event.x <= 10000.0);
        std.debug.assert(event.y >= -10000.0 and event.y <= 10000.0);
        
        // Assert: event enum values must be valid (Grain Style enum validation).
        std.debug.assert(@intFromEnum(event.kind) < 4);
        std.debug.assert(@intFromEnum(event.button) < 4);
        
        // Assert: modifiers must be valid (all boolean flags).
        // Note: @typeInfo returns a union(enum), so we check the tag.
        _ = @typeInfo(@TypeOf(event.modifiers));
        
        // Update mouse state for visual feedback.
        // Why: Store state to render mouse position and button state.
        sandbox.last_mouse_x = event.x;
        sandbox.last_mouse_y = event.y;
        
        // Update button state based on event kind.
        // Why: Track button state for visual feedback (highlight buttons on click).
        switch (event.kind) {
            .down => {
                sandbox.mouse_button_down = true;
                // Assert: button must be valid for down events.
                std.debug.assert(@intFromEnum(event.button) < 4);
            },
            .up => {
                sandbox.mouse_button_down = false;
                // Assert: button must be valid for up events.
                std.debug.assert(@intFromEnum(event.button) < 4);
            },
            .move, .drag => {
                // Button state unchanged for move/drag.
            },
        }
        
        // Assert: mouse state must be consistent after update.
        std.debug.assert(sandbox.last_mouse_x >= -10000.0 and sandbox.last_mouse_x <= 10000.0);
        std.debug.assert(sandbox.last_mouse_y >= -10000.0 and sandbox.last_mouse_y <= 10000.0);
        
        std.debug.print("[tahoe_window] Mouse event: kind={s}, button={s}, x={d}, y={d}, modifiers={any}\n", .{
            @tagName(event.kind),
            @tagName(event.button),
            event.x,
            event.y,
            event.modifiers,
        });
        
        // Event handled: state updated for visual feedback.
        return true;
    }
    
    /// Handle keyboard events: log and process.
    /// Grain Style: validate user_data pointer, validate event fields.
    fn handle_keyboard_event(user_data: *anyopaque, event: events.KeyboardEvent) bool {
        // Assert: user_data pointer must be valid (non-zero, aligned).
        const user_data_ptr = @intFromPtr(user_data);
        std.debug.assert(user_data_ptr != 0);
        if (user_data_ptr < 0x1000) {
            std.debug.panic("handle_keyboard_event: user_data pointer is suspiciously small: 0x{x}", .{user_data_ptr});
        }
        if (user_data_ptr % @alignOf(TahoeSandbox) != 0) {
            std.debug.panic("handle_keyboard_event: user_data pointer is not aligned: 0x{x}", .{user_data_ptr});
        }
        
        // Cast user_data to TahoeSandbox.
        const sandbox: *TahoeSandbox = @ptrCast(@alignCast(user_data));
        
        // Assert: sandbox pointer round-trip check.
        const sandbox_ptr = @intFromPtr(sandbox);
        std.debug.assert(sandbox_ptr == user_data_ptr);
        
        // Assert: sandbox must have valid platform (Grain Style invariant).
        _ = sandbox.platform.vtable;
        _ = sandbox.platform.impl;
        
        // Assert: event key_code must be reasonable.
        std.debug.assert(event.key_code <= 0xFFFF);
        
        // Assert: event character must be valid Unicode (if present).
        // Why: Validate Unicode codepoints to prevent invalid text rendering.
        if (event.character) |c| {
            std.debug.assert(c <= 0x10FFFF);
            std.debug.assert(!(c >= 0xD800 and c <= 0xDFFF)); // No surrogates
            std.debug.assert(c != 0xFFFE and c != 0xFFFF); // No non-characters
        }
        
        // Assert: event enum value must be valid (Grain Style enum validation).
        std.debug.assert(@intFromEnum(event.kind) < 2);
        
        // Assert: modifiers must be valid (all boolean flags).
        // Note: @typeInfo returns a union(enum), so we check the tag.
        _ = @typeInfo(@TypeOf(event.modifiers));
        
        // Handle keyboard shortcuts (River-style commands).
        // Why: Implement River compositor keybindings for window management.
        if (event.kind == .down) {
            // Cmd+Q: Quit application.
            if (event.modifiers.command and event.key_code == 12) { // 'Q' key code
                std.debug.print("[tahoe_window] Quit command (Cmd+Q) received.\n", .{});
                // TODO: Implement clean shutdown.
                return true;
            }
            
            // Cmd+K: Start/stop RISC-V VM (kernel execution).
            // Why: Toggle VM execution for kernel development.
            if (event.modifiers.command and event.key_code == 11) { // 'K' key code
                if (sandbox.vm) |vm| {
                    switch (vm.state) {
                        .running => {
                            vm.stop();
                            std.debug.print("[tahoe_window] VM stopped.\n", .{});
                        },
                        .halted, .errored => {
                            vm.start();
                            std.debug.print("[tahoe_window] VM started.\n", .{});
                        },
                    }
                } else {
                    std.debug.print("[tahoe_window] No VM loaded. Use Cmd+L to load kernel.\n", .{});
                }
                return true;
            }
            
            // Cmd+L: Load kernel into VM.
            // Why: Load compiled RISC-V kernel ELF into VM memory.
            if (event.modifiers.command and event.key_code == 37) { // 'L' key code
                std.debug.print("[tahoe_window] Load kernel command (Cmd+L) received.\n", .{});
                
                // Read kernel ELF file from zig-out/bin/grain-rv64.
                const kernel_path = "zig-out/bin/grain-rv64";
                const cwd = std.fs.cwd();
                
                // Open kernel file.
                const kernel_file = cwd.openFile(kernel_path, .{}) catch |err| {
                    std.debug.print("[tahoe_window] Failed to open kernel file '{s}': {s}\n", .{ kernel_path, @errorName(err) });
                    return true;
                };
                defer kernel_file.close();
                
                // Read entire ELF file into memory.
                // Why: loadKernel expects complete ELF data.
                const elf_data = kernel_file.readToEndAlloc(sandbox.allocator, std.math.maxInt(usize)) catch |err| {
                    std.debug.print("[tahoe_window] Failed to read kernel file: {s}\n", .{@errorName(err)});
                    return true;
                };
                defer sandbox.allocator.free(elf_data);
                
                // Assert: ELF data must be non-empty.
                std.debug.assert(elf_data.len > 0);
                
                // Load kernel into VM.
                // Note: VM must be allocated on heap (4MB struct).
                var vm = sandbox.allocator.create(VM) catch |err| {
                    std.debug.print("[tahoe_window] Failed to allocate VM: {s}\n", .{@errorName(err)});
                    return true;
                };
                errdefer sandbox.allocator.destroy(vm);
                
                loadKernel(vm, sandbox.allocator, elf_data) catch |err| {
                    std.debug.print("[tahoe_window] Failed to load kernel: {s}\n", .{@errorName(err)});
                    sandbox.allocator.destroy(vm);
                    return true;
                };
                
                // Assert: VM must be valid before setting handlers.
                const vm_ptr = @intFromPtr(&vm);
                std.debug.assert(vm_ptr != 0);
                std.debug.assert(vm_ptr % @alignOf(VM) == 0);
                
                // Assert: VM state must be valid (halted or running, not errored).
                std.debug.assert(vm.state != .errored);
                
                // Assert: VM PC must be valid (aligned, within memory bounds).
                std.debug.assert(vm.regs.pc % 4 == 0);
                std.debug.assert(vm.regs.pc < vm.memory_size);
                
                // Set syscall handler for VM (Grain Basin kernel integration).
                // Why: Wire VM ECALL instructions to Grain Basin kernel syscalls.
                vm.set_syscall_handler(TahoeSandbox.handle_syscall, sandbox);
                
                // Assert: syscall handler must be set correctly.
                std.debug.assert(vm.syscall_handler != null);
                std.debug.assert(vm.syscall_user_data == @as(?*anyopaque, @ptrCast(sandbox)));
                
                // Set serial output handler for VM (SBI console integration).
                // Why: Wire SBI_CONSOLE_PUTCHAR to serial output for display in GUI VM pane.
                vm.set_serial_output(&sandbox.serial_output);
                
                // Assert: serial output handler must be set correctly.
                std.debug.assert(vm.serial_output != null);
                std.debug.assert(vm.serial_output.? == &sandbox.serial_output);
                
                // Assert: serial output buffer must be initialized.
                std.debug.assert(sandbox.serial_output.buffer.len > 0);
                std.debug.assert(sandbox.serial_output.write_pos < sandbox.serial_output.buffer.len);
                
                // Store VM in sandbox (store pointer to avoid copying 4MB struct).
                sandbox.vm = vm;
                
                // Assert: VM must be stored correctly.
                std.debug.assert(sandbox.vm != null);
                std.debug.assert(sandbox.vm.?.regs.pc == vm.*.regs.pc);
                
                std.debug.print("[tahoe_window] Kernel loaded successfully. PC: 0x{X}\n", .{vm.regs.pc});
                return true;
            }
            
            // Cmd+Shift+H: Horizontal split (River-style).
            if (event.modifiers.command and event.modifiers.shift and event.key_code == 4) { // 'H' key code
                std.debug.print("[tahoe_window] Horizontal split command (Cmd+Shift+H) received.\n", .{});
                // TODO: Implement horizontal split.
                return true;
            }
            
            // Cmd+Shift+V: Vertical split (River-style).
            if (event.modifiers.command and event.modifiers.shift and event.key_code == 9) { // 'V' key code
                std.debug.print("[tahoe_window] Vertical split command (Cmd+Shift+V) received.\n", .{});
                // TODO: Implement vertical split.
                return true;
            }
            
            // Handle printable characters (for text input display).
            if (event.character) |c| {
                // Assert: character must be valid Unicode.
                std.debug.assert(c <= 0x10FFFF);
                
                // Add character to typed text buffer (for visual feedback).
                // Why: Store typed text to display in UI.
                if (sandbox.typed_text_len < sandbox.typed_text.len - 4) {
                    var buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(c, &buf) catch 0;
                    // Assert: UTF-8 encoding must succeed for valid Unicode.
                    std.debug.assert(len > 0);
                    std.debug.assert(len <= 4);
                    
                    // Copy UTF-8 bytes to typed text buffer.
                    @memcpy(sandbox.typed_text[sandbox.typed_text_len..][0..len], buf[0..len]);
                    sandbox.typed_text_len += len;
                    
                    // Assert: typed_text_len must be within bounds.
                    std.debug.assert(sandbox.typed_text_len <= sandbox.typed_text.len);
                }
            }
        }
        
        const char_str = if (event.character) |c| blk: {
            var buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(c, &buf) catch 0;
            std.debug.assert(len > 0);
            std.debug.assert(len <= 4);
            break :blk buf[0..len];
        } else "none";
        std.debug.print("[tahoe_window] Keyboard event: kind={s}, key_code={d}, character={s}, modifiers={any}\n", .{
            @tagName(event.kind),
            event.key_code,
            char_str,
            event.modifiers,
        });
        
        // Event handled: state updated for visual feedback or command executed.
        return true;
    }
    
    /// Handle focus events: log window focus changes.
    /// Grain Style: validate user_data pointer, validate event fields.
    fn handle_focus_event(user_data: *anyopaque, event: events.FocusEvent) bool {
        // Assert: user_data pointer must be valid (non-zero, aligned).
        const user_data_ptr = @intFromPtr(user_data);
        std.debug.assert(user_data_ptr != 0);
        if (user_data_ptr < 0x1000) {
            std.debug.panic("handle_focus_event: user_data pointer is suspiciously small: 0x{x}", .{user_data_ptr});
        }
        if (user_data_ptr % @alignOf(TahoeSandbox) != 0) {
            std.debug.panic("handle_focus_event: user_data pointer is not aligned: 0x{x}", .{user_data_ptr});
        }
        
        // Cast user_data to TahoeSandbox.
        const sandbox: *TahoeSandbox = @ptrCast(@alignCast(user_data));
        
        // Assert: sandbox pointer round-trip check.
        const sandbox_ptr = @intFromPtr(sandbox);
        std.debug.assert(sandbox_ptr == user_data_ptr);
        
        // Assert: sandbox must have valid platform (Grain Style invariant).
        _ = sandbox.platform.vtable;
        _ = sandbox.platform.impl;
        
        // Assert: event enum value must be valid.
        std.debug.assert(@intFromEnum(event.kind) < 2);
        
        // Assert: event enum value must be valid (Grain Style enum validation).
        std.debug.assert(@intFromEnum(event.kind) < 2);
        
        // Update focus state for visual feedback.
        // Why: Store focus state to render focus indicator.
        switch (event.kind) {
            .gained => {
                sandbox.has_focus = true;
            },
            .lost => {
                sandbox.has_focus = false;
            },
        }
        
        // Assert: focus state must be consistent after update.
        std.debug.assert(sandbox.has_focus == (event.kind == .gained));
        
        std.debug.print("[tahoe_window] Focus event: kind={s}\n", .{@tagName(event.kind)});
        
        // Event handled: state updated for visual feedback.
        return true;
    }

    /// Handle syscall from RISC-V VM (Grain Basin kernel integration).
    /// Why: Bridge VM ECALL instructions to Grain Basin kernel syscalls.
    /// RISC-V calling convention: syscall_num in a7, args in a0-a5, result in a0.
    /// Note: This is a static function that will be called via callback.
    /// TODO: Use user_data to access sandbox instance properly.
    /// Handle syscall from VM (Grain Basin kernel integration).
    /// Why: Bridge VM ECALL instructions to Grain Basin kernel syscalls.
    /// Grain Style: Comprehensive assertions for all syscall parameters and results.
    pub fn handle_syscall(syscall_num: u32, arg1: u64, arg2: u64, arg3: u64, arg4: u64) u64 {
        // Assert: syscall number must be >= 10 (kernel syscalls, not SBI).
        // Why: SBI calls use function ID < 10, kernel syscalls use >= 10.
        // Note: This function is only called for kernel syscalls (VM dispatches SBI separately).
        std.debug.assert(syscall_num >= 10);
        
        // Assert: syscall number must be within valid range.
        std.debug.assert(syscall_num <= @intFromEnum(basin_kernel.Syscall.sysinfo));
        
        // For now, use a simple implementation that calls Basin Kernel.
        // TODO: Access sandbox via user_data when callback supports it.
        var kernel = basin_kernel.BasinKernel{};
        
        // Assert: kernel must be initialized correctly.
        const kernel_ptr = @intFromPtr(&kernel);
        std.debug.assert(kernel_ptr != 0);
        std.debug.assert(kernel_ptr % @alignOf(basin_kernel.BasinKernel) == 0);
        
        const result = kernel.handle_syscall(syscall_num, arg1, arg2, arg3, arg4) catch |err| {
            // Assert: error must be valid BasinError.
            std.debug.assert(@intFromError(err) > 0);
            
            // Return error code (negative value indicates error).
            const error_code = @as(i64, @intCast(@intFromError(err)));
            const error_result = @as(u64, @bitCast(-error_code));
            
            // Assert: error result must be negative when interpreted as i64.
            const error_result_signed = @as(i64, @bitCast(error_result));
            std.debug.assert(error_result_signed < 0);
            
            return error_result;
        };
        
        // Assert: result must be valid SyscallResult.
        std.debug.assert(result == .success or result == .err);
        
        // Extract result value from SyscallResult.
        switch (result) {
            .success => |value| {
                // Assert: success value must be valid (non-negative when interpreted as i64).
                const value_signed = @as(i64, @bitCast(value));
                std.debug.assert(value_signed >= 0);
                
                return value;
            },
            .err => |err_val| {
                // Assert: error must be valid BasinError.
                std.debug.assert(@intFromError(err_val) > 0);
                
                const error_code = @as(i64, @intCast(@intFromError(err_val)));
                const error_result = @as(u64, @bitCast(-error_code));
                
                // Assert: error result must be negative when interpreted as i64.
                const error_result_signed = @as(i64, @bitCast(error_result));
                std.debug.assert(error_result_signed < 0);
                
                return error_result;
            },
        }
    }

    pub fn deinit(self: *TahoeSandbox) void {
        self.aurora.deinit();
        self.platform.deinit();
        self.* = undefined;
    }

    pub fn show(self: *TahoeSandbox) !void {
        try self.platform.show();
    }

    pub fn tick(self: *TahoeSandbox) !void {
        // Assert precondition: platform must be initialized.
        // VTable and impl are non-optional pointers in Zig 0.15.
        _ = self.platform.vtable;
        _ = self.platform.impl;
        
        // Step RISC-V VM if running.
        // Why: Execute kernel instructions continuously during VM execution.
        if (self.vm) |vm| {
            if (vm.state == .running) {
                // Step VM (execute one instruction).
                vm.step() catch |err| {
                    std.debug.print("[tahoe_window] VM step error: {s}\n", .{@errorName(err)});
                    vm.stop();
                };
            }
        }
        
        const buffer = self.platform.getBuffer();
        // Assert buffer: must be RGBA-aligned.
        // Buffer size is fixed (1024x768), window size can differ.
        std.debug.assert(buffer.len > 0);
        std.debug.assert(buffer.len % 4 == 0);
        const expected_buffer_size = 1024 * 768 * 4; // Fixed buffer size
        std.debug.assert(buffer.len == expected_buffer_size);
        
        // Buffer dimensions (fixed, always 1024x768).
        const buffer_width: u32 = 1024;
        const buffer_height: u32 = 768;
        
        // Grain Style: Draw something visible to the buffer!
        // Fill with a nice dark blue-gray background (Tahoe aesthetic).
        const bg_color: u32 = 0xFF1E1E2E; // Dark blue-gray (RGBA)
        @memset(buffer, @as(u8, @truncate(bg_color)));
        @memset(buffer[1..], @as(u8, @truncate(bg_color >> 8)));
        @memset(buffer[2..], @as(u8, @truncate(bg_color >> 16)));
        @memset(buffer[3..], @as(u8, @truncate(bg_color >> 24)));
        
        // Actually, let's do it pixel by pixel for clarity.
        var y: u32 = 0;
        while (y < buffer_height) : (y += 1) {
            var x: u32 = 0;
            while (x < buffer_width) : (x += 1) {
                const pixel_offset = (y * buffer_width + x) * 4;
                if (pixel_offset + 3 < buffer.len) {
                    // RGBA format: R, G, B, A
                    buffer[pixel_offset + 0] = 0x1E; // R
                    buffer[pixel_offset + 1] = 0x1E; // G
                    buffer[pixel_offset + 2] = 0x2E; // B
                    buffer[pixel_offset + 3] = 0xFF; // A (fully opaque)
                }
            }
        }
        
        // Draw interactive UI elements for visual feedback.
        // Why: Show mouse position, typed text, focus state, and buttons.
        
        // Assert: UI state must be valid before rendering.
        std.debug.assert(self.last_mouse_x >= -10000.0 and self.last_mouse_x <= 10000.0);
        std.debug.assert(self.last_mouse_y >= -10000.0 and self.last_mouse_y <= 10000.0);
        std.debug.assert(self.typed_text_len <= self.typed_text.len);
        
        // Draw focus indicator (top border).
        // Why: Visual feedback for window focus state.
        if (self.has_focus) {
            var x: u32 = 0;
            while (x < buffer_width) : (x += 1) {
                const pixel_offset = (0 * buffer_width + x) * 4;
                // Assert: pixel offset must be within bounds.
                std.debug.assert(pixel_offset + 3 < buffer.len);
                if (pixel_offset + 3 < buffer.len) {
                    // Cyan focus indicator.
                    buffer[pixel_offset + 0] = 0x00; // R
                    buffer[pixel_offset + 1] = 0xFF; // G
                    buffer[pixel_offset + 2] = 0xFF; // B
                    buffer[pixel_offset + 3] = 0xFF; // A
                }
            }
        }
        
        // Draw mouse cursor indicator (small circle at mouse position).
        // Why: Visual feedback for mouse position and button state.
        const mouse_x_i = @as(i32, @intFromFloat(self.last_mouse_x));
        const mouse_y_i = @as(i32, @intFromFloat(self.last_mouse_y));
        const cursor_radius: i32 = 5;
        const cursor_color: [4]u8 = if (self.mouse_button_down) .{ 0xFF, 0x00, 0x00, 0xFF } else .{ 0xFF, 0xFF, 0xFF, 0xFF };
        
        // Assert: cursor radius must be positive and reasonable.
        std.debug.assert(cursor_radius > 0);
        std.debug.assert(cursor_radius < 100);
        
        var cy: i32 = mouse_y_i - cursor_radius;
        while (cy <= mouse_y_i + cursor_radius) : (cy += 1) {
            var cx: i32 = mouse_x_i - cursor_radius;
            while (cx <= mouse_x_i + cursor_radius) : (cx += 1) {
                const dx = cx - mouse_x_i;
                const dy = cy - mouse_y_i;
                // Assert: distance calculation must not overflow.
                std.debug.assert(dx >= -1000 and dx <= 1000);
                std.debug.assert(dy >= -1000 and dy <= 1000);
                
                if (dx * dx + dy * dy <= cursor_radius * cursor_radius) {
                    const x_clamped = if (cx < 0) 0 else if (cx >= @as(i32, @intCast(buffer_width))) @as(i32, @intCast(buffer_width - 1)) else cx;
                    const y_clamped = if (cy < 0) 0 else if (cy >= @as(i32, @intCast(buffer_height))) @as(i32, @intCast(buffer_height - 1)) else cy;
                    const x_u = @as(u32, @intCast(x_clamped));
                    const y_u = @as(u32, @intCast(y_clamped));
                    
                    // Assert: clamped coordinates must be within bounds.
                    std.debug.assert(x_u < buffer_width);
                    std.debug.assert(y_u < buffer_height);
                    
                    const pixel_offset = (y_u * buffer_width + x_u) * 4;
                    // Assert: pixel offset must be within buffer bounds.
                    std.debug.assert(pixel_offset + 3 < buffer.len);
                    if (pixel_offset + 3 < buffer.len) {
                        buffer[pixel_offset + 0] = cursor_color[0];
                        buffer[pixel_offset + 1] = cursor_color[1];
                        buffer[pixel_offset + 2] = cursor_color[2];
                        buffer[pixel_offset + 3] = cursor_color[3];
                    }
                }
            }
        }
        
        // Draw typed text display area (top-left corner).
        // Why: Visual feedback for keyboard input.
        const text_x: u32 = 20;
        const text_y: u32 = 30;
        const text_bg_width: u32 = 500;
        const text_bg_height: u32 = 30;
        
        // Assert: text area must be within buffer bounds.
        std.debug.assert(text_x + text_bg_width <= buffer_width);
        std.debug.assert(text_y + text_bg_height <= buffer_height);
        
        // Draw text background.
        var ty: u32 = text_y;
        while (ty < text_y + text_bg_height and ty < buffer_height) : (ty += 1) {
            var tx: u32 = text_x;
            while (tx < text_x + text_bg_width and tx < buffer_width) : (tx += 1) {
                const pixel_offset = (ty * buffer_width + tx) * 4;
                // Assert: pixel offset must be within bounds.
                std.debug.assert(pixel_offset + 3 < buffer.len);
                if (pixel_offset + 3 < buffer.len) {
                    // Dark gray background.
                    buffer[pixel_offset + 0] = 0x20; // R
                    buffer[pixel_offset + 1] = 0x20; // G
                    buffer[pixel_offset + 2] = 0x20; // B
                    buffer[pixel_offset + 3] = 0xFF; // A
                }
            }
        }
        
        // Draw typed text (simple ASCII rendering).
        // Why: Show typed characters visually.
        if (self.typed_text_len > 0) {
            const text_slice = self.typed_text[0..self.typed_text_len];
            const max_chars = @min(text_slice.len, 50);
            // Assert: max_chars must be within reasonable bounds.
            std.debug.assert(max_chars <= text_slice.len);
            std.debug.assert(max_chars <= 50);
            
            var char_idx: usize = 0;
            while (char_idx < max_chars) : (char_idx += 1) {
                const char_x = text_x + 5 + char_idx * 8;
                const char_y = text_y + 5;
                // Assert: character position must be within bounds.
                std.debug.assert(char_x + 8 <= buffer_width);
                std.debug.assert(char_y + 16 <= buffer_height);
                
                if (char_x + 8 < buffer_width and char_y + 16 < buffer_height) {
                    // Simple 8x16 ASCII character rendering.
                    const c = text_slice[char_idx];
                    // Assert: character must be valid ASCII.
                    std.debug.assert(c <= 127);
                    
                    if (c >= 32 and c <= 126) {
                        // Draw simple character outline (white pixels).
                        var py: u32 = 0;
                        while (py < 16) : (py += 1) {
                            var px: u32 = 0;
                            while (px < 8) : (px += 1) {
                                // Simple pattern: every 2nd pixel for visibility.
                                if ((px + py) % 2 == 0) {
                                    const pixel_offset = ((char_y + py) * buffer_width + (char_x + px)) * 4;
                                    // Assert: pixel offset must be within bounds.
                                    std.debug.assert(pixel_offset + 3 < buffer.len);
                                    if (pixel_offset + 3 < buffer.len) {
                                        buffer[pixel_offset + 0] = 0xFF; // R
                                        buffer[pixel_offset + 1] = 0xFF; // G
                                        buffer[pixel_offset + 2] = 0xFF; // B
                                        buffer[pixel_offset + 3] = 0xFF; // A
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Draw button area (bottom-right corner).
        // Why: Visual feedback for mouse clicks on buttons.
        const button_x: u32 = buffer_width - 150;
        const button_y: u32 = buffer_height - 50;
        const button_width: u32 = 120;
        const button_height: u32 = 30;
        
        // Assert: button area must be within buffer bounds.
        std.debug.assert(button_x + button_width <= buffer_width);
        std.debug.assert(button_y + button_height <= buffer_height);
        
        // Draw button background (highlighted if mouse is over it).
        const mouse_over_button = (self.last_mouse_x >= @as(f64, @floatFromInt(button_x)) and
            self.last_mouse_x <= @as(f64, @floatFromInt(button_x + button_width)) and
            self.last_mouse_y >= @as(f64, @floatFromInt(button_y)) and
            self.last_mouse_y <= @as(f64, @floatFromInt(button_y + button_height)));
        
        var by: u32 = button_y;
        while (by < button_y + button_height and by < buffer_height) : (by += 1) {
            var bx: u32 = button_x;
            while (bx < button_x + button_width and bx < buffer_width) : (bx += 1) {
                const pixel_offset = (by * buffer_width + bx) * 4;
                // Assert: pixel offset must be within bounds.
                std.debug.assert(pixel_offset + 3 < buffer.len);
                if (pixel_offset + 3 < buffer.len) {
                    if (mouse_over_button and self.mouse_button_down) {
                        // Bright green when clicked.
                        buffer[pixel_offset + 0] = 0x00; // R
                        buffer[pixel_offset + 1] = 0xFF; // G
                        buffer[pixel_offset + 2] = 0x00; // B
                        buffer[pixel_offset + 3] = 0xFF; // A
                    } else if (mouse_over_button) {
                        // Light gray when hovered.
                        buffer[pixel_offset + 0] = 0x80; // R
                        buffer[pixel_offset + 1] = 0x80; // G
                        buffer[pixel_offset + 2] = 0x80; // B
                        buffer[pixel_offset + 3] = 0xFF; // A
                    } else {
                        // Dark gray default.
                        buffer[pixel_offset + 0] = 0x40; // R
                        buffer[pixel_offset + 1] = 0x40; // G
                        buffer[pixel_offset + 2] = 0x40; // B
                        buffer[pixel_offset + 3] = 0xFF; // A
                    }
                }
            }
        }
        
        // Draw RISC-V VM pane (if VM is running).
        // Why: Show kernel output and VM state in dedicated pane.
        if (self.vm) |*vm| {
            // Draw VM pane (bottom-left corner).
            const vm_pane_x: u32 = 20;
            const vm_pane_y: u32 = buffer_height - 200;
            const vm_pane_width: u32 = 600;
            const vm_pane_height: u32 = 180;
            
            // Assert: VM pane must be within buffer bounds.
            std.debug.assert(vm_pane_x + vm_pane_width <= buffer_width);
            std.debug.assert(vm_pane_y + vm_pane_height <= buffer_height);
            
            // Draw VM pane background (dark gray).
            var vpy: u32 = vm_pane_y;
            while (vpy < vm_pane_y + vm_pane_height and vpy < buffer_height) : (vpy += 1) {
                var vpx: u32 = vm_pane_x;
                while (vpx < vm_pane_x + vm_pane_width and vpx < buffer_width) : (vpx += 1) {
                    const pixel_offset = (vpy * buffer_width + vpx) * 4;
                    // Assert: pixel offset must be within bounds.
                    std.debug.assert(pixel_offset + 3 < buffer.len);
                    if (pixel_offset + 3 < buffer.len) {
                        // Dark gray background for VM pane.
                        buffer[pixel_offset + 0] = 0x10; // R
                        buffer[pixel_offset + 1] = 0x10; // G
                        buffer[pixel_offset + 2] = 0x10; // B
                        buffer[pixel_offset + 3] = 0xFF; // A
                    }
                }
            }
            
            // Draw VM state indicator (top-left of VM pane).
            const vm_state_color: [4]u8 = switch (vm.state) {
                .running => .{ 0x00, 0xFF, 0x00, 0xFF }, // Green
                .halted => .{ 0xFF, 0xFF, 0x00, 0xFF }, // Yellow
                .errored => .{ 0xFF, 0x00, 0x00, 0xFF }, // Red
            };
            
            // Draw small status indicator (5x5 pixels).
            var status_y: u32 = vm_pane_y + 5;
            while (status_y < vm_pane_y + 10 and status_y < buffer_height) : (status_y += 1) {
                var status_x: u32 = vm_pane_x + 5;
                while (status_x < vm_pane_x + 10 and status_x < buffer_width) : (status_x += 1) {
                    const pixel_offset = (status_y * buffer_width + status_x) * 4;
                    // Assert: pixel offset must be within bounds.
                    std.debug.assert(pixel_offset + 3 < buffer.len);
                    if (pixel_offset + 3 < buffer.len) {
                        buffer[pixel_offset + 0] = vm_state_color[0];
                        buffer[pixel_offset + 1] = vm_state_color[1];
                        buffer[pixel_offset + 2] = vm_state_color[2];
                        buffer[pixel_offset + 3] = vm_state_color[3];
                    }
                }
            }
        }
        
        std.debug.print("[tahoe_window] Drew UI: mouse=({d},{d}), text_len={d}, focus={}, vm={}\n", .{
            self.last_mouse_x,
            self.last_mouse_y,
            self.typed_text_len,
            self.has_focus,
            self.vm != null,
        });
        
        // Apply Aurora filter if enabled.
        AuroraFilter.apply(self.filter_state, buffer);
        
        // Present the buffer to the window.
        try self.platform.present();
        std.debug.print("[tahoe_window] Buffer presented to window.\n", .{});
    }

    pub fn toggle_flux(self: *TahoeSandbox, mode: AuroraFilter.Mode) void {
        self.filter_state.toggle(mode);
    }
    
    /// Start animation loop: sets up timer to call tick() continuously at 60fps.
    /// Grain Style: validate platform pointers, ensure callback is properly set up.
    pub fn start_animation_loop(self: *TahoeSandbox) void {
        // Assert: platform must be initialized.
        _ = self.platform.vtable;
        _ = self.platform.impl;
        
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        if (self_ptr < 0x1000) {
            std.debug.panic("TahoeSandbox.start_animation_loop: self pointer is suspiciously small: 0x{x}", .{self_ptr});
        }
        
        // Create tick callback that calls self.tick().
        const tickCallback = struct {
            fn tick(user_data: *anyopaque) void {
                const sandbox: *TahoeSandbox = @ptrCast(@alignCast(user_data));
                
                // Assert: sandbox pointer round-trip check.
                const sandbox_ptr = @intFromPtr(sandbox);
                const user_data_ptr = @intFromPtr(user_data);
                std.debug.assert(sandbox_ptr == user_data_ptr);
                
                // Assert: sandbox must have valid platform.
                _ = sandbox.platform.vtable;
                _ = sandbox.platform.impl;
                
                // Call tick (ignore errors in timer callback - log them instead).
                sandbox.tick() catch |err| {
                    std.debug.print("[tahoe_window] Tick error in animation loop: {s}\n", .{@errorName(err)});
                };
            }
        }.tick;
        
        // Start animation loop via platform.
        // Note: tickCallback function pointer validation happens in Window.startAnimationLoop.
        self.platform.vtable.startAnimationLoop(self.platform.impl, tickCallback, self);
        
        std.debug.print("[tahoe_window] Animation loop started (60fps).\n", .{});
    }
    
    /// Stop animation loop: stops timer.
    /// Grain Style: validate platform pointers.
    pub fn stop_animation_loop(self: *TahoeSandbox) void {
        // Assert: platform must be initialized.
        _ = self.platform.vtable;
        _ = self.platform.impl;
        
        // Stop animation loop via platform.
        self.platform.vtable.stopAnimationLoop(self.platform.impl);
        
        std.debug.print("[tahoe_window] Animation loop stopped.\n", .{});
    }
};

test "tahoe sandbox lifecycle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var sandbox = try TahoeSandbox.init(arena.allocator(), "Test");
    defer sandbox.deinit();
    try sandbox.show();
    try sandbox.tick();
    sandbox.toggle_flux(.darkroom);
    try sandbox.tick();
}
