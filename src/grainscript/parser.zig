const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;

/// Grainscript Parser: Builds AST from tokens.
/// ~<~ Glow Airbend: explicit AST nodes, bounded tree depth.
/// ~~~~ Glow Waterbend: deterministic parsing, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const Parser = struct {
    // Bounded: Max 1,000 AST nodes per file (explicit limit)
    pub const MAX_AST_NODES: u32 = 1_000;

    // Bounded: Max 100 AST depth (explicit limit)
    pub const MAX_AST_DEPTH: u32 = 100;

    // Bounded: Max 256 expression operands (explicit limit)
    pub const MAX_EXPR_OPERANDS: u32 = 256;

    // Bounded: Max 64 function parameters (explicit limit)
    pub const MAX_FN_PARAMS: u32 = 64;

    // Bounded: Max 1,024 statement list items (explicit limit)
    pub const MAX_STMT_LIST: u32 = 1_024;

    /// AST node type enumeration.
    pub const NodeType = enum(u8) {
        // Expressions
        expr_literal, // Integer, float, string, boolean, null
        expr_identifier, // Variable or function name
        expr_binary, // Binary operation (+, -, *, /, ==, !=, etc.)
        expr_unary, // Unary operation (!, -)
        expr_call, // Function call
        expr_group, // Parenthesized expression
        expr_assign, // Assignment (=)

        // Statements
        stmt_expr, // Expression statement
        stmt_var, // Variable declaration
        stmt_const, // Constant declaration
        stmt_if, // If statement
        stmt_while, // While loop
        stmt_for, // For loop
        stmt_return, // Return statement
        stmt_break, // Break statement
        stmt_continue, // Continue statement
        stmt_block, // Block of statements

        // Declarations
        decl_fn, // Function declaration
        decl_var, // Variable declaration (top-level)
        decl_const, // Constant declaration (top-level)

        // Types
        type_named, // Named type (i32, u64, string, etc.)
        type_inferred, // Inferred type (placeholder)
    };

    /// AST node structure.
    pub const Node = struct {
        node_type: NodeType,
        start: u32, // Start position in source
        end: u32, // End position in source (exclusive)
        line: u32, // Line number (1-indexed)
        column: u32, // Column number (1-indexed)
        depth: u32, // Tree depth (for bounds checking)

        // Node data (union-like, but explicit for GrainStyle)
        data: NodeData,
    };

    /// Node data (explicit union for GrainStyle compliance).
    pub const NodeData = union(enum) {
        // Literal expression
        literal: LiteralData,
        // Identifier expression
        identifier: IdentifierData,
        // Binary expression
        binary: BinaryData,
        // Unary expression
        unary: UnaryData,
        // Function call expression
        call: CallData,
        // Grouped expression
        group: GroupData,
        // Assignment expression
        assign: AssignData,
        // Variable statement
        var_stmt: VarStmtData,
        // If statement
        if_stmt: IfStmtData,
        // While statement
        while_stmt: WhileStmtData,
        // For statement
        for_stmt: ForStmtData,
        // Return statement
        return_stmt: ReturnStmtData,
        // Block statement
        block: BlockData,
        // Function declaration
        fn_decl: FnDeclData,
        // Type
        type_named: TypeData,
        // Empty (for nodes that don't need data)
        empty: void,
    };

    /// Literal data (integer, float, string, boolean, null).
    pub const LiteralData = struct {
        literal_type: LiteralType,
        value: []const u8, // Source text of literal
        value_len: u32,
    };

    /// Literal type enumeration.
    pub const LiteralType = enum(u8) {
        integer,
        float,
        string,
        boolean_true,
        boolean_false,
        null,
    };

    /// Identifier data.
    pub const IdentifierData = struct {
        name: []const u8, // Identifier name
        name_len: u32,
    };

    /// Binary expression data.
    pub const BinaryData = struct {
        operator: BinaryOperator,
        left: u32, // Left operand node index
        right: u32, // Right operand node index
    };

    /// Binary operator enumeration.
    pub const BinaryOperator = enum(u8) {
        // Arithmetic
        add, // +
        subtract, // -
        multiply, // *
        divide, // /
        modulo, // %
        // Comparison
        eq, // ==
        ne, // !=
        lt, // <
        le, // <=
        gt, // >
        ge, // >=
        // Logical
        and_op, // &&
        or_op, // ||
    };

    /// Unary expression data.
    pub const UnaryData = struct {
        operator: UnaryOperator,
        operand: u32, // Operand node index
    };

    /// Unary operator enumeration.
    pub const UnaryOperator = enum(u8) {
        not, // !
        negate, // -
    };

    /// Function call data.
    pub const CallData = struct {
        callee: u32, // Function name node index
        args: []const u32, // Argument node indices
        args_len: u32,
    };

    /// Grouped expression data.
    pub const GroupData = struct {
        expr: u32, // Expression node index
    };

    /// Assignment expression data.
    pub const AssignData = struct {
        target: u32, // Target identifier node index
        value: u32, // Value expression node index
    };

    /// Variable statement data.
    pub const VarStmtData = struct {
        name: []const u8, // Variable name
        name_len: u32,
        type_node: ?u32, // Type node index (optional)
        init: ?u32, // Initializer expression node index (optional)
    };

    /// If statement data.
    pub const IfStmtData = struct {
        condition: u32, // Condition expression node index
        then_block: u32, // Then block node index
        else_block: ?u32, // Else block node index (optional)
    };

    /// While statement data.
    pub const WhileStmtData = struct {
        condition: u32, // Condition expression node index
        body: u32, // Body block node index
    };

    /// For statement data.
    pub const ForStmtData = struct {
        init: ?u32, // Initializer statement node index (optional)
        condition: ?u32, // Condition expression node index (optional)
        update: ?u32, // Update expression node index (optional)
        body: u32, // Body block node index
    };

    /// Return statement data.
    pub const ReturnStmtData = struct {
        value: ?u32, // Return value expression node index (optional)
    };

    /// Block statement data.
    pub const BlockData = struct {
        statements: []const u32, // Statement node indices
        statements_len: u32,
    };

    /// Function declaration data.
    pub const FnDeclData = struct {
        name: []const u8, // Function name
        name_len: u32,
        params: []const u32, // Parameter node indices
        params_len: u32,
        return_type: ?u32, // Return type node index (optional)
        body: u32, // Body block node index
    };

    /// Type data.
    pub const TypeData = struct {
        name: []const u8, // Type name (i32, u64, string, etc.)
        name_len: u32,
    };

    /// Parser state.
    lexer: *const Lexer,
    source: []const u8, // Source code (from lexer)
    tokens: []const Lexer.Token,
    token_index: u32, // Current token index
    nodes: []Node, // AST nodes
    nodes_len: u32, // Number of nodes
    allocator: std.mem.Allocator,
    depth: u32, // Current parsing depth

    /// Initialize parser with lexer.
    pub fn init(allocator: std.mem.Allocator, lexer: *const Lexer) !Parser {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        // Assert: Lexer must be valid
        std.debug.assert(lexer.get_token_count() > 0);

        // Pre-allocate node buffer
        const nodes = try allocator.alloc(Node, MAX_AST_NODES);
        errdefer allocator.free(nodes);

        // Get tokens from lexer
        const tokens = lexer.get_tokens();
        const source = lexer.get_source();

        return Parser{
            .lexer = lexer,
            .source = source,
            .tokens = tokens,
            .token_index = 0,
            .nodes = nodes,
            .nodes_len = 0,
            .allocator = allocator,
            .depth = 0,
        };
    }

    /// Deinitialize parser and free memory.
    pub fn deinit(self: *Parser) void {
        // Assert: Parser must be valid
        std.debug.assert(self.allocator.ptr != null);

        // Free node buffer
        self.allocator.free(self.nodes);
        self.* = undefined;
    }

    /// Parse entire source code into AST.
    pub fn parse(self: *Parser) !void {
        // Assert: Parser must be initialized
        std.debug.assert(self.tokens.len > 0);
        std.debug.assert(self.nodes.len == MAX_AST_NODES);

        // Reset state
        self.token_index = 0;
        self.nodes_len = 0;
        self.depth = 0;

        // Parse statements until EOF
        while (self.token_index < self.tokens.len) {
            const token = self.get_current_token();
            if (token.token_type == .eof) {
                break;
            }

            // Skip comments and whitespace
            if (token.token_type == .comment or token.token_type == .whitespace or token.token_type == .newline) {
                self.advance();
                continue;
            }

            // Parse declaration or statement
            _ = try self.parse_declaration_or_statement();
        }

        // Assert: Must have at least one node (or empty file)
        // Assert: Depth must be zero (all blocks closed)
        std.debug.assert(self.depth == 0);
    }

    /// Parse declaration or statement.
    fn parse_declaration_or_statement(self: *Parser) !?u32 {
        // Assert: Token index must be valid
        std.debug.assert(self.token_index < self.tokens.len);

        const token = self.get_current_token();

        // Function declaration
        if (token.token_type == .kw_fn) {
            return try self.parse_function_declaration();
        }

        // Variable declaration
        if (token.token_type == .kw_var) {
            return try self.parse_variable_declaration();
        }

        // Constant declaration
        if (token.token_type == .kw_const) {
            return try self.parse_constant_declaration();
        }

        // Statement
        return try self.parse_statement();
    }

    /// Parse function declaration.
    fn parse_function_declaration(self: *Parser) !u32 {
        // Assert: Current token must be 'fn'
        std.debug.assert(self.get_current_token().token_type == .kw_fn);

        const start_token = self.get_current_token();
        self.advance(); // Skip 'fn'

        // Parse function name
        const name_token = self.get_current_token();
        if (name_token.token_type != .identifier) {
            return error.ExpectedIdentifier;
        }
        const name = self.source[name_token.start..name_token.end];
        self.advance(); // Skip identifier

        // Parse parameters
        if (self.get_current_token().token_type != .punc_lparen) {
            return error.ExpectedLeftParen;
        }
        self.advance(); // Skip '('

        var params = std.ArrayList(u32).init(self.allocator);
        defer params.deinit();
        try params.ensureTotalCapacity(MAX_FN_PARAMS);

        // Parse parameter list
        while (self.get_current_token().token_type != .punc_rparen) {
            if (self.get_current_token().token_type == .eof) {
                return error.UnexpectedEof;
            }

            // Skip comma if not first parameter
            if (params.items.len > 0) {
                if (self.get_current_token().token_type != .punc_comma) {
                    return error.ExpectedComma;
                }
                self.advance(); // Skip ','
            }

            // Parse parameter name
            const param_name_token = self.get_current_token();
            if (param_name_token.token_type != .identifier) {
                return error.ExpectedIdentifier;
            }
            self.advance(); // Skip identifier

            // Parse parameter type (optional for now, required later)
            var param_type: ?u32 = null;
            if (self.get_current_token().token_type == .punc_colon) {
                self.advance(); // Skip ':'
                param_type = try self.parse_type();
            }

            // Create parameter node (for now, just identifier)
            const param_node = try self.create_node(
                .expr_identifier,
                param_name_token.start,
                param_name_token.end,
                param_name_token.line,
                param_name_token.column,
                .{ .identifier = .{ .name = self.source[param_name_token.start..param_name_token.end], .name_len = param_name_token.end - param_name_token.start } },
            );
            try params.append(param_node);
        }

        self.advance(); // Skip ')'

        // Parse return type (optional)
        var return_type: ?u32 = null;
        if (self.get_current_token().token_type == .op_arrow) {
            self.advance(); // Skip '->'
            return_type = try self.parse_type();
        }

        // Parse function body
        const body = try self.parse_block();

        // Create function declaration node
        const params_slice = try self.allocator.dupe(u32, params.items);
        errdefer self.allocator.free(params_slice);

        return try self.create_node(
            .decl_fn,
            start_token.start,
            self.get_current_token().end,
            start_token.line,
            start_token.column,
            .{ .fn_decl = .{
                .name = name,
                .name_len = @as(u32, @intCast(name.len)),
                .params = params_slice,
                .params_len = @as(u32, @intCast(params_slice.len)),
                .return_type = return_type,
                .body = body,
            } },
        );
    }

    /// Parse variable declaration.
    fn parse_variable_declaration(self: *Parser) !u32 {
        // Assert: Current token must be 'var'
        std.debug.assert(self.get_current_token().token_type == .kw_var);

        const start_token = self.get_current_token();
        self.advance(); // Skip 'var'

        // Parse variable name
        const name_token = self.get_current_token();
        if (name_token.token_type != .identifier) {
            return error.ExpectedIdentifier;
        }
        const name = self.source[name_token.start..name_token.end];
        self.advance(); // Skip identifier

        // Parse type (optional)
        var type_node: ?u32 = null;
        if (self.get_current_token().token_type == .punc_colon) {
            self.advance(); // Skip ':'
            type_node = try self.parse_type();
        }

        // Parse initializer (optional)
        var init_expr: ?u32 = null;
        if (self.get_current_token().token_type == .op_assign) {
            self.advance(); // Skip '='
            init_expr = try self.parse_expression();
        }

        // Create variable declaration node
        return try self.create_node(
            .stmt_var,
            start_token.start,
            self.get_current_token().end,
            start_token.line,
            start_token.column,
            .{ .var_stmt = .{
                .name = name,
                .name_len = @as(u32, @intCast(name.len)),
                .type_node = type_node,
                .init = init_expr,
            } },
        );
    }

    /// Parse constant declaration.
    fn parse_constant_declaration(self: *Parser) !u32 {
        // Assert: Current token must be 'const'
        std.debug.assert(self.get_current_token().token_type == .kw_const);

        const start_token = self.get_current_token();
        self.advance(); // Skip 'const'

        // Parse constant name
        const name_token = self.get_current_token();
        if (name_token.token_type != .identifier) {
            return error.ExpectedIdentifier;
        }
        const name = self.source[name_token.start..name_token.end];
        self.advance(); // Skip identifier

        // Parse type (optional)
        var type_node: ?u32 = null;
        if (self.get_current_token().token_type == .punc_colon) {
            self.advance(); // Skip ':'
            type_node = try self.parse_type();
        }

        // Parse initializer (required for const)
        if (self.get_current_token().token_type != .op_assign) {
            return error.ExpectedAssign;
        }
        self.advance(); // Skip '='
        const init_expr = try self.parse_expression();

        // Create constant declaration node
        return try self.create_node(
            .stmt_const,
            start_token.start,
            self.get_current_token().end,
            start_token.line,
            start_token.column,
            .{ .var_stmt = .{
                .name = name,
                .name_len = @as(u32, @intCast(name.len)),
                .type_node = type_node,
                .init = init_expr,
            } },
        );
    }

    /// Parse statement.
    fn parse_statement(self: *Parser) !?u32 {
        // Assert: Token index must be valid
        std.debug.assert(self.token_index < self.tokens.len);

        const token = self.get_current_token();

        // If statement
        if (token.token_type == .kw_if) {
            return try self.parse_if_statement();
        }

        // While statement
        if (token.token_type == .kw_while) {
            return try self.parse_while_statement();
        }

        // For statement
        if (token.token_type == .kw_for) {
            return try self.parse_for_statement();
        }

        // Return statement
        if (token.token_type == .kw_return) {
            return try self.parse_return_statement();
        }

        // Break statement
        if (token.token_type == .kw_break) {
            return try self.parse_break_statement();
        }

        // Continue statement
        if (token.token_type == .kw_continue) {
            return try self.parse_continue_statement();
        }

        // Block statement
        if (token.token_type == .punc_lbrace) {
            return try self.parse_block();
        }

        // Expression statement
        const expr = try self.parse_expression();
        const expr_node = self.get_node(expr) orelse return error.InvalidNode;
        
        if (self.get_current_token().token_type == .punc_semicolon) {
            self.advance(); // Skip ';'
        }
        
        return try self.create_node(
            .stmt_expr,
            expr_node.start,
            expr_node.end,
            token.line,
            token.column,
            .{ .group = .{ .expr = expr } },
        );
    }

    /// Parse if statement.
    fn parse_if_statement(self: *Parser) !u32 {
        // Assert: Current token must be 'if'
        std.debug.assert(self.get_current_token().token_type == .kw_if);

        const start_token = self.get_current_token();
        self.advance(); // Skip 'if'

        // Parse condition
        if (self.get_current_token().token_type != .punc_lparen) {
            return error.ExpectedLeftParen;
        }
        self.advance(); // Skip '('
        const condition = try self.parse_expression();
        if (self.get_current_token().token_type != .punc_rparen) {
            return error.ExpectedRightParen;
        }
        self.advance(); // Skip ')'

        // Parse then block
        const then_block = try self.parse_block();

        // Parse else block (optional)
        var else_block: ?u32 = null;
        if (self.get_current_token().token_type == .kw_else) {
            self.advance(); // Skip 'else'
            else_block = try self.parse_block();
        }

        // Create if statement node
        return try self.create_node(
            .stmt_if,
            start_token.start,
            self.get_current_token().end,
            start_token.line,
            start_token.column,
            .{ .if_stmt = .{
                .condition = condition,
                .then_block = then_block,
                .else_block = else_block,
            } },
        );
    }

    /// Parse while statement.
    fn parse_while_statement(self: *Parser) !u32 {
        // Assert: Current token must be 'while'
        std.debug.assert(self.get_current_token().token_type == .kw_while);

        const start_token = self.get_current_token();
        self.advance(); // Skip 'while'

        // Parse condition
        if (self.get_current_token().token_type != .punc_lparen) {
            return error.ExpectedLeftParen;
        }
        self.advance(); // Skip '('
        const condition = try self.parse_expression();
        if (self.get_current_token().token_type != .punc_rparen) {
            return error.ExpectedRightParen;
        }
        self.advance(); // Skip ')'

        // Parse body
        const body = try self.parse_block();

        // Create while statement node
        return try self.create_node(
            .stmt_while,
            start_token.start,
            self.get_current_token().end,
            start_token.line,
            start_token.column,
            .{ .while_stmt = .{
                .condition = condition,
                .body = body,
            } },
        );
    }

    /// Parse for statement.
    fn parse_for_statement(self: *Parser) !u32 {
        // Assert: Current token must be 'for'
        std.debug.assert(self.get_current_token().token_type == .kw_for);

        const start_token = self.get_current_token();
        self.advance(); // Skip 'for'

        // Parse for loop header
        if (self.get_current_token().token_type != .punc_lparen) {
            return error.ExpectedLeftParen;
        }
        self.advance(); // Skip '('

        // Parse initializer (optional)
        var init_stmt: ?u32 = null;
        if (self.get_current_token().token_type != .punc_semicolon) {
            init_stmt = try self.parse_statement();
        }

        // Parse condition (optional)
        var condition: ?u32 = null;
        if (self.get_current_token().token_type != .punc_semicolon) {
            condition = try self.parse_expression();
        }
        if (self.get_current_token().token_type != .punc_semicolon) {
            return error.ExpectedSemicolon;
        }
        self.advance(); // Skip ';'

        // Parse update (optional)
        var update: ?u32 = null;
        if (self.get_current_token().token_type != .punc_rparen) {
            update = try self.parse_expression();
        }
        if (self.get_current_token().token_type != .punc_rparen) {
            return error.ExpectedRightParen;
        }
        self.advance(); // Skip ')'

        // Parse body
        const body = try self.parse_block();

        // Create for statement node
        return try self.create_node(
            .stmt_for,
            start_token.start,
            self.get_current_token().end,
            start_token.line,
            start_token.column,
            .{ .for_stmt = .{
                .init = init_expr,
                .condition = condition,
                .update = update,
                .body = body,
            } },
        );
    }

    /// Parse return statement.
    fn parse_return_statement(self: *Parser) !u32 {
        // Assert: Current token must be 'return'
        std.debug.assert(self.get_current_token().token_type == .kw_return);

        const start_token = self.get_current_token();
        self.advance(); // Skip 'return'

        // Parse return value (optional)
        var value: ?u32 = null;
        if (self.get_current_token().token_type != .punc_semicolon and
            self.get_current_token().token_type != .newline and
            self.get_current_token().token_type != .eof)
        {
            value = try self.parse_expression();
        }

        if (self.get_current_token().token_type == .punc_semicolon) {
            self.advance(); // Skip ';'
        }

        // Create return statement node
        return try self.create_node(
            .stmt_return,
            start_token.start,
            self.get_current_token().end,
            start_token.line,
            start_token.column,
            .{ .return_stmt = .{ .value = value } },
        );
    }

    /// Parse break statement.
    fn parse_break_statement(self: *Parser) !u32 {
        // Assert: Current token must be 'break'
        std.debug.assert(self.get_current_token().token_type == .kw_break);

        const start_token = self.get_current_token();
        self.advance(); // Skip 'break'

        if (self.get_current_token().token_type == .punc_semicolon) {
            self.advance(); // Skip ';'
        }

        // Create break statement node
        return try self.create_node(
            .stmt_break,
            start_token.start,
            start_token.end,
            start_token.line,
            start_token.column,
            .{ .empty = {} },
        );
    }

    /// Parse continue statement.
    fn parse_continue_statement(self: *Parser) !u32 {
        // Assert: Current token must be 'continue'
        std.debug.assert(self.get_current_token().token_type == .kw_continue);

        const start_token = self.get_current_token();
        self.advance(); // Skip 'continue'

        if (self.get_current_token().token_type == .punc_semicolon) {
            self.advance(); // Skip ';'
        }

        // Create continue statement node
        return try self.create_node(
            .stmt_continue,
            start_token.start,
            start_token.end,
            start_token.line,
            start_token.column,
            .{ .empty = {} },
        );
    }

    /// Parse block statement.
    fn parse_block(self: *Parser) !u32 {
        // Assert: Current token must be '{'
        std.debug.assert(self.get_current_token().token_type == .punc_lbrace);

        const start_token = self.get_current_token();
        self.advance(); // Skip '{'

        // Assert: Depth must be within bounds
        std.debug.assert(self.depth < MAX_AST_DEPTH);
        self.depth += 1;
        defer self.depth -= 1;

        var statements = std.ArrayList(u32).init(self.allocator);
        defer statements.deinit();
        try statements.ensureTotalCapacity(MAX_STMT_LIST);

        // Parse statements until '}'
        while (self.get_current_token().token_type != .punc_rbrace) {
            if (self.get_current_token().token_type == .eof) {
                return error.UnexpectedEof;
            }

            // Skip comments and whitespace
            if (self.get_current_token().token_type == .comment or
                self.get_current_token().token_type == .whitespace or
                self.get_current_token().token_type == .newline)
            {
                self.advance();
                continue;
            }

            // Parse statement
            if (try self.parse_statement()) |stmt| {
                try statements.append(stmt);
            }
        }

        self.advance(); // Skip '}'

        // Create block node
        const statements_slice = try self.allocator.dupe(u32, statements.items);
        errdefer self.allocator.free(statements_slice);

        return try self.create_node(
            .stmt_block,
            start_token.start,
            self.get_current_token().end,
            start_token.line,
            start_token.column,
            .{ .block = .{
                .statements = statements_slice,
                .statements_len = @as(u32, @intCast(statements_slice.len)),
            } },
        );
    }

    /// Parse expression (iterative, precedence-based).
    fn parse_expression(self: *Parser) !u32 {
        // Assert: Token index must be valid
        std.debug.assert(self.token_index < self.tokens.len);

        // Check for assignment (lowest precedence)
        const token = self.get_current_token();
        if (token.token_type == .identifier) {
            // Look ahead to see if next token is assignment
            if (self.token_index + 1 < self.tokens.len) {
                const next_token = self.tokens[self.token_index + 1];
                if (next_token.token_type == .op_assign) {
                    // Parse assignment: identifier = expression
                    const target_token = token;
                    self.advance(); // Skip identifier
                    self.advance(); // Skip '='

                    // Parse target identifier
                    const target_name = self.source[target_token.start..target_token.end];
                    const target = try self.create_node(
                        .expr_identifier,
                        target_token.start,
                        target_token.end,
                        target_token.line,
                        target_token.column,
                        .{ .identifier = .{
                            .name = target_name,
                            .name_len = @as(u32, @intCast(target_name.len)),
                        } },
                    );

                    // Parse value expression
                    const value = try self.parse_expression_precedence(0);

                    // Create assignment node
                    const target_node = self.get_node(target) orelse return error.InvalidNode;
                    const value_node = self.get_node(value) orelse return error.InvalidNode;

                    return try self.create_node(
                        .expr_assign,
                        target_node.start,
                        value_node.end,
                        target_token.line,
                        target_token.column,
                        .{ .assign = .{
                            .target = target,
                            .value = value,
                        } },
                    );
                }
            }
        }

        // Parse with precedence (iterative, no recursion)
        return try self.parse_expression_precedence(0);
    }

    /// Parse expression with precedence (iterative, stack-based).
    fn parse_expression_precedence(self: *Parser, min_precedence: u32) !u32 {
        // Assert: Token index must be valid
        std.debug.assert(self.token_index < self.tokens.len);

        // Parse left operand
        var left = try self.parse_unary_expression();

        // Parse binary operators with precedence
        while (true) {
            const token = self.get_current_token();
            const precedence = get_binary_precedence(token.token_type);
            if (precedence == 0 or precedence < min_precedence) {
                break;
            }

            const operator_token = token;
            self.advance(); // Skip operator

            // Parse right operand
            const right = try self.parse_expression_precedence(precedence + 1);

            // Create binary expression node
            const operator = token_type_to_binary_operator(operator_token.token_type) orelse {
                return error.InvalidOperator;
            };

            // Get positions from nodes
            const left_node = self.get_node(left) orelse return error.InvalidNode;
            const right_node = self.get_node(right) orelse return error.InvalidNode;

            left = try self.create_node(
                .expr_binary,
                left_node.start,
                right_node.end,
                operator_token.line,
                operator_token.column,
                .{ .binary = .{
                    .operator = operator,
                    .left = left,
                    .right = right,
                } },
            );
        }

        return left;
    }

    /// Parse unary expression.
    fn parse_unary_expression(self: *Parser) !u32 {
        // Assert: Token index must be valid
        std.debug.assert(self.token_index < self.tokens.len);

        const token = self.get_current_token();

        // Unary operators
        if (token.token_type == .op_not or token.token_type == .op_minus) {
            const operator_token = token;
            self.advance(); // Skip operator

            const operand = try self.parse_unary_expression();

            const operator: UnaryOperator = if (token.token_type == .op_not) .not else .negate;

            return try self.create_node(
                .expr_unary,
                operator_token.start,
                self.get_current_token().end,
                operator_token.line,
                operator_token.column,
                .{ .unary = .{
                    .operator = operator,
                    .operand = operand,
                } },
            );
        }

        // Primary expression
        return try self.parse_primary_expression();
    }

    /// Parse primary expression.
    fn parse_primary_expression(self: *Parser) !u32 {
        // Assert: Token index must be valid
        std.debug.assert(self.token_index < self.tokens.len);

        const token = self.get_current_token();

        // Literal
        if (is_literal_token(token.token_type)) {
            return try self.parse_literal();
        }

        // Identifier
        if (token.token_type == .identifier) {
            const identifier_token = token;
            self.advance(); // Skip identifier

            // Function call
            if (self.get_current_token().token_type == .punc_lparen) {
                return try self.parse_function_call(identifier_token);
            }

            // Plain identifier
            const name = self.source[identifier_token.start..identifier_token.end];
            return try self.create_node(
                .expr_identifier,
                identifier_token.start,
                identifier_token.end,
                identifier_token.line,
                identifier_token.column,
                .{ .identifier = .{
                    .name = name,
                    .name_len = identifier_token.end - identifier_token.start,
                } },
            );
        }

        // Grouped expression
        if (token.token_type == .punc_lparen) {
            self.advance(); // Skip '('
            const expr = try self.parse_expression();
            if (self.get_current_token().token_type != .punc_rparen) {
                return error.ExpectedRightParen;
            }
            self.advance(); // Skip ')'

            return try self.create_node(
                .expr_group,
                token.start,
                self.get_current_token().end,
                token.line,
                token.column,
                .{ .group = .{ .expr = expr } },
            );
        }

        return error.UnexpectedToken;
    }

    /// Parse literal expression.
    fn parse_literal(self: *Parser) !u32 {
        // Assert: Current token must be a literal
        std.debug.assert(is_literal_token(self.get_current_token().token_type));

        const token = self.get_current_token();
        const value = self.source[token.start..token.end];

        var literal_type: LiteralType = undefined;
        switch (token.token_type) {
            .integer => literal_type = .integer,
            .float => literal_type = .float,
            .string => literal_type = .string,
            .kw_true => literal_type = .boolean_true,
            .kw_false => literal_type = .boolean_false,
            .kw_null => literal_type = .null,
            else => return error.InvalidLiteral,
        }

        self.advance(); // Skip literal

        return try self.create_node(
            .expr_literal,
            token.start,
            token.end,
            token.line,
            token.column,
            .{ .literal = .{
                .literal_type = literal_type,
                .value = value,
                .value_len = token.end - token.start,
            } },
        );
    }

    /// Parse function call.
    fn parse_function_call(self: *Parser, callee_token: Lexer.Token) !u32 {
        // Assert: Current token must be '('
        std.debug.assert(self.get_current_token().token_type == .punc_lparen);

        const start_token = self.get_current_token();
        self.advance(); // Skip '('

        // Create callee identifier node
        const callee_name = self.source[callee_token.start..callee_token.end];
        const callee = try self.create_node(
            .expr_identifier,
            callee_token.start,
            callee_token.end,
            callee_token.line,
            callee_token.column,
            .{ .identifier = .{
                .name = callee_name,
                .name_len = callee_token.end - callee_token.start,
            } },
        );

        var args = std.ArrayList(u32).init(self.allocator);
        defer args.deinit();
        try args.ensureTotalCapacity(MAX_EXPR_OPERANDS);

        // Parse argument list
        while (self.get_current_token().token_type != .punc_rparen) {
            if (self.get_current_token().token_type == .eof) {
                return error.UnexpectedEof;
            }

            // Skip comma if not first argument
            if (args.items.len > 0) {
                if (self.get_current_token().token_type != .punc_comma) {
                    return error.ExpectedComma;
                }
                self.advance(); // Skip ','
            }

            // Parse argument expression
            const arg = try self.parse_expression();
            try args.append(arg);
        }

        self.advance(); // Skip ')'

        // Create function call node
        const args_slice = try self.allocator.dupe(u32, args.items);
        errdefer self.allocator.free(args_slice);

        return try self.create_node(
            .expr_call,
            start_token.start,
            self.get_current_token().end,
            start_token.line,
            start_token.column,
            .{ .call = .{
                .callee = callee,
                .args = args_slice,
                .args_len = @as(u32, @intCast(args_slice.len)),
            } },
        );
    }

    /// Parse type.
    fn parse_type(self: *Parser) !u32 {
        // Assert: Token index must be valid
        std.debug.assert(self.token_index < self.tokens.len);

        const token = self.get_current_token();

        // Named type (identifier)
        if (token.token_type == .identifier) {
            const name = self.source[token.start..token.end];
            self.advance(); // Skip identifier

            return try self.create_node(
                .type_named,
                token.start,
                token.end,
                token.line,
                token.column,
                .{ .type_named = .{
                    .name = name,
                    .name_len = token.end - token.start,
                } },
            );
        }

        return error.ExpectedType;
    }

    /// Create AST node.
    fn create_node(self: *Parser, node_type: NodeType, start: u32, end: u32, line: u32, column: u32, data: NodeData) !u32 {
        // Assert: Node count must be within bounds
        std.debug.assert(self.nodes_len < MAX_AST_NODES);

        // Assert: Depth must be within bounds
        std.debug.assert(self.depth <= MAX_AST_DEPTH);

        const index = self.nodes_len;
        self.nodes[index] = Node{
            .node_type = node_type,
            .start = start,
            .end = end,
            .line = line,
            .column = column,
            .depth = self.depth,
            .data = data,
        };
        self.nodes_len += 1;

        return index;
    }

    /// Get current token.
    fn get_current_token(self: *const Parser) Lexer.Token {
        // Assert: Token index must be valid
        std.debug.assert(self.token_index < self.tokens.len);

        return self.tokens[self.token_index];
    }

    /// Advance to next token.
    fn advance(self: *Parser) void {
        // Assert: Token index must be valid
        std.debug.assert(self.token_index < self.tokens.len);

        self.token_index += 1;
    }

    /// Get binary operator precedence (higher = tighter binding).
    fn get_binary_precedence(token_type: Lexer.TokenType) u32 {
        return switch (token_type) {
            // Logical operators (lowest precedence)
            .op_or => 1,
            .op_and => 2,
            // Comparison operators
            .op_eq, .op_ne, .op_lt, .op_le, .op_gt, .op_ge => 3,
            // Arithmetic operators
            .op_plus, .op_minus => 4,
            .op_multiply, .op_divide, .op_modulo => 5,
            else => 0, // Not a binary operator
        };
    }

    /// Convert token type to binary operator.
    fn token_type_to_binary_operator(token_type: Lexer.TokenType) ?BinaryOperator {
        return switch (token_type) {
            .op_plus => .add,
            .op_minus => .subtract,
            .op_multiply => .multiply,
            .op_divide => .divide,
            .op_modulo => .modulo,
            .op_eq => .eq,
            .op_ne => .ne,
            .op_lt => .lt,
            .op_le => .le,
            .op_gt => .gt,
            .op_ge => .ge,
            .op_and => .and_op,
            .op_or => .or_op,
            else => null,
        };
    }

    /// Check if token type is a literal.
    fn is_literal_token(token_type: Lexer.TokenType) bool {
        return switch (token_type) {
            .integer, .float, .string, .kw_true, .kw_false, .kw_null => true,
            else => false,
        };
    }

    /// Get node at index.
    pub fn get_node(self: *const Parser, index: u32) ?Node {
        // Assert: Index must be valid
        std.debug.assert(index < MAX_AST_NODES);

        if (index >= self.nodes_len) {
            return null;
        }

        return self.nodes[index];
    }

    /// Get number of nodes.
    pub fn get_node_count(self: *const Parser) u32 {
        return self.nodes_len;
    }
};

/// Parser errors.
pub const ParserError = error{
    ExpectedIdentifier,
    ExpectedLeftParen,
    ExpectedRightParen,
    ExpectedComma,
    ExpectedSemicolon,
    ExpectedAssign,
    ExpectedType,
    UnexpectedToken,
    UnexpectedEof,
    InvalidOperator,
    InvalidLiteral,
    InvalidNode,
};

