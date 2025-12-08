pub const EntryPoints = struct {
    start: []const u8 = "_start",
    panic_handler: []const u8 = "grain_panic",
    debug_writer: []const u8 = "grain_debug_write",
};

pub const CallingConvention = struct {
    register_order: []const u8 = "a0..a7",
    stack_alignment: u8 = 16,
};

pub const ABI = struct {
    entry: EntryPoints = .{},
    cc: CallingConvention = .{},
};

pub const current = ABI{};
