//! Grain Basin Signal Handling
//! Why: Process communication and control via signals (SIGTERM, SIGKILL, etc.).
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Signal number (POSIX-compatible subset).
/// Why: Explicit signal types for type safety.
pub const Signal = enum(u32) {
    /// Hangup (terminal closed).
    sighup = 1,
    /// Interrupt (Ctrl+C).
    sigint = 2,
    /// Quit (Ctrl+\).
    sigquit = 3,
    /// Illegal instruction.
    sigill = 4,
    /// Abort.
    sigabrt = 6,
    /// Floating point exception.
    sigfpe = 8,
    /// Kill (cannot be caught or ignored).
    sigkill = 9,
    /// User-defined signal 1.
    sigusr1 = 10,
    /// Segmentation fault.
    sigsegv = 11,
    /// User-defined signal 2.
    sigusr2 = 12,
    /// Broken pipe.
    sigpipe = 13,
    /// Alarm clock.
    sigalrm = 14,
    /// Termination request.
    sigterm = 15,
    /// Child process terminated.
    sigchld = 17,
    /// Continue (resume execution).
    sigcont = 18,
    /// Stop (suspend execution).
    sigstop = 19,
    /// Terminal stop (Ctrl+Z).
    sigtstp = 20,
};

/// Signal handler function type.
/// Why: Type-safe signal handler registration.
/// Contract: Handler must be fast, non-blocking, and return void.
pub const SignalHandler = *const fn (signal: Signal, context: ?*anyopaque) void;

/// Signal action (handler + flags).
/// Why: POSIX-compatible signal action structure.
pub const SignalAction = struct {
    /// Signal handler function (optional).
    /// Why: Allow process to handle signals.
    handler: ?SignalHandler = null,
    /// Signal context (optional data for handler).
    /// Why: Allow handlers to access process state.
    context: ?*anyopaque = null,
    /// Signal mask (signals to block during handler).
    /// Why: Prevent signal reentrancy.
    mask: u32 = 0,
    /// Flags (future: SA_RESTART, etc.).
    /// Why: Signal behavior flags.
    flags: u32 = 0,
};

/// Signal table for a process.
/// Why: Track signal handlers and pending signals per process.
/// Grain Style: Static allocation, bounded signals.
pub const SignalTable = struct {
    /// Signal actions (one per signal type).
    /// Why: Store handler for each signal.
    actions: [32]SignalAction = [_]SignalAction{SignalAction{}} ** 32,
    /// Pending signals bitmap (32 signals max).
    /// Why: Track signals waiting to be delivered.
    pending: u32 = 0,
    /// Blocked signals bitmap (32 signals max).
    /// Why: Block signals from being delivered.
    blocked: u32 = 0,
    /// Initialized flag.
    /// Why: Track initialization state.
    initialized: bool = false,

    /// Initialize signal table.
    /// Why: Set up signal handling for a process.
    /// Contract: Must be called before use, sets initialized flag.
    pub fn init() SignalTable {
        var table = SignalTable{
            .actions = [_]SignalAction{SignalAction{}} ** 32,
            .pending = 0,
            .blocked = 0,
            .initialized = false,
        };
        
        // Assert: Table must be uninitialized (precondition).
        Debug.kassert(!table.initialized, "Table already initialized", .{});
        
        table.initialized = true;
        
        // Assert: Table must be initialized (postcondition).
        Debug.kassert(table.initialized, "Table not initialized", .{});
        Debug.kassert(table.pending == 0, "Pending signals not zero", .{});
        Debug.kassert(table.blocked == 0, "Blocked signals not zero", .{});
        
        return table;
    }

    /// Register signal handler.
    /// Why: Allow process to handle specific signals.
    /// Contract: Signal number must be valid (< 32), handler can be null (default action).
    pub fn register_handler(
        self: *SignalTable,
        signal: Signal,
        action: SignalAction,
    ) void {
        // Assert: Table must be initialized (precondition).
        Debug.kassert(self.initialized, "Table not initialized", .{});
        
        const signal_num = @intFromEnum(signal);
        
        // Assert: Signal number must be valid (precondition).
        Debug.kassert(signal_num < 32, "Signal number out of range", .{});
        
        // SIGKILL cannot be caught or ignored.
        if (signal == .sigkill) {
            return;
        }
        
        self.actions[signal_num] = action;
        
        // Assert: Handler must be registered (postcondition).
        Debug.kassert(self.actions[signal_num].handler == action.handler, "Handler not set", .{});
    }

    /// Send signal to process.
    /// Why: Deliver signal to process (from kernel or other process).
    /// Contract: Signal number must be valid (< 32).
    pub fn send_signal(self: *SignalTable, signal: Signal) void {
        // Assert: Table must be initialized (precondition).
        Debug.kassert(self.initialized, "Table not initialized", .{});
        
        const signal_num = @intFromEnum(signal);
        
        // Assert: Signal number must be valid (precondition).
        Debug.kassert(signal_num < 32, "Signal number out of range", .{});
        
        // SIGKILL always succeeds (cannot be blocked).
        if (signal == .sigkill) {
            self.pending |= (@as(u32, 1) << @as(u5, @truncate(signal_num)));
            return;
        }
        
        // Check if signal is blocked.
        if (self.blocked & (@as(u32, 1) << @as(u5, @truncate(signal_num))) != 0) {
            return;
        }
        
        // Mark signal as pending.
        self.pending |= (@as(u32, 1) << @as(u5, @truncate(signal_num)));
        
        // Assert: Signal must be pending (postcondition).
        Debug.kassert((self.pending & (@as(u32, 1) << @as(u5, @truncate(signal_num)))) != 0, "Signal not pending", .{});
    }

    /// Block signal.
    /// Why: Prevent signal from being delivered.
    /// Contract: Signal number must be valid (< 32).
    pub fn block_signal(self: *SignalTable, signal: Signal) void {
        // Assert: Table must be initialized (precondition).
        Debug.kassert(self.initialized, "Table not initialized", .{});
        
        const signal_num = @intFromEnum(signal);
        
        // Assert: Signal number must be valid (precondition).
        Debug.kassert(signal_num < 32, "Signal number out of range", .{});
        
        // SIGKILL cannot be blocked.
        if (signal == .sigkill) {
            return;
        }
        
        self.blocked |= (@as(u32, 1) << @as(u5, @truncate(signal_num)));
        
        // Assert: Signal must be blocked (postcondition).
        Debug.kassert((self.blocked & (@as(u32, 1) << @as(u5, @truncate(signal_num)))) != 0, "Signal not blocked", .{});
    }

    /// Unblock signal.
    /// Why: Allow signal to be delivered.
    /// Contract: Signal number must be valid (< 32).
    pub fn unblock_signal(self: *SignalTable, signal: Signal) void {
        // Assert: Table must be initialized (precondition).
        Debug.kassert(self.initialized, "Table not initialized", .{});
        
        const signal_num = @intFromEnum(signal);
        
        // Assert: Signal number must be valid (precondition).
        Debug.kassert(signal_num < 32, "Signal number out of range", .{});
        
        self.blocked &= ~(@as(u32, 1) << @as(u5, @truncate(signal_num)));
        
        // Assert: Signal must be unblocked (postcondition).
        Debug.kassert((self.blocked & (@as(u32, 1) << @as(u5, @truncate(signal_num)))) == 0, "Signal still blocked", .{});
    }

    /// Check if signal is pending.
    /// Why: Query signal delivery status.
    /// Contract: Signal number must be valid (< 32).
    pub fn is_pending(self: *const SignalTable, signal: Signal) bool {
        // Assert: Table must be initialized (precondition).
        Debug.kassert(self.initialized, "Table not initialized", .{});
        
        const signal_num = @intFromEnum(signal);
        
        // Assert: Signal number must be valid (precondition).
        Debug.kassert(signal_num < 32, "Signal number out of range", .{});
        
        return (self.pending & (@as(u32, 1) << @as(u5, @truncate(signal_num)))) != 0;
    }

    /// Process pending signals.
    /// Why: Deliver pending signals to handlers.
    /// Contract: Must be called from process context, handlers must be fast.
    pub fn process_pending(self: *SignalTable, context: ?*anyopaque) void {
        // Assert: Table must be initialized (precondition).
        Debug.kassert(self.initialized, "Table not initialized", .{});
        
        var signal_num: u32 = 0;
        while (signal_num < 32) : (signal_num += 1) {
            const signal_mask = @as(u32, 1) << @as(u5, @truncate(signal_num));
            
            // Check if signal is pending and not blocked.
            if ((self.pending & signal_mask) != 0 and (self.blocked & signal_mask) == 0) {
                const signal = @as(Signal, @enumFromInt(signal_num));
                const action = self.actions[signal_num];
                
                // Clear pending flag.
                self.pending &= ~signal_mask;
                
                // Call handler if registered.
                if (action.handler) |handler| {
                    handler(signal, action.context orelse context);
                }
            }
        }
        
        // Assert: All unblocked signals processed (postcondition).
        // Note: Some signals may remain pending if blocked.
    }
};

