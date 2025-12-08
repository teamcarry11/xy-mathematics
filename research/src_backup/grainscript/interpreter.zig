const std = @import("std");
const Parser = @import("parser.zig").Parser;

/// Grainscript Interpreter: Executes AST nodes.
/// ~<~ Glow Airbend: explicit value types, bounded runtime state.
/// ~~~~ Glow Waterbend: deterministic evaluation, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const Interpreter = struct {
    // Bounded: Max 1,000 variables (explicit limit)
    pub const MAX_VARIABLES: u32 = 1_000;

    // Bounded: Max 256 functions (explicit limit)
    pub const MAX_FUNCTIONS: u32 = 256;

    // Bounded: Max 1,024 call stack depth (explicit limit)
    pub const MAX_CALL_STACK: u32 = 1_024;

    // Bounded: Max 256 arguments per function call (explicit limit)
    pub const MAX_CALL_ARGS: u32 = 256;

    // Bounded: Max 4,096 bytes per string value (explicit limit)
    pub const MAX_STRING_LEN: u32 = 4_096;

    /// Runtime value type enumeration.
    pub const ValueType = enum(u8) {
        integer, // i64
        float, // f64
        string, // []const u8 (bounded)
        boolean, // bool
        null, // null value
    };

    /// Runtime value (explicit union for GrainStyle compliance).
    pub const Value = union(ValueType) {
        integer: i64,
        float: f64,
        string: []const u8, // Must be bounded (MAX_STRING_LEN)
        boolean: bool,
        null: void,

        /// Create integer value.
        pub fn from_integer(val: i64) Value {
            return Value{ .integer = val };
        }

        /// Create float value.
        pub fn from_float(val: f64) Value {
            return Value{ .float = val };
        }

        /// Create string value (bounded).
        pub fn from_string(allocator: std.mem.Allocator, str: []const u8) Error!Value {
            // Assert: String length must be bounded
            if (str.len > MAX_STRING_LEN) {
                return Error.string_too_long;
            }

            // Allocate bounded string
            const string_copy = allocator.dupe(u8, str) catch return Error.OutOfMemory;
            errdefer allocator.free(string_copy);

            return Value{ .string = string_copy };
        }

        /// Create boolean value.
        pub fn from_boolean(val: bool) Value {
            return Value{ .boolean = val };
        }

        /// Create null value.
        pub fn from_null() Value {
            return Value{ .null = {} };
        }

        /// Convert value to boolean (for truthiness).
        pub fn to_boolean(self: Value) bool {
            return switch (self) {
                .integer => |v| v != 0,
                .float => |v| v != 0.0,
                .string => |v| v.len > 0,
                .boolean => |v| v,
                .null => false,
            };
        }

        /// Free string value (if string type).
        pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
            if (self.* == .string) {
                allocator.free(self.string);
            }
        }
    };

    /// Variable scope enumeration.
    pub const VariableScope = enum(u8) {
        global, // Global scope (top-level)
        local, // Local scope (function/block)
    };

    /// Variable type information.
    pub const VariableType = struct {
        type_name: []const u8, // Type name (i32, u64, string, etc.) or null for inferred
        type_name_len: u32,
        is_inferred: bool, // True if type was inferred from initializer
    };

    /// Variable entry (name-value pair).
    pub const Variable = struct {
        name: []const u8, // Variable name (bounded)
        name_len: u32,
        value: Value,
        is_const: bool, // Constant flag
        scope: VariableScope, // Variable scope
        scope_depth: u32, // Scope depth (0 = global, 1+ = local)
        var_type: ?VariableType, // Variable type (optional, for type checking)
    };

    /// Function entry (user-defined or built-in).
    pub const Function = struct {
        name: []const u8, // Function name (bounded)
        name_len: u32,
        is_builtin: bool, // Built-in command flag
        // For user-defined functions:
        param_count: u32,
        body_node: ?u32, // AST node index for function body
        // For built-in functions:
        builtin_handler: ?*const fn (interpreter: *Interpreter, args: []const Value) Error!Value,
    };

    /// Call stack frame (for function calls).
    pub const CallFrame = struct {
        function_name: []const u8, // Function name (for debugging)
        return_value: ?Value, // Return value (if function returned)
        local_vars_start: u32, // Start index in variables array
        local_vars_count: u32, // Number of local variables
    };

    /// Control flow signal (for break/continue).
    pub const ControlFlowSignal = enum(u8) {
        none, // No signal
        break_loop, // Break out of loop
        continue_loop, // Continue to next iteration
    };

    /// Interpreter error enumeration.
    pub const Error = error{
        variable_not_found,
        variable_already_exists,
        function_not_found,
        type_mismatch,
        division_by_zero,
        invalid_argument,
        string_too_long,
        call_stack_overflow,
        too_many_variables,
        too_many_functions,
        too_many_call_args,
        runtime_error,
        OutOfMemory,
    };

    /// Interpreter state.
    parser: *const Parser,
    allocator: std.mem.Allocator,
    variables: []Variable, // Variable storage (bounded)
    variables_len: u32,
    functions: []Function, // Function storage (bounded)
    functions_len: u32,
    call_stack: []CallFrame, // Call stack (bounded)
    call_stack_len: u32,
    exit_code: u32, // Script exit code
    current_directory: []const u8, // Current working directory (bounded)
    scope_depth: u32, // Current scope depth (0 = global, 1+ = local)
    control_flow_signal: ControlFlowSignal, // Current control flow signal (break/continue)

    /// Initialize interpreter with parser.
    pub fn init(allocator: std.mem.Allocator, parser: *const Parser) !Interpreter {
        // Assert: Parser must be valid
        std.debug.assert(parser.get_node_count() > 0);

        // Pre-allocate variable buffer
        const variables = try allocator.alloc(Variable, MAX_VARIABLES);
        errdefer allocator.free(variables);

        // Pre-allocate function buffer
        const functions = try allocator.alloc(Function, MAX_FUNCTIONS);
        errdefer allocator.free(functions);

        // Pre-allocate call stack buffer
        const call_stack = try allocator.alloc(CallFrame, MAX_CALL_STACK);
        errdefer allocator.free(call_stack);

        // Initialize current directory to "/"
        const current_dir = try allocator.dupe(u8, "/");
        errdefer allocator.free(current_dir);

        var interpreter = Interpreter{
            .parser = parser,
            .allocator = allocator,
            .variables = variables,
            .variables_len = 0,
            .functions = functions,
            .functions_len = 0,
            .call_stack = call_stack,
            .call_stack_len = 0,
            .exit_code = 0,
            .current_directory = current_dir,
            .scope_depth = 0, // Start at global scope
            .control_flow_signal = .none, // No control flow signal initially
        };

        // Register built-in commands
        try interpreter.register_builtin_commands();

        return interpreter;
    }

    /// Deinitialize interpreter and free memory.
    pub fn deinit(self: *Interpreter) void {
        // Assert: Interpreter must be valid
        _ = self.allocator; // Allocator is used below

        // Free all variable string values and type names
        var i: u32 = 0;
        while (i < self.variables_len) : (i += 1) {
            self.variables[i].value.deinit(self.allocator);
            if (self.variables[i].name_len > 0) {
                self.allocator.free(self.variables[i].name);
            }
            if (self.variables[i].var_type) |var_type| {
                if (var_type.type_name_len > 0) {
                    self.allocator.free(var_type.type_name);
                }
            }
        }

        // Free all function names
        i = 0;
        while (i < self.functions_len) : (i += 1) {
            if (self.functions[i].name_len > 0) {
                self.allocator.free(self.functions[i].name);
            }
        }

        // Free call stack frame names
        i = 0;
        while (i < self.call_stack_len) : (i += 1) {
            if (self.call_stack[i].function_name.len > 0) {
                self.allocator.free(self.call_stack[i].function_name);
            }
        }

        // Free buffers
        self.allocator.free(self.variables);
        self.allocator.free(self.functions);
        self.allocator.free(self.call_stack);
        self.allocator.free(self.current_directory);

        self.* = undefined;
    }

    /// Register built-in commands (echo, cd, pwd, etc.).
    fn register_builtin_commands(self: *Interpreter) !void {
        // Assert: Interpreter must be initialized
        std.debug.assert(self.functions.len == MAX_FUNCTIONS);

        // Register echo command
        const echo_name = try self.allocator.dupe(u8, "echo");
        errdefer self.allocator.free(echo_name);
        self.functions[self.functions_len] = Function{
            .name = echo_name,
            .name_len = @as(u32, @intCast(echo_name.len)),
            .is_builtin = true,
            .param_count = 0, // Variable arguments
            .body_node = null,
            .builtin_handler = builtin_echo,
        };
        self.functions_len += 1;

        // Register cd command
        const cd_name = try self.allocator.dupe(u8, "cd");
        errdefer self.allocator.free(cd_name);
        self.functions[self.functions_len] = Function{
            .name = cd_name,
            .name_len = @as(u32, @intCast(cd_name.len)),
            .is_builtin = true,
            .param_count = 1,
            .body_node = null,
            .builtin_handler = builtin_cd,
        };
        self.functions_len += 1;

        // Register pwd command
        const pwd_name = try self.allocator.dupe(u8, "pwd");
        errdefer self.allocator.free(pwd_name);
        self.functions[self.functions_len] = Function{
            .name = pwd_name,
            .name_len = @as(u32, @intCast(pwd_name.len)),
            .is_builtin = true,
            .param_count = 0,
            .body_node = null,
            .builtin_handler = builtin_pwd,
        };
        self.functions_len += 1;

        // Register exit command
        const exit_name = try self.allocator.dupe(u8, "exit");
        errdefer self.allocator.free(exit_name);
        self.functions[self.functions_len] = Function{
            .name = exit_name,
            .name_len = @as(u32, @intCast(exit_name.len)),
            .is_builtin = true,
            .param_count = 1,
            .body_node = null,
            .builtin_handler = builtin_exit,
        };
        self.functions_len += 1;

        // Register string functions
        try self.register_string_functions();
        // Register math functions
        try self.register_math_functions();
        // Register type conversion functions
        try self.register_type_conversion_functions();
        // Register type checking functions
        try self.register_type_checking_functions();
        // Register string utility functions
        try self.register_string_utility_functions();
    }

    /// Register string manipulation built-in functions.
    // 2025-11-24-184000-pst: Active function
    fn register_string_functions(self: *Interpreter) !void {
        // len(str) - Get string length
        const len_name = try self.allocator.dupe(u8, "len");
        errdefer self.allocator.free(len_name);
        self.functions[self.functions_len] = Function{
            .name = len_name,
            .name_len = @as(u32, @intCast(len_name.len)),
            .is_builtin = true,
            .param_count = 1,
            .body_node = null,
            .builtin_handler = builtin_len,
        };
        self.functions_len += 1;

        // substr(str, start, end) - Get substring
        const substr_name = try self.allocator.dupe(u8, "substr");
        errdefer self.allocator.free(substr_name);
        self.functions[self.functions_len] = Function{
            .name = substr_name,
            .name_len = @as(u32, @intCast(substr_name.len)),
            .is_builtin = true,
            .param_count = 3,
            .body_node = null,
            .builtin_handler = builtin_substr,
        };
        self.functions_len += 1;

        // trim(str) - Trim whitespace
        const trim_name = try self.allocator.dupe(u8, "trim");
        errdefer self.allocator.free(trim_name);
        self.functions[self.functions_len] = Function{
            .name = trim_name,
            .name_len = @as(u32, @intCast(trim_name.len)),
            .is_builtin = true,
            .param_count = 1,
            .body_node = null,
            .builtin_handler = builtin_trim,
        };
        self.functions_len += 1;

        // indexOf(str, substr) - Find substring position
        const indexof_name = try self.allocator.dupe(u8, "indexOf");
        errdefer self.allocator.free(indexof_name);
        self.functions[self.functions_len] = Function{
            .name = indexof_name,
            .name_len = @as(u32, @intCast(indexof_name.len)),
            .is_builtin = true,
            .param_count = 2,
            .body_node = null,
            .builtin_handler = builtin_indexof,
        };
        self.functions_len += 1;

        // replace(str, old, new) - Replace substring
        const replace_name = try self.allocator.dupe(u8, "replace");
        errdefer self.allocator.free(replace_name);
        self.functions[self.functions_len] = Function{
            .name = replace_name,
            .name_len = @as(u32, @intCast(replace_name.len)),
            .is_builtin = true,
            .param_count = 3,
            .body_node = null,
            .builtin_handler = builtin_replace,
        };
        self.functions_len += 1;

        // toUpper(str) - Convert to uppercase
        const toupper_name = try self.allocator.dupe(u8, "toUpper");
        errdefer self.allocator.free(toupper_name);
        self.functions[self.functions_len] = Function{
            .name = toupper_name,
            .name_len = @as(u32, @intCast(toupper_name.len)),
            .is_builtin = true,
            .param_count = 1,
            .body_node = null,
            .builtin_handler = builtin_toupper,
        };
        self.functions_len += 1;

        // toLower(str) - Convert to lowercase
        const tolower_name = try self.allocator.dupe(u8, "toLower");
        errdefer self.allocator.free(tolower_name);
        self.functions[self.functions_len] = Function{
            .name = tolower_name,
            .name_len = @as(u32, @intCast(tolower_name.len)),
            .is_builtin = true,
            .param_count = 1,
            .body_node = null,
            .builtin_handler = builtin_tolower,
        };
        self.functions_len += 1;

        // startsWith(str, prefix) - Check if string starts with prefix
        const startswith_name = try self.allocator.dupe(u8, "startsWith");
        errdefer self.allocator.free(startswith_name);
        self.functions[self.functions_len] = Function{
            .name = startswith_name,
            .name_len = @as(u32, @intCast(startswith_name.len)),
            .is_builtin = true,
            .param_count = 2,
            .body_node = null,
            .builtin_handler = builtin_startswith,
        };
        self.functions_len += 1;

        // endsWith(str, suffix) - Check if string ends with suffix
        const endswith_name = try self.allocator.dupe(u8, "endsWith");
        errdefer self.allocator.free(endswith_name);
        self.functions[self.functions_len] = Function{
            .name = endswith_name,
            .name_len = @as(u32, @intCast(endswith_name.len)),
            .is_builtin = true,
            .param_count = 2,
            .body_node = null,
            .builtin_handler = builtin_endswith,
        };
        self.functions_len += 1;

        // charAt(str, index) - Get character at index
        const charat_name = try self.allocator.dupe(u8, "charAt");
        errdefer self.allocator.free(charat_name);
        self.functions[self.functions_len] = Function{
            .name = charat_name,
            .name_len = @as(u32, @intCast(charat_name.len)),
            .is_builtin = true,
            .param_count = 2,
            .body_node = null,
            .builtin_handler = builtin_charat,
        };
        self.functions_len += 1;

        // repeat(str, count) - Repeat string N times
        const repeat_name = try self.allocator.dupe(u8, "repeat");
        errdefer self.allocator.free(repeat_name);
        self.functions[self.functions_len] = Function{
            .name = repeat_name,
            .name_len = @as(u32, @intCast(repeat_name.len)),
            .is_builtin = true,
            .param_count = 2,
            .body_node = null,
            .builtin_handler = builtin_repeat,
        };
        self.functions_len += 1;
    }

    /// Register math built-in functions.
    // 2025-11-24-184000-pst: Active function
    fn register_math_functions(self: *Interpreter) !void {
        // abs(x) - Absolute value
        const abs_name = try self.allocator.dupe(u8, "abs");
        errdefer self.allocator.free(abs_name);
        self.functions[self.functions_len] = Function{
            .name = abs_name,
            .name_len = @as(u32, @intCast(abs_name.len)),
            .is_builtin = true,
            .param_count = 1,
            .body_node = null,
            .builtin_handler = builtin_abs,
        };
        self.functions_len += 1;

        // min(a, b) - Minimum value
        const min_name = try self.allocator.dupe(u8, "min");
        errdefer self.allocator.free(min_name);
        self.functions[self.functions_len] = Function{
            .name = min_name,
            .name_len = @as(u32, @intCast(min_name.len)),
            .is_builtin = true,
            .param_count = 2,
            .body_node = null,
            .builtin_handler = builtin_min,
        };
        self.functions_len += 1;

        // max(a, b) - Maximum value
        const max_name = try self.allocator.dupe(u8, "max");
        errdefer self.allocator.free(max_name);
        self.functions[self.functions_len] = Function{
            .name = max_name,
            .name_len = @as(u32, @intCast(max_name.len)),
            .is_builtin = true,
            .param_count = 2,
            .body_node = null,
            .builtin_handler = builtin_max,
        };
        self.functions_len += 1;

        // floor(x) - Floor function
        const floor_name = try self.allocator.dupe(u8, "floor");
        errdefer self.allocator.free(floor_name);
        self.functions[self.functions_len] = Function{
            .name = floor_name,
            .name_len = @as(u32, @intCast(floor_name.len)),
            .is_builtin = true,
            .param_count = 1,
            .body_node = null,
            .builtin_handler = builtin_floor,
        };
        self.functions_len += 1;

        // ceil(x) - Ceiling function
        const ceil_name = try self.allocator.dupe(u8, "ceil");
        errdefer self.allocator.free(ceil_name);
        self.functions[self.functions_len] = Function{
            .name = ceil_name,
            .name_len = @as(u32, @intCast(ceil_name.len)),
            .is_builtin = true,
            .param_count = 1,
            .body_node = null,
            .builtin_handler = builtin_ceil,
        };
        self.functions_len += 1;

        // round(x) - Round function
        const round_name = try self.allocator.dupe(u8, "round");
        errdefer self.allocator.free(round_name);
        self.functions[self.functions_len] = Function{
            .name = round_name,
            .name_len = @as(u32, @intCast(round_name.len)),
            .is_builtin = true,
            .param_count = 1,
            .body_node = null,
            .builtin_handler = builtin_round,
        };
        self.functions_len += 1;

        // sqrt(x) - Square root
        const sqrt_name = try self.allocator.dupe(u8, "sqrt");
        errdefer self.allocator.free(sqrt_name);
        self.functions[self.functions_len] = Function{
            .name = sqrt_name,
            .name_len = @as(u32, @intCast(sqrt_name.len)),
            .is_builtin = true,
            .param_count = 1,
            .body_node = null,
            .builtin_handler = builtin_sqrt,
        };
        self.functions_len += 1;

        // pow(base, exponent) - Power function
        const pow_name = try self.allocator.dupe(u8, "pow");
        errdefer self.allocator.free(pow_name);
        self.functions[self.functions_len] = Function{
            .name = pow_name,
            .name_len = @as(u32, @intCast(pow_name.len)),
            .is_builtin = true,
            .param_count = 2,
            .body_node = null,
            .builtin_handler = builtin_pow,
        };
        self.functions_len += 1;
    }

    /// Register string utility built-in functions.
    // 2025-11-24-213900-pst: Active function
    fn register_string_utility_functions(self: *Interpreter) !void {
        // split(str, delimiter) - Split string by delimiter (returns first part)
        const split_name = try self.allocator.dupe(u8, "split");
        errdefer self.allocator.free(split_name);
        self.functions[self.functions_len] = Function{
            .name = split_name,
            .name_len = @as(u32, @intCast(split_name.len)),
            .is_builtin = true,
            .param_count = 2,
            .body_node = null,
            .builtin_handler = builtin_split,
        };
        self.functions_len += 1;

        // join(str1, delimiter) - Join strings with delimiter (simplified)
        const join_name = try self.allocator.dupe(u8, "join");
        errdefer self.allocator.free(join_name);
        self.functions[self.functions_len] = Function{
            .name = join_name,
            .name_len = @as(u32, @intCast(join_name.len)),
            .is_builtin = true,
            .param_count = 2,
            .body_node = null,
            .builtin_handler = builtin_join,
        };
        self.functions_len += 1;
    }

    /// Built-in echo command: Print arguments to stdout.
    fn builtin_echo(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter; // Unused for now (may need for stdout access)

        // Print all arguments separated by spaces
        var first: bool = true;
        for (args) |arg| {
            if (!first) {
                std.debug.print(" ", .{});
            }
            first = false;

            switch (arg) {
                .integer => |v| std.debug.print("{}", .{v}),
                .float => |v| std.debug.print("{d}", .{v}),
                .string => |v| std.debug.print("{s}", .{v}),
                .boolean => |v| std.debug.print("{}", .{v}),
                .null => std.debug.print("null", .{}),
            }
        }
        std.debug.print("\n", .{});

        return Value.from_integer(0); // Success exit code
    }

    /// Built-in cd command: Change current directory.
    fn builtin_cd(interpreter: *Interpreter, args: []const Value) Error!Value {
        // Assert: Must have exactly one argument
        if (args.len != 1) {
            return Error.invalid_argument;
        }

        // Assert: Argument must be string
        const arg = args[0];
        if (arg != .string) {
            return Error.type_mismatch;
        }

        // Update current directory (bounded)
        const new_dir = arg.string;
        if (new_dir.len > MAX_STRING_LEN) {
            return Error.string_too_long;
        }

        // Free old directory
        interpreter.allocator.free(interpreter.current_directory);

        // Allocate new directory
        interpreter.current_directory = try interpreter.allocator.dupe(u8, new_dir);

        return Value.from_integer(0); // Success exit code
    }

    /// Built-in pwd command: Print current directory.
    fn builtin_pwd(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = args; // Unused

        std.debug.print("{s}\n", .{interpreter.current_directory});

        return Value.from_string(interpreter.allocator, interpreter.current_directory) catch |err| {
            return err;
        };
    }

    /// Built-in exit command: Set exit code and terminate.
    fn builtin_exit(interpreter: *Interpreter, args: []const Value) Error!Value {
        // Assert: Must have exactly one argument
        if (args.len != 1) {
            return Error.invalid_argument;
        }

        // Assert: Argument must be integer
        const arg = args[0];
        if (arg != .integer) {
            return Error.type_mismatch;
        }

        // Set exit code (cast to u32, handle negative)
        const exit_val = arg.integer;
        if (exit_val < 0) {
            interpreter.exit_code = @as(u32, @intCast(-exit_val));
        } else {
            interpreter.exit_code = @as(u32, @intCast(exit_val));
        }

        return Value.from_integer(0);
    }

    /// Built-in len function: Get string length.
    // 2025-11-24-184000-pst: Active function
    fn builtin_len(interpreter: *Interpreter, args: []const Value) Error!Value {
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        const arg = args[0];
        if (arg != .string) {
            return Error.type_mismatch;
        }
        return Value.from_integer(@as(i64, @intCast(arg.string.len)));
    }

    /// Built-in substr function: Get substring.
    // 2025-11-24-184000-pst: Active function
    fn builtin_substr(interpreter: *Interpreter, args: []const Value) Error!Value {
        if (args.len != 3) {
            return Error.invalid_argument;
        }
        if (args[0] != .string) {
            return Error.type_mismatch;
        }
        if (args[1] != .integer or args[2] != .integer) {
            return Error.type_mismatch;
        }
        const str = args[0].string;
        const start = args[1].integer;
        const end = args[2].integer;
        if (start < 0 or end < start or end > @as(i64, @intCast(str.len))) {
            return Error.invalid_argument;
        }
        const start_u = @as(u32, @intCast(start));
        const end_u = @as(u32, @intCast(end));
        const substr = str[start_u..end_u];
        return try Value.from_string(interpreter.allocator, substr);
    }

    /// Built-in trim function: Trim whitespace from string.
    // 2025-11-24-184000-pst: Active function
    fn builtin_trim(interpreter: *Interpreter, args: []const Value) Error!Value {
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        if (args[0] != .string) {
            return Error.type_mismatch;
        }
        const str = args[0].string;
        // Find start (skip whitespace)
        var start: u32 = 0;
        while (start < str.len and (str[start] == ' ' or str[start] == '\t' or str[start] == '\n' or str[start] == '\r')) : (start += 1) {}
        // Find end (skip whitespace from end)
        var end: u32 = str.len;
        while (end > start and (str[end - 1] == ' ' or str[end - 1] == '\t' or str[end - 1] == '\n' or str[end - 1] == '\r')) : (end -= 1) {}
        const trimmed = str[start..end];
        return try Value.from_string(interpreter.allocator, trimmed);
    }

    /// Built-in abs function: Absolute value.
    // 2025-11-24-184000-pst: Active function
    fn builtin_abs(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        const arg = args[0];
        return switch (arg) {
            .integer => |v| Value.from_integer(if (v < 0) -v else v),
            .float => |v| Value.from_float(@abs(v)),
            else => Error.type_mismatch,
        };
    }

    /// Built-in min function: Minimum of two values.
    // 2025-11-24-184000-pst: Active function
    fn builtin_min(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 2) {
            return Error.invalid_argument;
        }
        const a = args[0];
        const b = args[1];
        if (a != b) {
            return Error.type_mismatch;
        }
        return switch (a) {
            .integer => |av| {
                const bv = b.integer;
                return Value.from_integer(if (av < bv) av else bv);
            },
            .float => |av| {
                const bv = b.float;
                return Value.from_float(if (av < bv) av else bv);
            },
            else => Error.type_mismatch,
        };
    }

    /// Built-in max function: Maximum of two values.
    // 2025-11-24-184000-pst: Active function
    fn builtin_max(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 2) {
            return Error.invalid_argument;
        }
        const a = args[0];
        const b = args[1];
        if (a != b) {
            return Error.type_mismatch;
        }
        return switch (a) {
            .integer => |av| {
                const bv = b.integer;
                return Value.from_integer(if (av > bv) av else bv);
            },
            .float => |av| {
                const bv = b.float;
                return Value.from_float(if (av > bv) av else bv);
            },
            else => Error.type_mismatch,
        };
    }

    /// Built-in floor function: Floor of float.
    // 2025-11-24-184000-pst: Active function
    fn builtin_floor(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        const arg = args[0];
        return switch (arg) {
            .integer => |v| Value.from_integer(v),
            .float => |v| Value.from_float(@floor(v)),
            else => Error.type_mismatch,
        };
    }

    /// Built-in ceil function: Ceiling of float.
    // 2025-11-24-184000-pst: Active function
    fn builtin_ceil(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        const arg = args[0];
        return switch (arg) {
            .integer => |v| Value.from_integer(v),
            .float => |v| Value.from_float(@ceil(v)),
            else => Error.type_mismatch,
        };
    }

    /// Built-in round function: Round float to nearest integer.
    // 2025-11-24-184000-pst: Active function
    fn builtin_round(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        const arg = args[0];
        return switch (arg) {
            .integer => |v| Value.from_integer(v),
            .float => |v| Value.from_float(@round(v)),
            else => Error.type_mismatch,
        };
    }

    /// Built-in sqrt function: Square root.
    // 2025-11-24-221400-pst: Active function
    fn builtin_sqrt(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        const arg = args[0];
        return switch (arg) {
            .integer => |v| {
                if (v < 0) {
                    return Error.invalid_argument;
                }
                return Value.from_float(@sqrt(@as(f64, @floatFromInt(v))));
            },
            .float => |v| {
                if (v < 0.0) {
                    return Error.invalid_argument;
                }
                return Value.from_float(@sqrt(v));
            },
            else => Error.type_mismatch,
        };
    }

    /// Built-in pow function: Power (base^exponent).
    // 2025-11-24-221400-pst: Active function
    fn builtin_pow(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 2) {
            return Error.invalid_argument;
        }
        const base = args[0];
        const exponent = args[1];
        const base_f64: f64 = switch (base) {
            .integer => |v| @as(f64, @floatFromInt(v)),
            .float => |v| v,
            else => return Error.type_mismatch,
        };
        const exp_f64: f64 = switch (exponent) {
            .integer => |v| @as(f64, @floatFromInt(v)),
            .float => |v| v,
            else => return Error.type_mismatch,
        };
        return Value.from_float(std.math.pow(f64, base_f64, exp_f64));
    }

    /// Built-in indexOf function: Find substring position.
    // 2025-11-24-201000-pst: Active function
    fn builtin_indexof(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 2) {
            return Error.invalid_argument;
        }
        if (args[0] != .string or args[1] != .string) {
            return Error.type_mismatch;
        }
        const str = args[0].string;
        const substr = args[1].string;
        if (substr.len == 0) {
            return Value.from_integer(0);
        }
        if (substr.len > str.len) {
            return Value.from_integer(-1);
        }
        var i: u32 = 0;
        while (i <= str.len - substr.len) : (i += 1) {
            if (std.mem.eql(u8, str[i..i + substr.len], substr)) {
                return Value.from_integer(@as(i64, @intCast(i)));
            }
        }
        return Value.from_integer(-1);
    }

    /// Built-in replace function: Replace substring.
    // 2025-11-24-201000-pst: Active function
    fn builtin_replace(interpreter: *Interpreter, args: []const Value) Error!Value {
        if (args.len != 3) {
            return Error.invalid_argument;
        }
        if (args[0] != .string or args[1] != .string or args[2] != .string) {
            return Error.type_mismatch;
        }
        const str = args[0].string;
        const old_str = args[1].string;
        const new_str = args[2].string;
        if (old_str.len == 0) {
            return try Value.from_string(interpreter.allocator, str);
        }
        // Find first occurrence
        var found_idx: ?u32 = null;
        var i: u32 = 0;
        while (i <= str.len - old_str.len) : (i += 1) {
            if (std.mem.eql(u8, str[i..i + old_str.len], old_str)) {
                found_idx = i;
                break;
            }
        }
        if (found_idx == null) {
            return try Value.from_string(interpreter.allocator, str);
        }
        const idx = found_idx.?;
        // Build result string (before + new + after)
        const before_len = idx;
        const after_start = idx + old_str.len;
        const after_len = str.len - after_start;
        const result_len = before_len + new_str.len + after_len;
        if (result_len > MAX_STRING_LEN) {
            return Error.string_too_long;
        }
        var result = try interpreter.allocator.alloc(u8, result_len);
        errdefer interpreter.allocator.free(result);
        @memcpy(result[0..before_len], str[0..before_len]);
        @memcpy(result[before_len..before_len + new_str.len], new_str);
        @memcpy(result[before_len + new_str.len..], str[after_start..]);
        return Value{ .string = result };
    }

    /// Built-in toUpper function: Convert string to uppercase.
    // 2025-11-24-201000-pst: Active function
    fn builtin_toupper(interpreter: *Interpreter, args: []const Value) Error!Value {
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        if (args[0] != .string) {
            return Error.type_mismatch;
        }
        const str = args[0].string;
        var result = try interpreter.allocator.alloc(u8, str.len);
        errdefer interpreter.allocator.free(result);
        var i: u32 = 0;
        while (i < str.len) : (i += 1) {
            const ch = str[i];
            if (ch >= 'a' and ch <= 'z') {
                result[i] = ch - 32;
            } else {
                result[i] = ch;
            }
        }
        return Value{ .string = result };
    }

    /// Built-in toLower function: Convert string to lowercase.
    // 2025-11-24-201000-pst: Active function
    fn builtin_tolower(interpreter: *Interpreter, args: []const Value) Error!Value {
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        if (args[0] != .string) {
            return Error.type_mismatch;
        }
        const str = args[0].string;
        var result = try interpreter.allocator.alloc(u8, str.len);
        errdefer interpreter.allocator.free(result);
        var i: u32 = 0;
        while (i < str.len) : (i += 1) {
            const ch = str[i];
            if (ch >= 'A' and ch <= 'Z') {
                result[i] = ch + 32;
            } else {
                result[i] = ch;
            }
        }
        return Value{ .string = result };
    }

    /// Built-in startsWith function: Check if string starts with prefix.
    // 2025-11-24-203000-pst: Active function
    fn builtin_startswith(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 2) {
            return Error.invalid_argument;
        }
        if (args[0] != .string or args[1] != .string) {
            return Error.type_mismatch;
        }
        const str = args[0].string;
        const prefix = args[1].string;
        if (prefix.len > str.len) {
            return Value.from_boolean(false);
        }
        return Value.from_boolean(std.mem.eql(u8, str[0..prefix.len], prefix));
    }

    /// Built-in endsWith function: Check if string ends with suffix.
    // 2025-11-24-203000-pst: Active function
    fn builtin_endswith(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 2) {
            return Error.invalid_argument;
        }
        if (args[0] != .string or args[1] != .string) {
            return Error.type_mismatch;
        }
        const str = args[0].string;
        const suffix = args[1].string;
        if (suffix.len > str.len) {
            return Value.from_boolean(false);
        }
        const start_idx = str.len - suffix.len;
        return Value.from_boolean(std.mem.eql(u8, str[start_idx..], suffix));
    }

    /// Built-in charAt function: Get character at index.
    // 2025-11-24-203000-pst: Active function
    fn builtin_charat(interpreter: *Interpreter, args: []const Value) Error!Value {
        if (args.len != 2) {
            return Error.invalid_argument;
        }
        if (args[0] != .string or args[1] != .integer) {
            return Error.type_mismatch;
        }
        const str = args[0].string;
        const idx = args[1].integer;
        if (idx < 0 or @as(u32, @intCast(idx)) >= str.len) {
            return Error.invalid_argument;
        }
        const idx_u = @as(u32, @intCast(idx));
        const ch = str[idx_u];
        var result = try interpreter.allocator.alloc(u8, 1);
        errdefer interpreter.allocator.free(result);
        result[0] = ch;
        return Value{ .string = result };
    }

    /// Built-in repeat function: Repeat string N times.
    // 2025-11-24-203000-pst: Active function
    fn builtin_repeat(interpreter: *Interpreter, args: []const Value) Error!Value {
        if (args.len != 2) {
            return Error.invalid_argument;
        }
        if (args[0] != .string or args[1] != .integer) {
            return Error.type_mismatch;
        }
        const str = args[0].string;
        const count = args[1].integer;
        if (count < 0) {
            return Error.invalid_argument;
        }
        if (count == 0) {
            return try Value.from_string(interpreter.allocator, "");
        }
        const count_u = @as(u32, @intCast(count));
        const result_len = str.len * count_u;
        if (result_len > MAX_STRING_LEN) {
            return Error.string_too_long;
        }
        var result = try interpreter.allocator.alloc(u8, result_len);
        errdefer interpreter.allocator.free(result);
        var i: u32 = 0;
        while (i < count_u) : (i += 1) {
            @memcpy(result[i * str.len..(i + 1) * str.len], str);
        }
        return Value{ .string = result };
    }

    /// Built-in toString function: Convert value to string.
    // 2025-11-24-204000-pst: Active function
    fn builtin_tostring(interpreter: *Interpreter, args: []const Value) Error!Value {
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        const arg = args[0];
        return switch (arg) {
            .integer => |v| {
                var buf: [32]u8 = undefined;
                const str = std.fmt.bufPrint(&buf, "{}", .{v}) catch return Error.runtime_error;
                return try Value.from_string(interpreter.allocator, str);
            },
            .float => |v| {
                var buf: [64]u8 = undefined;
                const str = std.fmt.bufPrint(&buf, "{d}", .{v}) catch return Error.runtime_error;
                return try Value.from_string(interpreter.allocator, str);
            },
            .string => |v| try Value.from_string(interpreter.allocator, v),
            .boolean => |v| {
                const str = if (v) "true" else "false";
                return try Value.from_string(interpreter.allocator, str);
            },
            .null => try Value.from_string(interpreter.allocator, "null"),
        };
    }

    /// Built-in toInt function: Convert value to integer.
    // 2025-11-24-204000-pst: Active function
    fn builtin_toint(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        const arg = args[0];
        return switch (arg) {
            .integer => |v| Value.from_integer(v),
            .float => |v| Value.from_integer(@as(i64, @intFromFloat(v))),
            .string => |v| {
                const int_val = std.fmt.parseInt(i64, v, 10) catch return Error.type_mismatch;
                return Value.from_integer(int_val);
            },
            .boolean => |v| Value.from_integer(if (v) 1 else 0),
            .null => Error.type_mismatch,
        };
    }

    /// Built-in toFloat function: Convert value to float.
    // 2025-11-24-204000-pst: Active function
    fn builtin_tofloat(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        const arg = args[0];
        return switch (arg) {
            .integer => |v| Value.from_float(@as(f64, @floatFromInt(v))),
            .float => |v| Value.from_float(v),
            .string => |v| {
                const float_val = std.fmt.parseFloat(f64, v) catch return Error.type_mismatch;
                return Value.from_float(float_val);
            },
            .boolean => |v| Value.from_float(if (v) 1.0 else 0.0),
            .null => Error.type_mismatch,
        };
    }

    /// Built-in isNull function: Check if value is null.
    // 2025-11-24-211500-pst: Active function
    fn builtin_isnull(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        return Value.from_boolean(args[0] == .null);
    }

    /// Built-in isEmpty function: Check if string is empty.
    // 2025-11-24-211500-pst: Active function
    fn builtin_isempty(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        return switch (args[0]) {
            .string => |v| Value.from_boolean(v.len == 0),
            else => Value.from_boolean(false),
        };
    }

    /// Built-in isNumber function: Check if value is number.
    // 2025-11-24-211500-pst: Active function
    fn builtin_isnumber(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        return switch (args[0]) {
            .integer, .float => Value.from_boolean(true),
            else => Value.from_boolean(false),
        };
    }

    /// Built-in isString function: Check if value is string.
    // 2025-11-24-211500-pst: Active function
    fn builtin_isstring(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        return Value.from_boolean(args[0] == .string);
    }

    /// Built-in isBoolean function: Check if value is boolean.
    // 2025-11-24-211500-pst: Active function
    fn builtin_isboolean(interpreter: *Interpreter, args: []const Value) Error!Value {
        _ = interpreter;
        if (args.len != 1) {
            return Error.invalid_argument;
        }
        return Value.from_boolean(args[0] == .boolean);
    }

    /// Built-in split function: Split string by delimiter (returns first part).
    // 2025-11-24-213900-pst: Active function
    fn builtin_split(interpreter: *Interpreter, args: []const Value) Error!Value {
        if (args.len != 2) {
            return Error.invalid_argument;
        }
        if (args[0] != .string or args[1] != .string) {
            return Error.type_mismatch;
        }
        const str = args[0].string;
        const delimiter = args[1].string;

        // Empty delimiter, return original string
        if (delimiter.len == 0) {
            return try Value.from_string(interpreter.allocator, str);
        }

        // Find first occurrence of delimiter
        var i: u32 = 0;
        while (i <= str.len - delimiter.len) : (i += 1) {
            if (std.mem.eql(u8, str[i..i + delimiter.len], delimiter)) {
                // Return part before delimiter
                const result = try interpreter.allocator.dupe(u8, str[0..i]);
                return try Value.from_string(interpreter.allocator, result);
            }
        }

        // Delimiter not found, return original string
        return try Value.from_string(interpreter.allocator, str);
    }

    /// Built-in join function: Join strings with delimiter (simplified).
    // 2025-11-24-213900-pst: Active function
    fn builtin_join(interpreter: *Interpreter, args: []const Value) Error!Value {
        if (args.len != 2) {
            return Error.invalid_argument;
        }
        // Simplified: join two strings with delimiter
        if (args[0] != .string or args[1] != .string) {
            return Error.type_mismatch;
        }
        const str1 = args[0].string;
        const delimiter = args[1].string;

        // Return first string + delimiter
        const result = try std.fmt.allocPrint(interpreter.allocator, "{s}{s}", .{ str1, delimiter });
        errdefer interpreter.allocator.free(result);
        return try Value.from_string(interpreter.allocator, result);
    }

    /// Execute AST (evaluate all top-level statements).
    pub fn execute(self: *Interpreter) Error!void {
        // Assert: Interpreter must be initialized
        std.debug.assert(self.parser.get_node_count() > 0);

        // Get all AST nodes from parser
        const node_count = self.parser.get_node_count();
        var i: u32 = 0;
        while (i < node_count) : (i += 1) {
            const node = self.parser.get_node(i);
            if (node) |n| {
                // Execute statement or declaration
                _ = try self.execute_statement_or_declaration(n);
            }
        }
    }

    /// Execute statement or declaration.
    fn execute_statement_or_declaration(self: *Interpreter, node: Parser.Node) Error!Value {
        return switch (node.node_type) {
            .stmt_expr => self.execute_expression_statement(node),
            .stmt_var => self.execute_variable_statement(node),
            .stmt_const => self.execute_constant_statement(node),
            .stmt_if => self.execute_if_statement(node),
            .stmt_while => self.execute_while_statement(node),
            .stmt_for => self.execute_for_statement(node),
            .stmt_return => self.execute_return_statement(node),
            .stmt_break => self.execute_break_statement(node),
            .stmt_continue => self.execute_continue_statement(node),
            .stmt_block => self.execute_block_statement(node),
            .decl_fn => self.execute_function_declaration(node),
            .decl_var => self.execute_variable_declaration(node),
            .decl_const => self.execute_constant_declaration(node),
            else => Error.runtime_error,
        };
    }

    /// Execute expression statement.
    fn execute_expression_statement(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be expression statement
        std.debug.assert(node.node_type == .stmt_expr);

        // Get expression from statement data (uses group data)
        const group_data = node.data.group;
        const expr_node = self.parser.get_node(group_data.expr) orelse return Error.runtime_error;

        // Evaluate expression (discard result)
        _ = try self.evaluate_expression(expr_node);

        return Value.from_null();
    }

    /// Execute variable statement.
    fn execute_variable_statement(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be variable statement
        std.debug.assert(node.node_type == .stmt_var);

        const stmt_data = node.data.var_stmt;

        // Check if variable already exists
        if (self.find_variable(stmt_data.name) != null) {
            return Error.variable_already_exists;
        }

        // Check variable limit
        if (self.variables_len >= MAX_VARIABLES) {
            return Error.too_many_variables;
        }

        // Evaluate initializer (if any)
        var value = Value.from_null();
        var inferred_type: ?VariableType = null;

        if (stmt_data.init) |init_node_idx| {
            const init_node = self.parser.get_node(init_node_idx) orelse return Error.runtime_error;
            value = try self.evaluate_expression(init_node);

            // Type inference: infer type from initializer if not explicitly declared
            if (stmt_data.type_node == null) {
                const inferred_type_name = try self.infer_type_from_value(value);
                const type_name_copy = try self.allocator.dupe(u8, inferred_type_name);
                errdefer self.allocator.free(type_name_copy);

                inferred_type = VariableType{
                    .type_name = type_name_copy,
                    .type_name_len = @as(u32, @intCast(type_name_copy.len)),
                    .is_inferred = true,
                };
            }
        }

        // Parse declared type (if any)
        var declared_type: ?VariableType = null;
        if (stmt_data.type_node) |type_node_idx| {
            const type_node = self.parser.get_node(type_node_idx) orelse return Error.runtime_error;
            if (type_node.node_type == .type_named) {
                const type_name = type_node.data.type_named.name;
                const type_name_copy = try self.allocator.dupe(u8, type_name);
                errdefer self.allocator.free(type_name_copy);

                declared_type = VariableType{
                    .type_name = type_name_copy,
                    .type_name_len = @as(u32, @intCast(type_name_copy.len)),
                    .is_inferred = false,
                };

                // Type checking: verify initializer matches declared type
                if (stmt_data.init) |init_node_idx| {
                    const init_node = self.parser.get_node(init_node_idx) orelse return Error.runtime_error;
                    const init_value = try self.evaluate_expression(init_node);
                    if (!self.value_matches_type(init_value, type_name)) {
                        return Error.type_mismatch;
                    }
                }
            }
        }

        // Use declared type if available, otherwise use inferred type
        const var_type = declared_type orelse inferred_type;

        // Allocate variable name
        const var_name = try self.allocator.dupe(u8, stmt_data.name);
        errdefer self.allocator.free(var_name);

        // Store variable (with scope information and type)
        self.variables[self.variables_len] = Variable{
            .name = var_name,
            .name_len = @as(u32, @intCast(var_name.len)),
            .value = value,
            .is_const = false,
            .scope = if (self.scope_depth == 0) .global else .local,
            .scope_depth = self.scope_depth,
            .var_type = var_type,
        };
        self.variables_len += 1;

        return Value.from_null();
    }

    /// Execute constant statement.
    fn execute_constant_statement(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be constant statement
        std.debug.assert(node.node_type == .stmt_const);

        const stmt_data = node.data.var_stmt; // Reuse VarStmtData

        // Check if variable already exists
        if (self.find_variable(stmt_data.name) != null) {
            return Error.variable_already_exists;
        }

        // Check variable limit
        if (self.variables_len >= MAX_VARIABLES) {
            return Error.too_many_variables;
        }

        // Evaluate initializer (required for constants)
        const init_node_idx = stmt_data.init orelse return Error.runtime_error;
        const init_node = self.parser.get_node(init_node_idx) orelse return Error.runtime_error;
        const value = try self.evaluate_expression(init_node);

        // Allocate variable name
        const var_name = try self.allocator.dupe(u8, stmt_data.name);
        errdefer self.allocator.free(var_name);

        // Type inference: infer type from initializer if not explicitly declared
        var inferred_type: ?VariableType = null;
        if (stmt_data.type_node == null) {
            const inferred_type_name = try self.infer_type_from_value(value);
            const type_name_copy = try self.allocator.dupe(u8, inferred_type_name);
            errdefer self.allocator.free(type_name_copy);

            inferred_type = VariableType{
                .type_name = type_name_copy,
                .type_name_len = @as(u32, @intCast(type_name_copy.len)),
                .is_inferred = true,
            };
        }

        // Parse declared type (if any)
        var declared_type: ?VariableType = null;
        if (stmt_data.type_node) |type_node_idx| {
            const type_node = self.parser.get_node(type_node_idx) orelse return Error.runtime_error;
            if (type_node.node_type == .type_named) {
                const type_name = type_node.data.type_named.name;
                const type_name_copy = try self.allocator.dupe(u8, type_name);
                errdefer self.allocator.free(type_name_copy);

                declared_type = VariableType{
                    .type_name = type_name_copy,
                    .type_name_len = @as(u32, @intCast(type_name_copy.len)),
                    .is_inferred = false,
                };

                // Type checking: verify initializer matches declared type
                if (!self.value_matches_type(value, type_name)) {
                    return Error.type_mismatch;
                }
            }
        }

        // Use declared type if available, otherwise use inferred type
        const var_type = declared_type orelse inferred_type;

        // Store variable (as constant, with scope information and type)
        self.variables[self.variables_len] = Variable{
            .name = var_name,
            .name_len = @as(u32, @intCast(var_name.len)),
            .value = value,
            .is_const = true,
            .scope = if (self.scope_depth == 0) .global else .local,
            .scope_depth = self.scope_depth,
            .var_type = var_type,
        };
        self.variables_len += 1;

        return Value.from_null();
    }

    /// Execute if statement.
    fn execute_if_statement(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be if statement
        std.debug.assert(node.node_type == .stmt_if);

        const stmt_data = node.data.if_stmt;

        // Evaluate condition
        const condition_node = self.parser.get_node(stmt_data.condition) orelse return Error.runtime_error;
        const condition_value = try self.evaluate_expression(condition_node);
        const condition_bool = condition_value.to_boolean();

        // Execute then or else block
        if (condition_bool) {
            const then_node = self.parser.get_node(stmt_data.then_block) orelse return Error.runtime_error;
            return self.execute_block_statement(then_node);
        } else if (stmt_data.else_block) |else_node_idx| {
            const else_node = self.parser.get_node(else_node_idx) orelse return Error.runtime_error;
            return self.execute_block_statement(else_node);
        }

        return Value.from_null();
    }

    /// Execute while statement.
    fn execute_while_statement(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be while statement
        std.debug.assert(node.node_type == .stmt_while);

        const stmt_data = node.data.while_stmt;

        // Loop while condition is true
        while (true) {
            // Reset control flow signal at start of iteration
            self.control_flow_signal = .none;

            const condition_node = self.parser.get_node(stmt_data.condition) orelse return Error.runtime_error;
            const condition_value = try self.evaluate_expression(condition_node);
            const condition_bool = condition_value.to_boolean();

            if (!condition_bool) {
                break;
            }

            const body_node = self.parser.get_node(stmt_data.body) orelse return Error.runtime_error;
            _ = try self.execute_block_statement(body_node);

            // Check for break signal
            if (self.control_flow_signal == .break_loop) {
                self.control_flow_signal = .none;
                break;
            }

            // Continue signal is handled by loop iteration (already at top)
            if (self.control_flow_signal == .continue_loop) {
                self.control_flow_signal = .none;
                continue;
            }
        }

        // Reset control flow signal after loop
        self.control_flow_signal = .none;

        return Value.from_null();
    }

    /// Execute for statement.
    fn execute_for_statement(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be for statement
        std.debug.assert(node.node_type == .stmt_for);

        const stmt_data = node.data.for_stmt;

        // Execute initializer (if any)
        if (stmt_data.init) |init_node_idx| {
            const init_node = self.parser.get_node(init_node_idx) orelse return Error.runtime_error;
            _ = try self.execute_statement_or_declaration(init_node);
        }

        // Loop while condition is true
        while (true) {
            // Reset control flow signal at start of iteration
            self.control_flow_signal = .none;

            // Check condition (if any)
            if (stmt_data.condition) |condition_node_idx| {
                const condition_node = self.parser.get_node(condition_node_idx) orelse return Error.runtime_error;
                const condition_value = try self.evaluate_expression(condition_node);
                const condition_bool = condition_value.to_boolean();

                if (!condition_bool) {
                    break;
                }
            }

            // Execute body
            const body_node = self.parser.get_node(stmt_data.body) orelse return Error.runtime_error;
            _ = try self.execute_block_statement(body_node);

            // Check for break signal (before update)
            if (self.control_flow_signal == .break_loop) {
                self.control_flow_signal = .none;
                break;
            }

            // Check for continue signal (skip update, go to next iteration)
            if (self.control_flow_signal == .continue_loop) {
                self.control_flow_signal = .none;
                // Skip update and continue to next iteration
                continue;
            }

            // Execute update (if any)
            if (stmt_data.update) |update_node_idx| {
                const update_node = self.parser.get_node(update_node_idx) orelse return Error.runtime_error;
                _ = try self.evaluate_expression(update_node);
            }
        }

        // Reset control flow signal after loop
        self.control_flow_signal = .none;

        return Value.from_null();
    }

    /// Execute return statement.
    // 2025-11-24-183000-pst: Active function
    fn execute_return_statement(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be return statement
        std.debug.assert(node.node_type == .stmt_return);

        const stmt_data = node.data.return_stmt;

        // Evaluate return value (if any)
        var return_value: Value = Value.from_null();
        if (stmt_data.value) |value_node_idx| {
            const value_node = self.parser.get_node(value_node_idx) orelse return Error.runtime_error;
            return_value = try self.evaluate_expression(value_node);
        }

        // Store return value in current call frame (if in function)
        if (self.call_stack_len > 0) {
            const frame_idx = self.call_stack_len - 1;
            // Copy return value (for strings, allocate new copy)
            if (return_value == .string) {
                const return_val_copy = try Value.from_string(self.allocator, return_value.string);
                self.call_stack[frame_idx].return_value = return_val_copy;
            } else {
                self.call_stack[frame_idx].return_value = return_value;
            }
        }

        return return_value;
    }

    /// Execute break statement.
    fn execute_break_statement(self: *Interpreter, node: Parser.Node) Error!Value {
        _ = node; // Unused for now
        // Set break signal
        self.control_flow_signal = .break_loop;
        return Value.from_null();
    }

    /// Execute continue statement.
    fn execute_continue_statement(self: *Interpreter, node: Parser.Node) Error!Value {
        _ = node; // Unused for now
        // Set continue signal
        self.control_flow_signal = .continue_loop;
        return Value.from_null();
    }

    /// Execute block statement.
    fn execute_block_statement(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be block statement
        std.debug.assert(node.node_type == .stmt_block);

        const stmt_data = node.data.block;

        // Enter new scope
        const old_scope_depth = self.scope_depth;
        self.scope_depth += 1;
        defer self.scope_depth = old_scope_depth;

        // Track variables created in this scope
        const vars_before = self.variables_len;

        // Execute all statements in block
        var i: u32 = 0;
        while (i < stmt_data.statements_len) : (i += 1) {
            // Check for break/continue signal (propagate to loop)
            if (self.control_flow_signal != .none) {
                break;
            }

            // Check for return value in call frame (function returned)
            if (self.call_stack_len > 0) {
                const frame_idx = self.call_stack_len - 1;
                if (self.call_stack[frame_idx].return_value != null) {
                    break; // Function returned, stop executing
                }
            }

            const stmt_node_idx = stmt_data.statements[i];
            const stmt_node = self.parser.get_node(stmt_node_idx) orelse return Error.runtime_error;
            _ = try self.execute_statement_or_declaration(stmt_node);

            // Check for break/continue signal after statement
            if (self.control_flow_signal != .none) {
                break;
            }

            // Check for return value after statement
            if (self.call_stack_len > 0) {
                const frame_idx = self.call_stack_len - 1;
                if (self.call_stack[frame_idx].return_value != null) {
                    break; // Function returned, stop executing
                }
            }
        }

        // Clean up local variables (free string values)
        while (self.variables_len > vars_before) {
            self.variables_len -= 1;
            const variable = &self.variables[self.variables_len];
            variable.value.deinit(self.allocator);
            self.allocator.free(variable.name);
        }

        return Value.from_null();
    }

    /// Execute function declaration.
    fn execute_function_declaration(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be function declaration
        std.debug.assert(node.node_type == .decl_fn);

        const decl_data = node.data.fn_decl;

        // Check if function already exists
        if (self.find_function(decl_data.name) != null) {
            return Error.runtime_error; // Function already defined
        }

        // Check function limit
        if (self.functions_len >= MAX_FUNCTIONS) {
            return Error.too_many_functions;
        }

        // Allocate function name
        const fn_name = try self.allocator.dupe(u8, decl_data.name);
        errdefer self.allocator.free(fn_name);

        // Store function (user-defined)
        self.functions[self.functions_len] = Function{
            .name = fn_name,
            .name_len = @as(u32, @intCast(fn_name.len)),
            .is_builtin = false,
            .param_count = decl_data.params_len,
            .body_node = decl_data.body,
            .builtin_handler = null,
        };
        self.functions_len += 1;

        return Value.from_null();
    }

    /// Execute variable declaration (top-level).
    fn execute_variable_declaration(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be variable declaration
        std.debug.assert(node.node_type == .decl_var);

        // Reuse variable statement logic
        const var_node = Parser.Node{
            .node_type = .stmt_var,
            .start = node.start,
            .end = node.end,
            .line = node.line,
            .column = node.column,
            .depth = node.depth,
            .data = node.data,
        };

        return self.execute_variable_statement(var_node);
    }

    /// Execute constant declaration (top-level).
    fn execute_constant_declaration(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be constant declaration
        std.debug.assert(node.node_type == .decl_const);

        // Reuse constant statement logic
        const const_node = Parser.Node{
            .node_type = .stmt_const,
            .start = node.start,
            .end = node.end,
            .line = node.line,
            .column = node.column,
            .depth = node.depth,
            .data = node.data,
        };

        return self.execute_constant_statement(const_node);
    }

    /// Evaluate expression.
    fn evaluate_expression(self: *Interpreter, node: Parser.Node) Error!Value {
        return switch (node.node_type) {
            .expr_literal => self.evaluate_literal_expression(node),
            .expr_identifier => self.evaluate_identifier_expression(node),
            .expr_binary => self.evaluate_binary_expression(node),
            .expr_unary => self.evaluate_unary_expression(node),
            .expr_call => self.evaluate_call_expression(node),
            .expr_group => self.evaluate_group_expression(node),
            .expr_assign => self.evaluate_assign_expression(node),
            else => Error.runtime_error,
        };
    }

    /// Evaluate literal expression.
    fn evaluate_literal_expression(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be literal expression
        std.debug.assert(node.node_type == .expr_literal);

        const literal_data = node.data.literal;

        return switch (literal_data.literal_type) {
            .integer => blk: {
                const int_val = std.fmt.parseInt(i64, literal_data.value, 10) catch return Error.runtime_error;
                break :blk Value.from_integer(int_val);
            },
            .float => blk: {
                const float_val = std.fmt.parseFloat(f64, literal_data.value) catch return Error.runtime_error;
                break :blk Value.from_float(float_val);
            },
            .string => blk: {
                // Remove quotes and unescape
                const str_val = literal_data.value;
                if (str_val.len < 2) {
                    return Error.runtime_error;
                }
                const unquoted = str_val[1..str_val.len-1]; // Remove quotes
                break :blk try Value.from_string(self.allocator, unquoted);
            },
            .boolean_true => Value.from_boolean(true),
            .boolean_false => Value.from_boolean(false),
            .null => Value.from_null(),
        };
    }

    /// Evaluate identifier expression.
    fn evaluate_identifier_expression(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be identifier expression
        std.debug.assert(node.node_type == .expr_identifier);

        const identifier_data = node.data.identifier;

        // Find variable
        const variable = self.find_variable(identifier_data.name) orelse {
            return Error.variable_not_found;
        };

        // Return variable value (copy for strings)
        return switch (variable.value) {
            .integer => |v| Value.from_integer(v),
            .float => |v| Value.from_float(v),
            .string => |v| blk: {
                // Copy string value
                break :blk try Value.from_string(self.allocator, v);
            },
            .boolean => |v| Value.from_boolean(v),
            .null => Value.from_null(),
        };
    }

    /// Evaluate binary expression.
    fn evaluate_binary_expression(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be binary expression
        std.debug.assert(node.node_type == .expr_binary);

        const binary_data = node.data.binary;

        // Evaluate operands
        const left_node = self.parser.get_node(binary_data.left) orelse return Error.runtime_error;
        const right_node = self.parser.get_node(binary_data.right) orelse return Error.runtime_error;
        const left_value = try self.evaluate_expression(left_node);
        const right_value = try self.evaluate_expression(right_node);

        // Perform operation
        return switch (binary_data.operator) {
            .add => self.binary_add(left_value, right_value),
            .subtract => self.binary_subtract(left_value, right_value),
            .multiply => self.binary_multiply(left_value, right_value),
            .divide => self.binary_divide(left_value, right_value),
            .modulo => self.binary_modulo(left_value, right_value),
            .eq => self.binary_eq(left_value, right_value),
            .ne => self.binary_ne(left_value, right_value),
            .lt => self.binary_lt(left_value, right_value),
            .le => self.binary_le(left_value, right_value),
            .gt => self.binary_gt(left_value, right_value),
            .ge => self.binary_ge(left_value, right_value),
            .and_op => self.binary_and(left_value, right_value),
            .or_op => self.binary_or(left_value, right_value),
        };
    }

    /// Binary addition.
    // 2025-11-23-160254-pst: Active function
    fn binary_add(self: *Interpreter, left: Value, right: Value) Error!Value {
        // self will be used in full implementation for context
        return switch (left) {
            .integer => |l| switch (right) {
                .integer => |r| Value.from_integer(l + r),
                .float => |r| Value.from_float(@as(f64, @floatFromInt(l)) + r),
                else => Error.type_mismatch,
            },
            .float => |l| switch (right) {
                .integer => |r| Value.from_float(l + @as(f64, @floatFromInt(r))),
                .float => |r| Value.from_float(l + r),
                else => Error.type_mismatch,
            },
            .string => |l| switch (right) {
                .string => |r| {
                    // Concatenate strings
                    const combined = std.fmt.allocPrint(self.allocator, "{s}{s}", .{ l, r }) catch return Error.OutOfMemory;
                    errdefer self.allocator.free(combined);
                    return try Value.from_string(self.allocator, combined);
                },
                else => Error.type_mismatch,
            },
            else => Error.type_mismatch,
        };
    }

    /// Binary subtraction.
    fn binary_subtract(self: *Interpreter, left: Value, right: Value) Error!Value {
        _ = self;
        return switch (left) {
            .integer => |l| switch (right) {
                .integer => |r| Value.from_integer(l - r),
                .float => |r| Value.from_float(@as(f64, @floatFromInt(l)) - r),
                else => Error.type_mismatch,
            },
            .float => |l| switch (right) {
                .integer => |r| Value.from_float(l - @as(f64, @floatFromInt(r))),
                .float => |r| Value.from_float(l - r),
                else => Error.type_mismatch,
            },
            else => Error.type_mismatch,
        };
    }

    /// Binary multiplication.
    fn binary_multiply(self: *Interpreter, left: Value, right: Value) Error!Value {
        _ = self;
        return switch (left) {
            .integer => |l| switch (right) {
                .integer => |r| Value.from_integer(l * r),
                .float => |r| Value.from_float(@as(f64, @floatFromInt(l)) * r),
                else => Error.type_mismatch,
            },
            .float => |l| switch (right) {
                .integer => |r| Value.from_float(l * @as(f64, @floatFromInt(r))),
                .float => |r| Value.from_float(l * r),
                else => Error.type_mismatch,
            },
            else => Error.type_mismatch,
        };
    }

    /// Binary division.
    fn binary_divide(self: *Interpreter, left: Value, right: Value) Error!Value {
        _ = self;
        return switch (left) {
            .integer => |l| switch (right) {
                .integer => |r| {
                    if (r == 0) {
                        return Error.division_by_zero;
                    }
                    return Value.from_integer(@divTrunc(l, r));
                },
                .float => |r| {
                    if (r == 0.0) {
                        return Error.division_by_zero;
                    }
                    return Value.from_float(@as(f64, @floatFromInt(l)) / r);
                },
                else => Error.type_mismatch,
            },
            .float => |l| switch (right) {
                .integer => |r| {
                    if (r == 0) {
                        return Error.division_by_zero;
                    }
                    return Value.from_float(l / @as(f64, @floatFromInt(r)));
                },
                .float => |r| {
                    if (r == 0.0) {
                        return Error.division_by_zero;
                    }
                    return Value.from_float(l / r);
                },
                else => Error.type_mismatch,
            },
            else => Error.type_mismatch,
        };
    }

    /// Binary modulo.
    fn binary_modulo(self: *Interpreter, left: Value, right: Value) Error!Value {
        _ = self;
        return switch (left) {
            .integer => |l| switch (right) {
                .integer => |r| {
                    if (r == 0) {
                        return Error.division_by_zero;
                    }
                    return Value.from_integer(@mod(l, r));
                },
                else => Error.type_mismatch,
            },
            else => Error.type_mismatch,
        };
    }

    /// Binary equality.
    fn binary_eq(self: *Interpreter, left: Value, right: Value) Error!Value {
        _ = self;
        return switch (left) {
            .integer => |l| switch (right) {
                .integer => |r| Value.from_boolean(l == r),
                .float => |r| Value.from_boolean(@as(f64, @floatFromInt(l)) == r),
                else => Value.from_boolean(false),
            },
            .float => |l| switch (right) {
                .integer => |r| Value.from_boolean(l == @as(f64, @floatFromInt(r))),
                .float => |r| Value.from_boolean(l == r),
                else => Value.from_boolean(false),
            },
            .string => |l| switch (right) {
                .string => |r| Value.from_boolean(std.mem.eql(u8, l, r)),
                else => Value.from_boolean(false),
            },
            .boolean => |l| switch (right) {
                .boolean => |r| Value.from_boolean(l == r),
                else => Value.from_boolean(false),
            },
            .null => switch (right) {
                .null => Value.from_boolean(true),
                else => Value.from_boolean(false),
            },
        };
    }

    /// Binary inequality.
    fn binary_ne(self: *Interpreter, left: Value, right: Value) Error!Value {
        const eq_result = try self.binary_eq(left, right);
        return Value.from_boolean(!eq_result.to_boolean());
    }

    /// Binary less than.
    fn binary_lt(self: *Interpreter, left: Value, right: Value) Error!Value {
        _ = self;
        return switch (left) {
            .integer => |l| switch (right) {
                .integer => |r| Value.from_boolean(l < r),
                .float => |r| Value.from_boolean(@as(f64, @floatFromInt(l)) < r),
                else => Error.type_mismatch,
            },
            .float => |l| switch (right) {
                .integer => |r| Value.from_boolean(l < @as(f64, @floatFromInt(r))),
                .float => |r| Value.from_boolean(l < r),
                else => Error.type_mismatch,
            },
            .string => |l| switch (right) {
                .string => |r| Value.from_boolean(std.mem.order(u8, l, r) == .lt),
                else => Error.type_mismatch,
            },
            else => Error.type_mismatch,
        };
    }

    /// Binary less than or equal.
    fn binary_le(self: *Interpreter, left: Value, right: Value) Error!Value {
        const lt_result = try self.binary_lt(left, right);
        const eq_result = try self.binary_eq(left, right);
        return Value.from_boolean(lt_result.to_boolean() or eq_result.to_boolean());
    }

    /// Binary greater than.
    fn binary_gt(self: *Interpreter, left: Value, right: Value) Error!Value {
        const le_result = try self.binary_le(left, right);
        return Value.from_boolean(!le_result.to_boolean());
    }

    /// Binary greater than or equal.
    fn binary_ge(self: *Interpreter, left: Value, right: Value) Error!Value {
        const lt_result = try self.binary_lt(left, right);
        return Value.from_boolean(!lt_result.to_boolean());
    }

    /// Binary logical AND.
    fn binary_and(self: *Interpreter, left: Value, right: Value) Error!Value {
        _ = self;
        const left_bool = left.to_boolean();
        if (!left_bool) {
            return Value.from_boolean(false);
        }
        return Value.from_boolean(right.to_boolean());
    }

    /// Binary logical OR.
    fn binary_or(self: *Interpreter, left: Value, right: Value) Error!Value {
        _ = self;
        const left_bool = left.to_boolean();
        if (left_bool) {
            return Value.from_boolean(true);
        }
        return Value.from_boolean(right.to_boolean());
    }

    /// Evaluate unary expression.
    fn evaluate_unary_expression(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be unary expression
        std.debug.assert(node.node_type == .expr_unary);

        const unary_data = node.data.unary;

        // Evaluate operand
        const operand_node = self.parser.get_node(unary_data.operand) orelse return Error.runtime_error;
        const operand_value = try self.evaluate_expression(operand_node);

        // Perform operation
        return switch (unary_data.operator) {
            .not => Value.from_boolean(!operand_value.to_boolean()),
            .negate => switch (operand_value) {
                .integer => |v| Value.from_integer(-v),
                .float => |v| Value.from_float(-v),
                else => Error.type_mismatch,
            },
        };
    }

    /// Evaluate call expression.
    fn evaluate_call_expression(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be call expression
        std.debug.assert(node.node_type == .expr_call);

        const call_data = node.data.call;

        // Get function name
        const callee_node = self.parser.get_node(call_data.callee) orelse return Error.runtime_error;
        if (callee_node.node_type != .expr_identifier) {
            return Error.runtime_error;
        }
        const function_name = callee_node.data.identifier.name;

        // Find function
        const function = self.find_function(function_name) orelse {
            return Error.function_not_found;
        };

        // Evaluate arguments
        if (call_data.args_len > MAX_CALL_ARGS) {
            return Error.too_many_call_args;
        }

        var args: [MAX_CALL_ARGS]Value = undefined;
        var args_len: u32 = 0;
        var i: u32 = 0;
        while (i < call_data.args_len) : (i += 1) {
            const arg_node_idx = call_data.args[i];
            const arg_node = self.parser.get_node(arg_node_idx) orelse return Error.runtime_error;
            args[args_len] = try self.evaluate_expression(arg_node);
            args_len += 1;
        }

        // Call function (built-in or user-defined)
        if (function.is_builtin) {
            if (function.builtin_handler) |handler| {
                return handler(self, args[0..args_len]);
            } else {
                return Error.runtime_error;
            }
        } else {
            // User-defined function call
            return self.call_user_function(function, args[0..args_len]);
        }
    }

    /// Call user-defined function.
    // 2025-11-24-183000-pst: Active function
    fn call_user_function(self: *Interpreter, function: *const Function, args: []const Value) Error!Value {
        // Assert: Function must be user-defined
        std.debug.assert(!function.is_builtin);
        std.debug.assert(function.body_node != null);

        // Check call stack depth
        if (self.call_stack_len >= MAX_CALL_STACK) {
            return Error.call_stack_overflow;
        }

        // Check argument count matches parameter count
        if (args.len != function.param_count) {
            return Error.invalid_argument;
        }

        // Get function declaration node to access parameters
        const fn_decl_node_idx = self.find_function_decl_node(function.name) orelse return Error.runtime_error;
        const fn_decl_node = self.parser.get_node(fn_decl_node_idx) orelse return Error.runtime_error;
        if (fn_decl_node.node_type != .decl_fn) {
            return Error.runtime_error;
        }
        const fn_decl_data = fn_decl_node.data.fn_decl;

        // Push call frame
        const frame_start = self.call_stack_len;
        self.call_stack[frame_start] = CallFrame{
            .function_name = function.name,
            .return_value = null,
            .local_vars_start = self.variables_len,
            .local_vars_count = 0,
        };
        self.call_stack_len += 1;

        // Create local variables for parameters
        var param_idx: u32 = 0;
        while (param_idx < fn_decl_data.params_len) : (param_idx += 1) {
            const param_node_idx = fn_decl_data.params[param_idx];
            const param_node = self.parser.get_node(param_node_idx) orelse {
                // Clean up call frame
                self.call_stack_len -= 1;
                return Error.runtime_error;
            };

            // Parameter should be identifier (parameter name)
            if (param_node.node_type != .expr_identifier) {
                self.call_stack_len -= 1;
                return Error.runtime_error;
            }

            const param_name = param_node.data.identifier.name;
            const arg_value = args[param_idx];

            // Create local variable for parameter
            if (self.variables_len >= MAX_VARIABLES) {
                self.call_stack_len -= 1;
                return Error.too_many_variables;
            }

            const param_name_copy = try self.allocator.dupe(u8, param_name);
            errdefer self.allocator.free(param_name_copy);

            // Copy argument value (for strings, allocate new copy)
            var param_value = arg_value;
            if (arg_value == .string) {
                param_value = try Value.from_string(self.allocator, arg_value.string);
            }

            self.variables[self.variables_len] = Variable{
                .name = param_name_copy,
                .name_len = @as(u32, @intCast(param_name_copy.len)),
                .value = param_value,
                .is_const = false,
                .scope = .local,
                .scope_depth = self.scope_depth + 1,
                .var_type = null,
            };
            self.variables_len += 1;
            self.call_stack[frame_start].local_vars_count += 1;
        }

        // Increment scope depth
        const old_scope_depth = self.scope_depth;
        self.scope_depth += 1;

        // Execute function body
        const body_node_idx = function.body_node.?;
        const body_node = self.parser.get_node(body_node_idx) orelse {
            // Clean up
            self.cleanup_call_frame(frame_start);
            self.scope_depth = old_scope_depth;
            return Error.runtime_error;
        };

        // Execute function body
        if (body_node.node_type == .stmt_block) {
            // Execute block (may contain return statement)
            _ = self.execute_block_statement(body_node) catch |err| {
                // Clean up on error
                self.cleanup_call_frame(frame_start);
                self.scope_depth = old_scope_depth;
                return err;
            };
        } else {
            // Single statement body (could be return statement)
            _ = self.execute_statement(body_node) catch |err| {
                self.cleanup_call_frame(frame_start);
                self.scope_depth = old_scope_depth;
                return err;
            };
        }

        // Restore scope depth
        self.scope_depth = old_scope_depth;

        // Get return value from call frame (if set by return statement)
        // Must get before cleanup (cleanup pops frame)
        const frame_return = if (frame_start < self.call_stack_len) self.call_stack[frame_start].return_value else null;

        // Clean up call frame (free local variables)
        self.cleanup_call_frame(frame_start);

        // Return value (or null if no return statement)
        if (frame_return) |val| {
            // Copy return value (for strings, allocate new copy)
            if (val == .string) {
                return try Value.from_string(self.allocator, val.string);
            } else {
                return val;
            }
        } else {
            return Value.from_null();
        }
    }

    /// Find function declaration node by name.
    // 2025-11-24-183000-pst: Active function
    fn find_function_decl_node(self: *const Interpreter, name: []const u8) ?u32 {
        // Search through parser nodes for function declaration
        var i: u32 = 0;
        while (i < self.parser.get_node_count()) : (i += 1) {
            const node = self.parser.get_node(i) orelse continue;
            if (node.node_type == .decl_fn) {
                const fn_decl_data = node.data.fn_decl;
                if (std.mem.eql(u8, fn_decl_data.name, name)) {
                    return i;
                }
            }
        }
        return null;
    }

    /// Clean up call frame (free local variables, but preserve return value).
    // 2025-11-24-183000-pst: Active function
    fn cleanup_call_frame(self: *Interpreter, frame_idx: u32) void {
        std.debug.assert(frame_idx < self.call_stack_len);
        const frame = &self.call_stack[frame_idx];

        // Free local variables
        var i: u32 = 0;
        while (i < frame.local_vars_count) : (i += 1) {
            const var_idx = frame.local_vars_start + i;
            if (var_idx < self.variables_len) {
                const variable = &self.variables[var_idx];
                // Free variable name
                self.allocator.free(variable.name);
                // Free variable value (if string)
                variable.value.deinit(self.allocator);
            }
        }

        // Remove variables from array (shift remaining variables)
        const vars_to_remove = frame.local_vars_count;
        if (vars_to_remove > 0 and frame.local_vars_start + vars_to_remove < self.variables_len) {
            const remaining_count = self.variables_len - (frame.local_vars_start + vars_to_remove);
            var j: u32 = 0;
            while (j < remaining_count) : (j += 1) {
                const src_idx = frame.local_vars_start + vars_to_remove + j;
                const dst_idx = frame.local_vars_start + j;
                self.variables[dst_idx] = self.variables[src_idx];
            }
        }
        self.variables_len -= vars_to_remove;

        // Note: return_value is preserved in frame until caller uses it
        // Pop call frame (return_value will be copied by caller if needed)
        self.call_stack_len -= 1;
    }

    /// Evaluate group expression.
    fn evaluate_group_expression(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be group expression
        std.debug.assert(node.node_type == .expr_group);

        const group_data = node.data.group;

        // Evaluate inner expression
        const expr_node = self.parser.get_node(group_data.expr) orelse return Error.runtime_error;
        return self.evaluate_expression(expr_node);
    }

    /// Evaluate assignment expression.
    fn evaluate_assign_expression(self: *Interpreter, node: Parser.Node) Error!Value {
        // Assert: Node must be assignment expression
        std.debug.assert(node.node_type == .expr_assign);

        const assign_data = node.data.assign;

        // Get target identifier
        const target_node = self.parser.get_node(assign_data.target) orelse return Error.runtime_error;
        if (target_node.node_type != .expr_identifier) {
            return Error.runtime_error;
        }
        const target_name = target_node.data.identifier.name;

        // Find variable (must exist)
        const variable = self.find_variable(target_name) orelse {
            return Error.variable_not_found;
        };

        // Check if constant (cannot assign to constants)
        if (variable.is_const) {
            return Error.runtime_error; // Cannot assign to constant
        }

        // Evaluate value expression
        const value_node = self.parser.get_node(assign_data.value) orelse return Error.runtime_error;
        const new_value = try self.evaluate_expression(value_node);

        // Type checking: check against declared type or existing value type
        if (variable.var_type) |var_type| {
            // Check against declared/inferred type
            const type_name = var_type.type_name;
            if (!self.value_matches_type(new_value, type_name)) {
                return Error.type_mismatch;
            }
        } else if (variable.value != .null) {
            // Fallback: check type compatibility with existing value
            if (!self.types_compatible(variable.value, new_value)) {
                return Error.type_mismatch;
            }
        }

        // Free old value (if string)
        variable.value.deinit(self.allocator);

        // Assign new value (copy for strings)
        const assigned_value = switch (new_value) {
            .integer => |v| Value.from_integer(v),
            .float => |v| Value.from_float(v),
            .string => |v| blk: {
                // Copy string value
                break :blk try Value.from_string(self.allocator, v);
            },
            .boolean => |v| Value.from_boolean(v),
            .null => Value.from_null(),
        };

        variable.value = assigned_value;

        // Return the assigned value (copy for strings)
        return switch (assigned_value) {
            .integer => |v| Value.from_integer(v),
            .float => |v| Value.from_float(v),
            .string => |v| blk: {
                // Copy string value for return
                break :blk try Value.from_string(self.allocator, v);
            },
            .boolean => |v| Value.from_boolean(v),
            .null => Value.from_null(),
        };
    }

    /// Check if two value types are compatible.
    fn types_compatible(self: *const Interpreter, old: Value, new: Value) bool {
        _ = self;
        // Same type is always compatible
        if (@as(ValueType, old) == @as(ValueType, new)) {
            return true;
        }

        // Integer and float are compatible (numeric)
        return switch (old) {
            .integer => switch (new) {
                .float => true,
                else => false,
            },
            .float => switch (new) {
                .integer => true,
                else => false,
            },
            else => false,
        };
    }

    /// Infer type name from value.
    fn infer_type_from_value(self: *const Interpreter, value: Value) Error![]const u8 {
        _ = self;
        return switch (value) {
            .integer => "i64",
            .float => "f64",
            .string => "string",
            .boolean => "bool",
            .null => "null",
        };
    }

    /// Check if value matches type name.
    fn value_matches_type(self: *const Interpreter, value: Value, type_name: []const u8) bool {
        _ = self;
        // Type name matching (case-sensitive)
        return switch (value) {
            .integer => std.mem.eql(u8, type_name, "i32") or std.mem.eql(u8, type_name, "i64") or std.mem.eql(u8, type_name, "int"),
            .float => std.mem.eql(u8, type_name, "f32") or std.mem.eql(u8, type_name, "f64") or std.mem.eql(u8, type_name, "float"),
            .string => std.mem.eql(u8, type_name, "string") or std.mem.eql(u8, type_name, "str"),
            .boolean => std.mem.eql(u8, type_name, "bool") or std.mem.eql(u8, type_name, "boolean"),
            .null => std.mem.eql(u8, type_name, "null") or std.mem.eql(u8, type_name, "void"),
        };
    }

    /// Find variable by name (with scope resolution).
    fn find_variable(self: *const Interpreter, name: []const u8) ?*Variable {
        // Search from most recent to oldest (local to global)
        var i: u32 = self.variables_len;
        while (i > 0) {
            i -= 1;
            const variable = &self.variables[i];
            if (std.mem.eql(u8, variable.name, name)) {
                // Check if variable is in accessible scope
                if (variable.scope_depth <= self.scope_depth) {
                    return variable;
                }
            }
        }
        return null;
    }

    /// Find function by name.
    fn find_function(self: *const Interpreter, name: []const u8) ?*Function {
        var i: u32 = 0;
        while (i < self.functions_len) : (i += 1) {
            if (std.mem.eql(u8, self.functions[i].name, name)) {
                return &self.functions[i];
            }
        }
        return null;
    }

    /// Get exit code.
    pub fn get_exit_code(self: *const Interpreter) u32 {
        return self.exit_code;
    }
};

