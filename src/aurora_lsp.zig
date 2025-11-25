const std = @import("std");
const GrainBuffer = @import("grain_buffer.zig").GrainBuffer;

// Cancellation support: track pending requests
// Bounded: Max 100 pending requests
pub const MAX_PENDING_REQUESTS: u32 = 100;

/// LSP client for Aurora IDE: communicates with ZLS (Zig Language Server) via JSON-RPC 2.0.
/// ~<~ Glow Airbend: static allocation for message buffers; process lifecycle explicit.
/// ~~~~ Glow Waterbend: snapshot model tracks incremental document changes (Matklad-style).
pub const LspClient = struct {
    // Snapshot model: track document versions incrementally (Matklad-style)
    // Bounded: Max 1000 document snapshots
    pub const MAX_SNAPSHOTS: u32 = 1000;
    
    // Diagnostics storage: track diagnostics per document
    // Bounded: Max 1000 diagnostics per document
    pub const MAX_DIAGNOSTICS_PER_DOCUMENT: u32 = 1000;
    
    allocator: std.mem.Allocator,
    server_process: ?std.process.Child = null,
    request_id: u64 = 1,
    message_buffer: [8192]u8 = undefined,
    snapshots: std.ArrayListUnmanaged(DocumentSnapshot) = .{},
    current_snapshot_id: u64 = 0,
    pending_requests: std.AutoHashMap(u64, void) = undefined,
    diagnostics: std.StringHashMap(std.ArrayListUnmanaged(Diagnostic)) = undefined,

    pub const Message = struct {
        jsonrpc: []const u8 = "2.0",
        id: ?u64 = null,
        method: ?[]const u8 = null,
        params: ?std.json.Value = null,
        result: ?std.json.Value = null,
        lsp_error: ?LspError = null,
    };

    pub const LspError = struct {
        code: i32,
        message: []const u8,
        data: ?std.json.Value = null,
    };

    pub const CompletionItem = struct {
        label: []const u8,
        kind: ?u32 = null,
        detail: ?[]const u8 = null,
        documentation: ?[]const u8 = null,
    };
    
    pub const HoverResult = struct {
        contents: []const u8, // Hover content (markdown or plain text)
        range: ?Range = null, // Optional range for hover
    };
    
    /// Location result for go-to-definition (file URI and range).
    pub const Location = struct {
        uri: []const u8, // File URI where definition is located
        range: Range, // Range of the definition
    };

    pub const Diagnostic = struct {
        range: Range,
        severity: ?u32 = null,
        message: []const u8,
        source: ?[]const u8 = null,
    };

    pub const Range = struct {
        start: Position,
        end: Position,
    };

    pub const Position = struct {
        line: u32,
        character: u32,
    };
    
    /// Document snapshot: incremental change tracking (Matklad-style).
    /// Tracks document version, URI, and text content.
    pub const DocumentSnapshot = struct {
        id: u64,
        uri: []const u8,
        version: u64,
        text: []const u8,
    };
    
    /// Text document change: incremental edit (LSP textDocument/didChange).
    pub const TextDocumentChange = struct {
        range: ?Range = null, // null = full document replacement
        range_length: ?u32 = null,
        text: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) LspClient {
        return LspClient{
            .allocator = allocator,
            .snapshots = .{},
            .pending_requests = std.AutoHashMap(u64, void).init(allocator),
            .diagnostics = std.StringHashMap(std.ArrayListUnmanaged(Diagnostic)).init(allocator),
        };
    }

    pub fn deinit(self: *LspClient) void {
        // Free snapshot URIs and text
        for (self.snapshots.items) |*snapshot| {
            self.allocator.free(snapshot.uri);
            self.allocator.free(snapshot.text);
        }
        self.snapshots.deinit(self.allocator);
        
        // Free diagnostics
        var diagnostics_it = self.diagnostics.iterator();
        while (diagnostics_it.next()) |entry| {
            // Free diagnostic messages and sources
            for (entry.value_ptr.items) |*diag| {
                self.allocator.free(diag.message);
                if (diag.source) |source| {
                    self.allocator.free(source);
                }
            }
            entry.value_ptr.deinit(self.allocator);
            // Free URI key (StringHashMap owns keys, but we allocated them)
            self.allocator.free(entry.key_ptr.*);
        }
        self.diagnostics.deinit();
        
        self.pending_requests.deinit();
        
        if (self.server_process) |*proc| {
            _ = proc.kill() catch {};
            _ = proc.wait() catch {};
        }
        self.* = undefined;
    }

    /// Spawn ZLS process: expects `zls` in PATH or use explicit path.
    pub fn startServer(self: *LspClient, zls_path: []const u8) !void {
        if (self.server_process != null) return;

        const argv = [_][]const u8{ zls_path };
        var child = std.process.Child.init(&argv, self.allocator);
        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        try child.spawn();
        self.server_process = child;
    }

    /// Send initialize request to LSP server.
    pub fn initialize(self: *LspClient, root_uri: []const u8) !void {
        // Assert: Root URI must be non-empty
        std.debug.assert(root_uri.len > 0);
        std.debug.assert(root_uri.len <= 4096); // Bounded URI length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        try params_obj.put("rootUri", std.json.Value{ .string = root_uri });
        
        const capabilities_obj = std.json.ObjectMap.init(self.allocator);
        try params_obj.put("capabilities", std.json.Value{ .object = capabilities_obj });
        
        const params = std.json.Value{ .object = params_obj };
        _ = try self.sendRequest("initialize", params);
    }

    /// Request textDocument/completion at a position.
    pub fn requestCompletion(
        self: *LspClient,
        uri: []const u8,
        line: u32,
        character: u32,
    ) !?[]CompletionItem {
        // Assert: URI and position must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        var position_obj = std.json.ObjectMap.init(self.allocator);
        defer position_obj.deinit();
        try position_obj.put("line", std.json.Value{ .integer = @intCast(line) });
        try position_obj.put("character", std.json.Value{ .integer = @intCast(character) });
        try params_obj.put("position", std.json.Value{ .object = position_obj });
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/completion", params);
        
        // Parse completion items from response.result
        if (response.result) |result| {
            if (result == .array) {
                const items = result.array.items;
                var completions = try self.allocator.alloc(CompletionItem, items.len);
                for (items, 0..) |item, i| {
                    if (item == .object) {
                        const obj = item.object;
                        completions[i] = CompletionItem{
                            .label = if (obj.get("label")) |l| l.string else "",
                            .kind = if (obj.get("kind")) |k| @intCast(k.integer) else null,
                            .detail = if (obj.get("detail")) |d| d.string else null,
                            .documentation = if (obj.get("documentation")) |doc| doc.string else null,
                        };
                    }
                }
                return completions;
            }
        }
        return null;
    }
    
    /// Request completionItem/resolve (get additional details for completion item).
    /// Why: Get full documentation and details for a completion item after selection.
    /// Contract: completion_item must be valid (must have label at minimum).
    /// Returns: Resolved completion item with full details, or null if not available.
    pub fn resolveCompletionItem(
        self: *LspClient,
        completion_item: CompletionItem,
    ) !?CompletionItem {
        // Assert: Completion item must have label
        std.debug.assert(completion_item.label.len > 0);
        std.debug.assert(completion_item.label.len <= 1024); // Bounded label length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        // Build completion item object
        var item_obj = std.json.ObjectMap.init(self.allocator);
        try item_obj.put("label", std.json.Value{ .string = completion_item.label });
        
        if (completion_item.kind) |kind| {
            try item_obj.put("kind", std.json.Value{ .integer = @intCast(kind) });
        }
        if (completion_item.detail) |detail| {
            try item_obj.put("detail", std.json.Value{ .string = detail });
        }
        if (completion_item.documentation) |doc| {
            try item_obj.put("documentation", std.json.Value{ .string = doc });
        }
        
        try params_obj.put("item", std.json.Value{ .object = item_obj });
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("completionItem/resolve", params);
        
        // Parse resolved completion item from response.result
        if (response.result) |result| {
            if (result == .object) {
                const obj = result.object;
                
                // Parse label (required)
                const label_val = obj.get("label") orelse return null;
                if (label_val != .string) return null;
                const label_str = label_val.string;
                
                const label_copy = try self.allocator.dupe(u8, label_str);
                errdefer self.allocator.free(label_copy);
                
                // Parse kind (optional)
                const kind: ?u32 = if (obj.get("kind")) |k|
                    if (k == .integer) @as(u32, @intCast(k.integer)) else null
                else
                    null;
                
                // Parse detail (optional)
                var detail: ?[]const u8 = null;
                if (obj.get("detail")) |detail_val| {
                    if (detail_val == .string) {
                        const detail_str = detail_val.string;
                        const detail_copy = try self.allocator.dupe(u8, detail_str);
                        errdefer self.allocator.free(detail_copy);
                        detail = detail_copy;
                    }
                }
                
                // Parse documentation (optional)
                var documentation: ?[]const u8 = null;
                if (obj.get("documentation")) |doc_val| {
                    if (doc_val == .string) {
                        const doc_str = doc_val.string;
                        const doc_copy = try self.allocator.dupe(u8, doc_str);
                        errdefer self.allocator.free(doc_copy);
                        documentation = doc_copy;
                    } else if (doc_val == .object) {
                        // Documentation can be MarkupContent (object with kind and value)
                        if (doc_val.object.get("value")) |value| {
                            if (value == .string) {
                                const doc_str = value.string;
                                const doc_copy = try self.allocator.dupe(u8, doc_str);
                                errdefer self.allocator.free(doc_copy);
                                documentation = doc_copy;
                            }
                        }
                    }
                }
                
                return CompletionItem{
                    .label = label_copy,
                    .kind = kind,
                    .detail = detail,
                    .documentation = documentation,
                };
            }
        }
        return null;
    }
    
    /// Request textDocument/signatureHelp (get function signature at position).
    /// Why: Show function signatures and parameter hints as user types.
    /// Contract: uri, line, and character must be valid.
    /// Returns: Signature help information, or null if not available.
    pub fn requestSignatureHelp(
        self: *LspClient,
        uri: []const u8,
        line: u32,
        character: u32,
    ) !?SignatureHelp {
        // Assert: URI and position must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        var position_obj = std.json.ObjectMap.init(self.allocator);
        defer position_obj.deinit();
        try position_obj.put("line", std.json.Value{ .integer = @intCast(line) });
        try position_obj.put("character", std.json.Value{ .integer = @intCast(character) });
        try params_obj.put("position", std.json.Value{ .object = position_obj });
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/signatureHelp", params);
        
        // Parse signature help from response.result
        if (response.result) |result| {
            if (result == .object) {
                const obj = result.object;
                
                // Parse signatures array
                const signatures_val = obj.get("signatures") orelse return null;
                if (signatures_val != .array) return null;
                
                var signatures = std.ArrayList(SignatureInformation).init(self.allocator);
                errdefer {
                    // Free any allocated strings on error
                    for (signatures.items) |*sig| {
                        self.allocator.free(sig.label);
                        if (sig.documentation) |doc| {
                            self.allocator.free(doc);
                        }
                        if (sig.parameters) |params_list| {
                            for (params_list.items) |*param| {
                                self.allocator.free(param.label);
                                if (param.documentation) |doc| {
                                    self.allocator.free(doc);
                                }
                            }
                            params_list.deinit(self.allocator);
                            self.allocator.free(params_list.items);
                        }
                    }
                    signatures.deinit();
                }
                
                for (signatures_val.array.items) |sig_item| {
                    if (sig_item == .object) {
                        const sig_obj = sig_item.object;
                        
                        // Parse label
                        const label_val = sig_obj.get("label") orelse continue;
                        if (label_val != .string) continue;
                        const label_str = label_val.string;
                        
                        const label_copy = try self.allocator.dupe(u8, label_str);
                        errdefer self.allocator.free(label_copy);
                        
                        // Parse documentation (optional)
                        var documentation: ?[]const u8 = null;
                        if (sig_obj.get("documentation")) |doc_val| {
                            if (doc_val == .string) {
                                const doc_str = doc_val.string;
                                const doc_copy = try self.allocator.dupe(u8, doc_str);
                                errdefer self.allocator.free(doc_copy);
                                documentation = doc_copy;
                            }
                        }
                        
                        // Parse parameters (optional)
                        var parameters: ?std.ArrayList(ParameterInformation) = null;
                        if (sig_obj.get("parameters")) |params_val| {
                            if (params_val == .array) {
                                parameters = std.ArrayList(ParameterInformation).init(self.allocator);
                                errdefer {
                                    if (parameters) |*params_list| {
                                        for (params_list.items) |*param| {
                                            self.allocator.free(param.label);
                                            if (param.documentation) |doc| {
                                                self.allocator.free(doc);
                                            }
                                        }
                                        params_list.deinit();
                                    }
                                }
                                
                                for (params_val.array.items) |param_item| {
                                    if (param_item == .object) {
                                        const param_obj = param_item.object;
                                        
                                        // Parse label
                                        const param_label_val = param_obj.get("label") orelse continue;
                                        if (param_label_val != .string) continue;
                                        const param_label_str = param_label_val.string;
                                        
                                        const param_label_copy = try self.allocator.dupe(u8, param_label_str);
                                        errdefer self.allocator.free(param_label_copy);
                                        
                                        // Parse documentation (optional)
                                        var param_doc: ?[]const u8 = null;
                                        if (param_obj.get("documentation")) |doc_val| {
                                            if (doc_val == .string) {
                                                const param_doc_str = doc_val.string;
                                                const param_doc_copy = try self.allocator.dupe(u8, param_doc_str);
                                                errdefer self.allocator.free(param_doc_copy);
                                                param_doc = param_doc_copy;
                                            }
                                        }
                                        
                                        try parameters.?.append(ParameterInformation{
                                            .label = param_label_copy,
                                            .documentation = param_doc,
                                        });
                                    }
                                }
                            }
                        }
                        
                        try signatures.append(SignatureInformation{
                            .label = label_copy,
                            .documentation = documentation,
                            .parameters = parameters,
                        });
                    }
                }
                
                // Parse activeSignature (optional)
                const active_sig: ?u32 = if (obj.get("activeSignature")) |as|
                    if (as == .integer) @as(u32, @intCast(as.integer)) else null
                else
                    null;
                
                // Parse activeParameter (optional)
                const active_param: ?u32 = if (obj.get("activeParameter")) |ap|
                    if (ap == .integer) @as(u32, @intCast(ap.integer)) else null
                else
                    null;
                
                const signatures_slice = try signatures.toOwnedSlice();
                return SignatureHelp{
                    .signatures = std.ArrayList(SignatureInformation).fromOwnedSlice(self.allocator, signatures_slice),
                    .active_signature = active_sig,
                    .active_parameter = active_param,
                };
            }
        }
        return null;
    }
    
    /// Signature help information from LSP server.
    pub const SignatureHelp = struct {
        signatures: std.ArrayList(SignatureInformation), // Available signatures
        active_signature: ?u32 = null, // Currently active signature index
        active_parameter: ?u32 = null, // Currently active parameter index
    };
    
    /// Signature information (function signature).
    pub const SignatureInformation = struct {
        label: []const u8, // Function signature label
        documentation: ?[]const u8 = null, // Optional documentation
        parameters: ?std.ArrayList(ParameterInformation) = null, // Optional parameters
    };
    
    /// Parameter information (function parameter).
    pub const ParameterInformation = struct {
        label: []const u8, // Parameter label
        documentation: ?[]const u8 = null, // Optional documentation
    };
    
    /// Request textDocument/hover at a position.
    pub fn requestHover(
        self: *LspClient,
        uri: []const u8,
        line: u32,
        character: u32,
    ) !?HoverResult {
        // Assert: URI and position must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        var position_obj = std.json.ObjectMap.init(self.allocator);
        defer position_obj.deinit();
        try position_obj.put("line", std.json.Value{ .integer = @intCast(line) });
        try position_obj.put("character", std.json.Value{ .integer = @intCast(character) });
        try params_obj.put("position", std.json.Value{ .object = position_obj });
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/hover", params);
        
        // Parse hover result from response.result
        if (response.result) |result| {
            if (result == .object) {
                const obj = result.object;
                var contents: []const u8 = "";
                var hover_range: ?Range = null;
                
                // Parse contents (can be string or object with value)
                if (obj.get("contents")) |contents_val| {
                    if (contents_val == .string) {
                        contents = contents_val.string;
                    } else if (contents_val == .object) {
                        if (contents_val.object.get("value")) |value| {
                            if (value == .string) {
                                contents = value.string;
                            }
                        }
                    }
                }
                
                // Parse range (optional)
                if (obj.get("range")) |range_val| {
                    if (range_val == .object) {
                        const range_obj = range_val.object;
                        if (range_obj.get("start")) |start_val| {
                            if (start_val == .object) {
                                const start_obj = start_val.object;
                                const start_line = if (start_obj.get("line")) |l| @as(u32, @intCast(l.integer)) else 0;
                                const start_char = if (start_obj.get("character")) |c| @as(u32, @intCast(c.integer)) else 0;
                                
                                if (range_obj.get("end")) |end_val| {
                                    if (end_val == .object) {
                                        const end_obj = end_val.object;
                                        const end_line = if (end_obj.get("line")) |l| @as(u32, @intCast(l.integer)) else 0;
                                        const end_char = if (end_obj.get("character")) |c| @as(u32, @intCast(c.integer)) else 0;
                                        
                                        hover_range = Range{
                                            .start = Position{ .line = start_line, .character = start_char },
                                            .end = Position{ .line = end_line, .character = end_char },
                                        };
                                    }
                                }
                            }
                        }
                    }
                }
                
                if (contents.len > 0) {
                    // Allocate hover result
                    const contents_copy = try self.allocator.dupe(u8, contents);
                    return HoverResult{
                        .contents = contents_copy,
                        .range = hover_range,
                    };
                }
            }
        }
        return null;
    }
    
    /// Request textDocument/references at a position (find all references).
    /// Why: Find all references to a symbol for code navigation and refactoring.
    /// Contract: uri, line, and character must be valid.
    /// Returns: Array of locations where the symbol is referenced.
    pub fn requestReferences(
        self: *LspClient,
        uri: []const u8,
        line: u32,
        character: u32,
        include_declaration: bool,
    ) !?[]Location {
        // Assert: URI and position must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        var position_obj = std.json.ObjectMap.init(self.allocator);
        defer position_obj.deinit();
        try position_obj.put("line", std.json.Value{ .integer = @intCast(line) });
        try position_obj.put("character", std.json.Value{ .integer = @intCast(character) });
        try params_obj.put("position", std.json.Value{ .object = position_obj });
        
        // Set includeDeclaration in context
        var context_obj = std.json.ObjectMap.init(self.allocator);
        try context_obj.put("includeDeclaration", std.json.Value{ .bool = include_declaration });
        try params_obj.put("context", std.json.Value{ .object = context_obj });
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/references", params);
        
        // Parse locations array from response.result
        if (response.result) |result| {
            if (result == .array) {
                const items = result.array.items;
                var locations = std.ArrayList(Location).init(self.allocator);
                errdefer {
                    // Free any allocated URIs on error
                    for (locations.items) |*loc| {
                        self.allocator.free(loc.uri);
                    }
                    locations.deinit();
                }
                
                for (items) |item| {
                    if (item == .object) {
                        const obj = item.object;
                        const location_uri = obj.get("uri") orelse continue;
                        if (location_uri != .string) continue;
                        const uri_str = location_uri.string;
                        
                        const range_val = obj.get("range") orelse continue;
                        if (range_val != .object) continue;
                        const range_obj = range_val.object;
                        
                        const start_val = range_obj.get("start") orelse continue;
                        const end_val = range_obj.get("end") orelse continue;
                        if (start_val != .object or end_val != .object) continue;
                        
                        const start_obj = start_val.object;
                        const end_obj = end_val.object;
                        
                        const start_line_val = start_obj.get("line") orelse continue;
                        const start_char_val = start_obj.get("character") orelse continue;
                        const end_line_val = end_obj.get("line") orelse continue;
                        const end_char_val = end_obj.get("character") orelse continue;
                        
                        if (start_line_val != .integer or start_char_val != .integer or
                            end_line_val != .integer or end_char_val != .integer) continue;
                        
                        const start_line = @as(u32, @intCast(start_line_val.integer));
                        const start_char = @as(u32, @intCast(start_char_val.integer));
                        const end_line = @as(u32, @intCast(end_line_val.integer));
                        const end_char = @as(u32, @intCast(end_char_val.integer));
                        
                        const uri_copy = try self.allocator.dupe(u8, uri_str);
                        errdefer self.allocator.free(uri_copy);
                        
                        try locations.append(Location{
                            .uri = uri_copy,
                            .range = Range{
                                .start = Position{ .line = start_line, .character = start_char },
                                .end = Position{ .line = end_line, .character = end_char },
                            },
                        });
                    }
                }
                
                return try locations.toOwnedSlice();
            }
        }
        return null;
    }
    
    /// Request textDocument/definition at a position (go-to-definition).
    /// Why: Navigate to symbol definition for code navigation.
    /// Contract: uri, line, and character must be valid.
    pub fn requestDefinition(
        self: *LspClient,
        uri: []const u8,
        line: u32,
        character: u32,
    ) !?Location {
        // Assert: URI and position must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        var position_obj = std.json.ObjectMap.init(self.allocator);
        defer position_obj.deinit();
        try position_obj.put("line", std.json.Value{ .integer = @intCast(line) });
        try position_obj.put("character", std.json.Value{ .integer = @intCast(character) });
        try params_obj.put("position", std.json.Value{ .object = position_obj });
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/definition", params);
        
        // Parse location from response.result
        // LSP can return either a single Location or an array of Locations
        if (response.result) |result| {
            if (result == .object) {
                // Single location
                const obj = result.object;
                const location_uri = if (obj.get("uri")) |u| u.string else return null;
                const range_val = obj.get("range") orelse return null;
                
                if (range_val == .object) {
                    const range_obj = range_val.object;
                    const start_val = range_obj.get("start") orelse return null;
                    const end_val = range_obj.get("end") orelse return null;
                    
                    if (start_val == .object and end_val == .object) {
                        const start_obj = start_val.object;
                        const end_obj = end_val.object;
                        
                        const start_line = if (start_obj.get("line")) |l| @as(u32, @intCast(l.integer)) else return null;
                        const start_char = if (start_obj.get("character")) |c| @as(u32, @intCast(c.integer)) else return null;
                        const end_line = if (end_obj.get("line")) |l| @as(u32, @intCast(l.integer)) else return null;
                        const end_char = if (end_obj.get("character")) |c| @as(u32, @intCast(c.integer)) else return null;
                        
                        const uri_copy = try self.allocator.dupe(u8, location_uri);
                        return Location{
                            .uri = uri_copy,
                            .range = Range{
                                .start = Position{ .line = start_line, .character = start_char },
                                .end = Position{ .line = end_line, .character = end_char },
                            },
                        };
                    }
                }
            } else if (result == .array) {
                // Array of locations (take first one)
                const items = result.array.items;
                if (items.len > 0) {
                    const first_item = items[0];
                    if (first_item == .object) {
                        const obj = first_item.object;
                        const location_uri = if (obj.get("uri")) |u| u.string else return null;
                        const range_val = obj.get("range") orelse return null;
                        
                        if (range_val == .object) {
                            const range_obj = range_val.object;
                            const start_val = range_obj.get("start") orelse return null;
                            const end_val = range_obj.get("end") orelse return null;
                            
                            if (start_val == .object and end_val == .object) {
                                const start_obj = start_val.object;
                                const end_obj = end_val.object;
                                
                                const start_line = if (start_obj.get("line")) |l| @as(u32, @intCast(l.integer)) else return null;
                                const start_char = if (start_obj.get("character")) |c| @as(u32, @intCast(c.integer)) else return null;
                                const end_line = if (end_obj.get("line")) |l| @as(u32, @intCast(l.integer)) else return null;
                                const end_char = if (end_obj.get("character")) |c| @as(u32, @intCast(c.integer)) else return null;
                                
                                const uri_copy = try self.allocator.dupe(u8, location_uri);
                                return Location{
                                    .uri = uri_copy,
                                    .range = Range{
                                        .start = Position{ .line = start_line, .character = start_char },
                                        .end = Position{ .line = end_line, .character = end_char },
                                    },
                                };
                            }
                        }
                    }
                }
            }
        }
        return null;
    }
    
    /// Request textDocument/formatting (format entire document).
    /// Why: Format code according to language server formatting rules.
    /// Contract: uri must be valid.
    /// Returns: Array of text edits to apply, or null if formatting not available.
    pub fn requestFormatting(
        self: *LspClient,
        uri: []const u8,
        options: ?FormattingOptions,
    ) !?[]TextEdit {
        // Assert: URI must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        // Add formatting options if provided
        if (options) |opts| {
            var options_obj = std.json.ObjectMap.init(self.allocator);
            try options_obj.put("tabSize", std.json.Value{ .integer = @intCast(opts.tab_size) });
            try options_obj.put("insertSpaces", std.json.Value{ .bool = opts.insert_spaces });
            try params_obj.put("options", std.json.Value{ .object = options_obj });
        }
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/formatting", params);
        
        // Parse text edits array from response.result
        if (response.result) |result| {
            if (result == .array) {
                const items = result.array.items;
                var edits = std.ArrayList(TextEdit).init(self.allocator);
                errdefer {
                    // Free any allocated text on error
                    for (edits.items) |*edit| {
                        self.allocator.free(edit.new_text);
                    }
                    edits.deinit();
                }
                
                for (items) |item| {
                    if (item == .object) {
                        const obj = item.object;
                        
                        // Parse range
                        const range_val = obj.get("range") orelse continue;
                        if (range_val != .object) continue;
                        const range_obj = range_val.object;
                        
                        const start_val = range_obj.get("start") orelse continue;
                        const end_val = range_obj.get("end") orelse continue;
                        if (start_val != .object or end_val != .object) continue;
                        
                        const start_obj = start_val.object;
                        const end_obj = end_val.object;
                        
                        const start_line_val = start_obj.get("line") orelse continue;
                        const start_char_val = start_obj.get("character") orelse continue;
                        const end_line_val = end_obj.get("line") orelse continue;
                        const end_char_val = end_obj.get("character") orelse continue;
                        
                        if (start_line_val != .integer or start_char_val != .integer or
                            end_line_val != .integer or end_char_val != .integer) continue;
                        
                        const start_line = @as(u32, @intCast(start_line_val.integer));
                        const start_char = @as(u32, @intCast(start_char_val.integer));
                        const end_line = @as(u32, @intCast(end_line_val.integer));
                        const end_char = @as(u32, @intCast(end_char_val.integer));
                        
                        // Parse newText
                        const new_text_val = obj.get("newText") orelse continue;
                        if (new_text_val != .string) continue;
                        const new_text_str = new_text_val.string;
                        
                        const new_text_copy = try self.allocator.dupe(u8, new_text_str);
                        errdefer self.allocator.free(new_text_copy);
                        
                        try edits.append(TextEdit{
                            .range = Range{
                                .start = Position{ .line = start_line, .character = start_char },
                                .end = Position{ .line = end_line, .character = end_char },
                            },
                            .new_text = new_text_copy,
                        });
                    }
                }
                
                return try edits.toOwnedSlice();
            }
        }
        return null;
    }
    
    /// Request textDocument/rangeFormatting (format selected range).
    /// Why: Format a specific range of code according to language server rules.
    /// Contract: uri and range must be valid.
    /// Returns: Array of text edits to apply, or null if formatting not available.
    pub fn requestRangeFormatting(
        self: *LspClient,
        uri: []const u8,
        range: Range,
        options: ?FormattingOptions,
    ) !?[]TextEdit {
        // Assert: URI and range must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        // Add range
        var range_param_obj = std.json.ObjectMap.init(self.allocator);
        var start_obj = std.json.ObjectMap.init(self.allocator);
        try start_obj.put("line", std.json.Value{ .integer = @intCast(range.start.line) });
        try start_obj.put("character", std.json.Value{ .integer = @intCast(range.start.character) });
        try range_param_obj.put("start", std.json.Value{ .object = start_obj });
        
        var end_obj = std.json.ObjectMap.init(self.allocator);
        try end_obj.put("line", std.json.Value{ .integer = @intCast(range.end.line) });
        try end_obj.put("character", std.json.Value{ .integer = @intCast(range.end.character) });
        try range_param_obj.put("end", std.json.Value{ .object = end_obj });
        try params_obj.put("range", std.json.Value{ .object = range_param_obj });
        
        // Add formatting options if provided
        if (options) |opts| {
            var options_obj = std.json.ObjectMap.init(self.allocator);
            try options_obj.put("tabSize", std.json.Value{ .integer = @intCast(opts.tab_size) });
            try options_obj.put("insertSpaces", std.json.Value{ .bool = opts.insert_spaces });
            try params_obj.put("options", std.json.Value{ .object = options_obj });
        }
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/rangeFormatting", params);
        
        // Parse text edits array from response.result (same as document formatting)
        if (response.result) |result| {
            if (result == .array) {
                const items = result.array.items;
                var edits = std.ArrayList(TextEdit).init(self.allocator);
                errdefer {
                    // Free any allocated text on error
                    for (edits.items) |*edit| {
                        self.allocator.free(edit.new_text);
                    }
                    edits.deinit();
                }
                
                for (items) |item| {
                    if (item == .object) {
                        const obj = item.object;
                        
                        // Parse range
                        const range_val = obj.get("range") orelse continue;
                        if (range_val != .object) continue;
                        const edit_range_obj = range_val.object;
                        
                        const start_val = edit_range_obj.get("start") orelse continue;
                        const end_val = edit_range_obj.get("end") orelse continue;
                        if (start_val != .object or end_val != .object) continue;
                        
                        const edit_start_obj = start_val.object;
                        const edit_end_obj = end_val.object;
                        
                        const start_line_val = edit_start_obj.get("line") orelse continue;
                        const start_char_val = edit_start_obj.get("character") orelse continue;
                        const end_line_val = edit_end_obj.get("line") orelse continue;
                        const end_char_val = edit_end_obj.get("character") orelse continue;
                        
                        if (start_line_val != .integer or start_char_val != .integer or
                            end_line_val != .integer or end_char_val != .integer) continue;
                        
                        const start_line = @as(u32, @intCast(start_line_val.integer));
                        const start_char = @as(u32, @intCast(start_char_val.integer));
                        const end_line = @as(u32, @intCast(end_line_val.integer));
                        const end_char = @as(u32, @intCast(end_char_val.integer));
                        
                        // Parse newText
                        const new_text_val = obj.get("newText") orelse continue;
                        if (new_text_val != .string) continue;
                        const new_text_str = new_text_val.string;
                        
                        const new_text_copy = try self.allocator.dupe(u8, new_text_str);
                        errdefer self.allocator.free(new_text_copy);
                        
                        try edits.append(TextEdit{
                            .range = Range{
                                .start = Position{ .line = start_line, .character = start_char },
                                .end = Position{ .line = end_line, .character = end_char },
                            },
                            .new_text = new_text_copy,
                        });
                    }
                }
                
                return try edits.toOwnedSlice();
            }
        }
        return null;
    }
    
    /// Request textDocument/codeAction (get code actions for diagnostics/selection).
    /// Why: Get quick fixes, refactorings, and other code actions from LSP server.
    /// Contract: uri and range must be valid.
    /// Returns: Array of code actions, or null if no actions available.
    pub fn requestCodeActions(
        self: *LspClient,
        uri: []const u8,
        range: Range,
        context: ?CodeActionContext,
    ) !?[]CodeAction {
        // Assert: URI and range must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        // Add range
        var range_param_obj = std.json.ObjectMap.init(self.allocator);
        var start_obj = std.json.ObjectMap.init(self.allocator);
        try start_obj.put("line", std.json.Value{ .integer = @intCast(range.start.line) });
        try start_obj.put("character", std.json.Value{ .integer = @intCast(range.start.character) });
        try range_param_obj.put("start", std.json.Value{ .object = start_obj });
        
        var end_obj = std.json.ObjectMap.init(self.allocator);
        try end_obj.put("line", std.json.Value{ .integer = @intCast(range.end.line) });
        try end_obj.put("character", std.json.Value{ .integer = @intCast(range.end.character) });
        try range_param_obj.put("end", std.json.Value{ .object = end_obj });
        try params_obj.put("range", std.json.Value{ .object = range_param_obj });
        
        // Add context if provided
        if (context) |ctx| {
            var context_obj = std.json.ObjectMap.init(self.allocator);
            if (ctx.diagnostics.len > 0) {
                var diags_array = std.ArrayList(std.json.Value).init(self.allocator);
                defer diags_array.deinit(self.allocator);
                
                for (ctx.diagnostics) |diag| {
                    var diag_obj = std.json.ObjectMap.init(self.allocator);
                    
                    // Add range
                    var diag_range_obj = std.json.ObjectMap.init(self.allocator);
                    var diag_start_obj = std.json.ObjectMap.init(self.allocator);
                    try diag_start_obj.put("line", std.json.Value{ .integer = @intCast(diag.range.start.line) });
                    try diag_start_obj.put("character", std.json.Value{ .integer = @intCast(diag.range.start.character) });
                    try diag_range_obj.put("start", std.json.Value{ .object = diag_start_obj });
                    
                    var diag_end_obj = std.json.ObjectMap.init(self.allocator);
                    try diag_end_obj.put("line", std.json.Value{ .integer = @intCast(diag.range.end.line) });
                    try diag_end_obj.put("character", std.json.Value{ .integer = @intCast(diag.range.end.character) });
                    try diag_range_obj.put("end", std.json.Value{ .object = diag_end_obj });
                    try diag_obj.put("range", std.json.Value{ .object = diag_range_obj });
                    
                    // Add severity if present
                    if (diag.severity) |sev| {
                        try diag_obj.put("severity", std.json.Value{ .integer = @intCast(sev) });
                    }
                    
                    // Add message
                    try diag_obj.put("message", std.json.Value{ .string = diag.message });
                    
                    // Add source if present
                    if (diag.source) |src| {
                        try diag_obj.put("source", std.json.Value{ .string = src });
                    }
                    
                    try diags_array.append(self.allocator, std.json.Value{ .object = diag_obj });
                }
                
                const diags_slice = try diags_array.toOwnedSlice(self.allocator);
                try context_obj.put("diagnostics", std.json.Value{ .array = .{ .items = diags_slice, .capacity = diags_slice.len, .allocator = self.allocator } });
            }
            
            // Add onlyRequested if present
            if (ctx.only_requested) |only| {
                try context_obj.put("only", std.json.Value{ .bool = only });
            }
            
            try params_obj.put("context", std.json.Value{ .object = context_obj });
        }
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/codeAction", params);
        
        // Parse code actions array from response.result
        if (response.result) |result| {
            if (result == .array) {
                const items = result.array.items;
                var actions = std.ArrayList(CodeAction).init(self.allocator);
                errdefer {
                    // Free any allocated strings on error
                    for (actions.items) |*action| {
                        self.allocator.free(action.title);
                        if (action.command) |cmd| {
                            self.allocator.free(cmd.command);
                            if (cmd.arguments) |args| {
                                self.allocator.free(args);
                            }
                        }
                        if (action.edit) |edit| {
                            for (edit.changes.items) |*change| {
                                for (change.edits.items) |*text_edit| {
                                    self.allocator.free(text_edit.new_text);
                                }
                                change.edits.deinit(self.allocator);
                                self.allocator.free(change.uri);
                            }
                            edit.changes.deinit(self.allocator);
                        }
                    }
                    actions.deinit();
                }
                
                for (items) |item| {
                    if (item == .object) {
                        const obj = item.object;
                        
                        // Parse title
                        const title_val = obj.get("title") orelse continue;
                        if (title_val != .string) continue;
                        const title_str = title_val.string;
                        
                        const title_copy = try self.allocator.dupe(u8, title_str);
                        errdefer self.allocator.free(title_copy);
                        
                        // Parse command (optional)
                        var command: ?CodeActionCommand = null;
                        if (obj.get("command")) |cmd_val| {
                            if (cmd_val == .object) {
                                const cmd_obj = cmd_val.object;
                                const cmd_title = cmd_obj.get("command") orelse continue;
                                if (cmd_title != .string) continue;
                                
                                const cmd_str = try self.allocator.dupe(u8, cmd_title.string);
                                errdefer self.allocator.free(cmd_str);
                                
                                // Parse arguments (optional)
                                var arguments: ?[]const u8 = null;
                                if (cmd_obj.get("arguments")) |args_val| {
                                    // Arguments can be any JSON value, store as string for now
                                    const args_str = try self.serialize_json_value(args_val);
                                    errdefer self.allocator.free(args_str);
                                    arguments = args_str;
                                }
                                
                                command = CodeActionCommand{
                                    .command = cmd_str,
                                    .arguments = arguments,
                                };
                            }
                        }
                        
                        // Parse edit (optional)
                        var edit: ?WorkspaceEdit = null;
                        if (obj.get("edit")) |edit_val| {
                            if (edit_val == .object) {
                                const edit_obj = edit_val.object;
                                
                                // Parse changes (map of URI to TextEdit[])
                                var changes = std.ArrayList(TextDocumentEdit).init(self.allocator);
                                errdefer {
                                    for (changes.items) |*change| {
                                        for (change.edits.items) |*text_edit| {
                                            self.allocator.free(text_edit.new_text);
                                        }
                                        change.edits.deinit(self.allocator);
                                        self.allocator.free(change.uri);
                                    }
                                    changes.deinit();
                                }
                                
                                if (edit_obj.get("changes")) |changes_val| {
                                    if (changes_val == .object) {
                                        var changes_it = changes_val.object.iterator();
                                        while (changes_it.next()) |entry| {
                                            const uri_str = entry.key_ptr.*;
                                            const edits_val = entry.value_ptr.*;
                                            
                                            if (edits_val == .array) {
                                                var edits = std.ArrayList(TextEdit).init(self.allocator);
                                                errdefer {
                                                    for (edits.items) |*text_edit| {
                                                        self.allocator.free(text_edit.new_text);
                                                    }
                                                    edits.deinit();
                                                }
                                                
                                                for (edits_val.array.items) |edit_item| {
                                                    if (edit_item == .object) {
                                                        const edit_item_obj = edit_item.object;
                                                        
                                                        // Parse range
                                                        const range_val = edit_item_obj.get("range") orelse continue;
                                                        if (range_val != .object) continue;
                                                        const edit_range_obj = range_val.object;
                                                        
                                                        const start_val = edit_range_obj.get("start") orelse continue;
                                                        const end_val = edit_range_obj.get("end") orelse continue;
                                                        if (start_val != .object or end_val != .object) continue;
                                                        
                                                        const edit_start_obj = start_val.object;
                                                        const edit_end_obj = end_val.object;
                                                        
                                                        const start_line_val = edit_start_obj.get("line") orelse continue;
                                                        const start_char_val = edit_start_obj.get("character") orelse continue;
                                                        const end_line_val = edit_end_obj.get("line") orelse continue;
                                                        const end_char_val = edit_end_obj.get("character") orelse continue;
                                                        
                                                        if (start_line_val != .integer or start_char_val != .integer or
                                                            end_line_val != .integer or end_char_val != .integer) continue;
                                                        
                                                        const start_line = @as(u32, @intCast(start_line_val.integer));
                                                        const start_char = @as(u32, @intCast(start_char_val.integer));
                                                        const end_line = @as(u32, @intCast(end_line_val.integer));
                                                        const end_char = @as(u32, @intCast(end_char_val.integer));
                                                        
                                                        // Parse newText
                                                        const new_text_val = edit_item_obj.get("newText") orelse continue;
                                                        if (new_text_val != .string) continue;
                                                        const new_text_str = new_text_val.string;
                                                        
                                                        const new_text_copy = try self.allocator.dupe(u8, new_text_str);
                                                        errdefer self.allocator.free(new_text_copy);
                                                        
                                                        try edits.append(TextEdit{
                                                            .range = Range{
                                                                .start = Position{ .line = start_line, .character = start_char },
                                                                .end = Position{ .line = end_line, .character = end_char },
                                                            },
                                                            .new_text = new_text_copy,
                                                        });
                                                    }
                                                }
                                                
                                                const uri_copy = try self.allocator.dupe(u8, uri_str);
                                                errdefer self.allocator.free(uri_copy);
                                                
                                                try changes.append(TextDocumentEdit{
                                                    .uri = uri_copy,
                                                    .edits = edits,
                                                });
                                            }
                                        }
                                    }
                                }
                                
                                const changes_slice = try changes.toOwnedSlice(self.allocator);
                                edit = WorkspaceEdit{
                                    .changes = std.ArrayList(TextDocumentEdit).fromOwnedSlice(self.allocator, changes_slice),
                                };
                            }
                        }
                        
                        try actions.append(CodeAction{
                            .title = title_copy,
                            .command = command,
                            .edit = edit,
                        });
                    }
                }
                
                return try actions.toOwnedSlice();
            }
        }
        return null;
    }
    
    /// Code action from LSP server.
    pub const CodeAction = struct {
        title: []const u8, // Title of the action
        command: ?CodeActionCommand = null, // Optional command to execute
        edit: ?WorkspaceEdit = null, // Optional workspace edit
    };
    
    /// Code action command.
    pub const CodeActionCommand = struct {
        command: []const u8, // Command identifier
        arguments: ?[]const u8 = null, // Optional arguments (JSON string)
    };
    
    /// Workspace edit (multiple file edits).
    pub const WorkspaceEdit = struct {
        changes: std.ArrayList(TextDocumentEdit), // Changes per document
    };
    
    /// Text document edit (edits for a single document).
    pub const TextDocumentEdit = struct {
        uri: []const u8, // Document URI
        edits: std.ArrayList(TextEdit), // Text edits for this document
    };
    
    /// Code action context (diagnostics, etc.).
    pub const CodeActionContext = struct {
        diagnostics: []const Diagnostic, // Diagnostics in the range
        only_requested: ?bool = null, // Only return requested action kinds
    };
    
    /// Text edit for document formatting.
    pub const TextEdit = struct {
        range: Range, // Range to replace
        new_text: []const u8, // New text to insert
    };
    
    /// Request textDocument/rename (rename symbol at position).
    /// Why: Rename a symbol across all references for refactoring.
    /// Contract: uri, position, and new_name must be valid.
    /// Returns: Workspace edit with changes to all files, or null if rename not available.
    pub fn requestRename(
        self: *LspClient,
        uri: []const u8,
        line: u32,
        character: u32,
        new_name: []const u8,
    ) !?WorkspaceEdit {
        // Assert: URI, position, and new name must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        std.debug.assert(new_name.len > 0);
        std.debug.assert(new_name.len <= 1024); // Bounded name length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        // Add position
        var position_obj = std.json.ObjectMap.init(self.allocator);
        defer position_obj.deinit();
        try position_obj.put("line", std.json.Value{ .integer = @intCast(line) });
        try position_obj.put("character", std.json.Value{ .integer = @intCast(character) });
        try params_obj.put("position", std.json.Value{ .object = position_obj });
        
        // Add new name
        try params_obj.put("newName", std.json.Value{ .string = new_name });
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/rename", params);
        
        // Parse workspace edit from response.result
        if (response.result) |result| {
            if (result == .object) {
                const obj = result.object;
                
                // Parse changes (map of URI to TextEdit[])
                var changes = std.ArrayList(TextDocumentEdit).init(self.allocator);
                errdefer {
                    for (changes.items) |*change| {
                        for (change.edits.items) |*text_edit| {
                            self.allocator.free(text_edit.new_text);
                        }
                        change.edits.deinit(self.allocator);
                        self.allocator.free(change.uri);
                    }
                    changes.deinit();
                }
                
                if (obj.get("changes")) |changes_val| {
                    if (changes_val == .object) {
                        var changes_it = changes_val.object.iterator();
                        while (changes_it.next()) |entry| {
                            const uri_str = entry.key_ptr.*;
                            const edits_val = entry.value_ptr.*;
                            
                            if (edits_val == .array) {
                                var edits = std.ArrayList(TextEdit).init(self.allocator);
                                errdefer {
                                    for (edits.items) |*text_edit| {
                                        self.allocator.free(text_edit.new_text);
                                    }
                                    edits.deinit();
                                }
                                
                                for (edits_val.array.items) |edit_item| {
                                    if (edit_item == .object) {
                                        const edit_item_obj = edit_item.object;
                                        
                                        // Parse range
                                        const range_val = edit_item_obj.get("range") orelse continue;
                                        if (range_val != .object) continue;
                                        const edit_range_obj = range_val.object;
                                        
                                        const start_val = edit_range_obj.get("start") orelse continue;
                                        const end_val = edit_range_obj.get("end") orelse continue;
                                        if (start_val != .object or end_val != .object) continue;
                                        
                                        const edit_start_obj = start_val.object;
                                        const edit_end_obj = end_val.object;
                                        
                                        const start_line_val = edit_start_obj.get("line") orelse continue;
                                        const start_char_val = edit_start_obj.get("character") orelse continue;
                                        const end_line_val = edit_end_obj.get("line") orelse continue;
                                        const end_char_val = edit_end_obj.get("character") orelse continue;
                                        
                                        if (start_line_val != .integer or start_char_val != .integer or
                                            end_line_val != .integer or end_char_val != .integer) continue;
                                        
                                        const start_line = @as(u32, @intCast(start_line_val.integer));
                                        const start_char = @as(u32, @intCast(start_char_val.integer));
                                        const end_line = @as(u32, @intCast(end_line_val.integer));
                                        const end_char = @as(u32, @intCast(end_char_val.integer));
                                        
                                        // Parse newText
                                        const new_text_val = edit_item_obj.get("newText") orelse continue;
                                        if (new_text_val != .string) continue;
                                        const new_text_str = new_text_val.string;
                                        
                                        const new_text_copy = try self.allocator.dupe(u8, new_text_str);
                                        errdefer self.allocator.free(new_text_copy);
                                        
                                        try edits.append(TextEdit{
                                            .range = Range{
                                                .start = Position{ .line = start_line, .character = start_char },
                                                .end = Position{ .line = end_line, .character = end_char },
                                            },
                                            .new_text = new_text_copy,
                                        });
                                    }
                                }
                                
                                const uri_copy = try self.allocator.dupe(u8, uri_str);
                                errdefer self.allocator.free(uri_copy);
                                
                                try changes.append(TextDocumentEdit{
                                    .uri = uri_copy,
                                    .edits = edits,
                                });
                            }
                        }
                    }
                }
                
                const changes_slice = try changes.toOwnedSlice(self.allocator);
                return WorkspaceEdit{
                    .changes = std.ArrayList(TextDocumentEdit).fromOwnedSlice(self.allocator, changes_slice),
                };
            }
        }
        return null;
    }
    
    /// Request workspace/symbol (search for symbols in workspace).
    /// Why: Search for symbols across the entire workspace for navigation.
    /// Contract: query must be valid.
    /// Returns: Array of symbol information, or null if no symbols found.
    pub fn requestWorkspaceSymbols(
        self: *LspClient,
        query: []const u8,
    ) !?[]SymbolInformation {
        // Assert: Query must be valid
        std.debug.assert(query.len <= 1024); // Bounded query length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        try params_obj.put("query", std.json.Value{ .string = query });
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("workspace/symbol", params);
        
        // Parse symbol information array from response.result
        if (response.result) |result| {
            if (result == .array) {
                const items = result.array.items;
                var symbols = std.ArrayList(SymbolInformation).init(self.allocator);
                errdefer {
                    // Free any allocated strings on error
                    for (symbols.items) |*symbol| {
                        self.allocator.free(symbol.name);
                        self.allocator.free(symbol.uri);
                        if (symbol.container_name) |container| {
                            self.allocator.free(container);
                        }
                    }
                    symbols.deinit();
                }
                
                for (items) |item| {
                    if (item == .object) {
                        const obj = item.object;
                        
                        // Parse name
                        const name_val = obj.get("name") orelse continue;
                        if (name_val != .string) continue;
                        const name_str = name_val.string;
                        
                        const name_copy = try self.allocator.dupe(u8, name_str);
                        errdefer self.allocator.free(name_copy);
                        
                        // Parse kind (optional)
                        const kind: ?u32 = if (obj.get("kind")) |k|
                            if (k == .integer) @as(u32, @intCast(k.integer)) else null
                        else
                            null;
                        
                        // Parse location
                        const location_val = obj.get("location") orelse continue;
                        if (location_val != .object) continue;
                        const location_obj = location_val.object;
                        
                        const location_uri = location_obj.get("uri") orelse continue;
                        if (location_uri != .string) continue;
                        const uri_str = location_uri.string;
                        
                        const uri_copy = try self.allocator.dupe(u8, uri_str);
                        errdefer self.allocator.free(uri_copy);
                        
                        // Parse range
                        const range_val = location_obj.get("range") orelse continue;
                        if (range_val != .object) continue;
                        const range_obj = range_val.object;
                        
                        const start_val = range_obj.get("start") orelse continue;
                        const end_val = range_obj.get("end") orelse continue;
                        if (start_val != .object or end_val != .object) continue;
                        
                        const start_obj = start_val.object;
                        const end_obj = end_val.object;
                        
                        const start_line_val = start_obj.get("line") orelse continue;
                        const start_char_val = start_obj.get("character") orelse continue;
                        const end_line_val = end_obj.get("line") orelse continue;
                        const end_char_val = end_obj.get("character") orelse continue;
                        
                        if (start_line_val != .integer or start_char_val != .integer or
                            end_line_val != .integer or end_char_val != .integer) continue;
                        
                        const start_line = @as(u32, @intCast(start_line_val.integer));
                        const start_char = @as(u32, @intCast(start_char_val.integer));
                        const end_line = @as(u32, @intCast(end_line_val.integer));
                        const end_char = @as(u32, @intCast(end_char_val.integer));
                        
                        // Parse containerName (optional)
                        var container_name: ?[]const u8 = null;
                        if (obj.get("containerName")) |container_val| {
                            if (container_val == .string) {
                                const container_str = container_val.string;
                                const container_copy = try self.allocator.dupe(u8, container_str);
                                errdefer self.allocator.free(container_copy);
                                container_name = container_copy;
                            }
                        }
                        
                        try symbols.append(SymbolInformation{
                            .name = name_copy,
                            .kind = kind,
                            .uri = uri_copy,
                            .range = Range{
                                .start = Position{ .line = start_line, .character = start_char },
                                .end = Position{ .line = end_line, .character = end_char },
                            },
                            .container_name = container_name,
                        });
                    }
                }
                
                return try symbols.toOwnedSlice();
            }
        }
        return null;
    }
    
    /// Symbol information from workspace symbol search.
    pub const SymbolInformation = struct {
        name: []const u8, // Symbol name
        kind: ?u32 = null, // Symbol kind (function, class, etc.)
        uri: []const u8, // File URI where symbol is located
        range: Range, // Range of the symbol
        container_name: ?[]const u8 = null, // Optional container name (e.g., class name)
    };
    
    /// Request textDocument/documentSymbol (get symbols in document).
    /// Why: Get outline of document (functions, classes, etc.) for navigation.
    /// Contract: uri must be valid.
    /// Returns: Array of document symbols, or null if no symbols found.
    pub fn requestDocumentSymbols(
        self: *LspClient,
        uri: []const u8,
    ) !?[]DocumentSymbol {
        // Assert: URI must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/documentSymbol", params);
        
        // Parse document symbols array from response.result
        if (response.result) |result| {
            if (result == .array) {
                const items = result.array.items;
                var symbols = std.ArrayList(DocumentSymbol).init(self.allocator);
                errdefer {
                    // Free any allocated strings on error
                    for (symbols.items) |*symbol| {
                        self.allocator.free(symbol.name);
                        if (symbol.detail) |detail| {
                            self.allocator.free(detail);
                        }
                        if (symbol.children) |children| {
                            for (children.items) |*child| {
                                self.allocator.free(child.name);
                                if (child.detail) |d| {
                                    self.allocator.free(d);
                                }
                            }
                            children.deinit(self.allocator);
                            self.allocator.free(children.items);
                        }
                    }
                    symbols.deinit();
                }
                
                for (items) |item| {
                    if (item == .object) {
                        const obj = item.object;
                        
                        // Parse name
                        const name_val = obj.get("name") orelse continue;
                        if (name_val != .string) continue;
                        const name_str = name_val.string;
                        
                        const name_copy = try self.allocator.dupe(u8, name_str);
                        errdefer self.allocator.free(name_copy);
                        
                        // Parse kind (optional)
                        const kind: ?u32 = if (obj.get("kind")) |k|
                            if (k == .integer) @as(u32, @intCast(k.integer)) else null
                        else
                            null;
                        
                        // Parse range
                        const range_val = obj.get("range") orelse continue;
                        if (range_val != .object) continue;
                        const range_obj = range_val.object;
                        
                        const start_val = range_obj.get("start") orelse continue;
                        const end_val = range_obj.get("end") orelse continue;
                        if (start_val != .object or end_val != .object) continue;
                        
                        const start_obj = start_val.object;
                        const end_obj = end_val.object;
                        
                        const start_line_val = start_obj.get("line") orelse continue;
                        const start_char_val = start_obj.get("character") orelse continue;
                        const end_line_val = end_obj.get("line") orelse continue;
                        const end_char_val = end_obj.get("character") orelse continue;
                        
                        if (start_line_val != .integer or start_char_val != .integer or
                            end_line_val != .integer or end_char_val != .integer) continue;
                        
                        const start_line = @as(u32, @intCast(start_line_val.integer));
                        const start_char = @as(u32, @intCast(start_char_val.integer));
                        const end_line = @as(u32, @intCast(end_line_val.integer));
                        const end_char = @as(u32, @intCast(end_char_val.integer));
                        
                        // Parse selectionRange (optional, defaults to range)
                        var selection_range = Range{
                            .start = Position{ .line = start_line, .character = start_char },
                            .end = Position{ .line = end_line, .character = end_char },
                        };
                        if (obj.get("selectionRange")) |sel_range_val| {
                            if (sel_range_val == .object) {
                                const sel_range_obj = sel_range_val.object;
                                const sel_start_val = sel_range_obj.get("start");
                                const sel_end_val = sel_range_obj.get("end");
                                if (sel_start_val != null and sel_end_val != null) {
                                    if (sel_start_val.? == .object and sel_end_val.? == .object) {
                                        const sel_start_obj = sel_start_val.?.object;
                                        const sel_end_obj = sel_end_val.?.object;
                                        
                                        const sel_start_line_val = sel_start_obj.get("line");
                                        const sel_start_char_val = sel_start_obj.get("character");
                                        const sel_end_line_val = sel_end_obj.get("line");
                                        const sel_end_char_val = sel_end_obj.get("character");
                                        
                                        if (sel_start_line_val != null and sel_start_char_val != null and
                                            sel_end_line_val != null and sel_end_char_val != null) {
                                            if (sel_start_line_val.? == .integer and sel_start_char_val.? == .integer and
                                                sel_end_line_val.? == .integer and sel_end_char_val.? == .integer) {
                                                selection_range = Range{
                                                    .start = Position{
                                                        .line = @as(u32, @intCast(sel_start_line_val.?.integer)),
                                                        .character = @as(u32, @intCast(sel_start_char_val.?.integer)),
                                                    },
                                                    .end = Position{
                                                        .line = @as(u32, @intCast(sel_end_line_val.?.integer)),
                                                        .character = @as(u32, @intCast(sel_end_char_val.?.integer)),
                                                    },
                                                };
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Parse detail (optional)
                        var detail: ?[]const u8 = null;
                        if (obj.get("detail")) |detail_val| {
                            if (detail_val == .string) {
                                const detail_str = detail_val.string;
                                const detail_copy = try self.allocator.dupe(u8, detail_str);
                                errdefer self.allocator.free(detail_copy);
                                detail = detail_copy;
                            }
                        }
                        
                        // Parse children (optional, recursive)
                        var children: ?std.ArrayList(DocumentSymbol) = null;
                        if (obj.get("children")) |children_val| {
                            if (children_val == .array) {
                                children = std.ArrayList(DocumentSymbol).init(self.allocator);
                                errdefer {
                                    if (children) |*ch| {
                                        for (ch.items) |*child| {
                                            self.allocator.free(child.name);
                                            if (child.detail) |d| {
                                                self.allocator.free(d);
                                            }
                                        }
                                        ch.deinit();
                                    }
                                }
                                
                                // Note: For simplicity, we only parse one level of children
                                // Full recursive parsing would require more complex error handling
                                for (children_val.array.items) |child_item| {
                                    if (child_item == .object) {
                                        const child_obj = child_item.object;
                                        
                                        const child_name_val = child_obj.get("name") orelse continue;
                                        if (child_name_val != .string) continue;
                                        const child_name_str = child_name_val.string;
                                        
                                        const child_name_copy = try self.allocator.dupe(u8, child_name_str);
                                        errdefer self.allocator.free(child_name_copy);
                                        
                                        const child_kind: ?u32 = if (child_obj.get("kind")) |k|
                                            if (k == .integer) @as(u32, @intCast(k.integer)) else null
                                        else
                                            null;
                                        
                                        const child_range_val = child_obj.get("range") orelse continue;
                                        if (child_range_val != .object) continue;
                                        const child_range_obj = child_range_val.object;
                                        
                                        const child_start_val = child_range_obj.get("start") orelse continue;
                                        const child_end_val = child_range_obj.get("end") orelse continue;
                                        if (child_start_val != .object or child_end_val != .object) continue;
                                        
                                        const child_start_obj = child_start_val.object;
                                        const child_end_obj = child_end_val.object;
                                        
                                        const child_start_line_val = child_start_obj.get("line") orelse continue;
                                        const child_start_char_val = child_start_obj.get("character") orelse continue;
                                        const child_end_line_val = child_end_obj.get("line") orelse continue;
                                        const child_end_char_val = child_end_obj.get("character") orelse continue;
                                        
                                        if (child_start_line_val != .integer or child_start_char_val != .integer or
                                            child_end_line_val != .integer or child_end_char_val != .integer) continue;
                                        
                                        const child_start_line = @as(u32, @intCast(child_start_line_val.integer));
                                        const child_start_char = @as(u32, @intCast(child_start_char_val.integer));
                                        const child_end_line = @as(u32, @intCast(child_end_line_val.integer));
                                        const child_end_char = @as(u32, @intCast(child_end_char_val.integer));
                                        
                                        var child_detail: ?[]const u8 = null;
                                        if (child_obj.get("detail")) |d_val| {
                                            if (d_val == .string) {
                                                const child_detail_str = d_val.string;
                                                const child_detail_copy = try self.allocator.dupe(u8, child_detail_str);
                                                errdefer self.allocator.free(child_detail_copy);
                                                child_detail = child_detail_copy;
                                            }
                                        }
                                        
                                        try children.?.append(DocumentSymbol{
                                            .name = child_name_copy,
                                            .kind = child_kind,
                                            .range = Range{
                                                .start = Position{ .line = child_start_line, .character = child_start_char },
                                                .end = Position{ .line = child_end_line, .character = child_end_char },
                                            },
                                            .selection_range = Range{
                                                .start = Position{ .line = child_start_line, .character = child_start_char },
                                                .end = Position{ .line = child_end_line, .character = child_end_char },
                                            },
                                            .detail = child_detail,
                                            .children = null, // Only one level for now
                                        });
                                    }
                                }
                            }
                        }
                        
                        try symbols.append(DocumentSymbol{
                            .name = name_copy,
                            .kind = kind,
                            .range = Range{
                                .start = Position{ .line = start_line, .character = start_char },
                                .end = Position{ .line = end_line, .character = end_char },
                            },
                            .selection_range = selection_range,
                            .detail = detail,
                            .children = children,
                        });
                    }
                }
                
                return try symbols.toOwnedSlice();
            }
        }
        return null;
    }
    
    /// Document symbol (for outline view).
    pub const DocumentSymbol = struct {
        name: []const u8, // Symbol name
        kind: ?u32 = null, // Symbol kind (function, class, etc.)
        range: Range, // Full range of symbol
        selection_range: Range, // Range that should be selected when navigating
        detail: ?[]const u8 = null, // Optional detail (e.g., function signature)
        children: ?std.ArrayList(DocumentSymbol) = null, // Optional child symbols
    };
    
    /// Request textDocument/onTypeFormatting (format on character trigger).
    /// Why: Format code automatically when typing specific characters (e.g., ';', '}').
    /// Contract: uri, position, and ch must be valid.
    /// Returns: Array of text edits to apply, or null if formatting not available.
    pub fn requestOnTypeFormatting(
        self: *LspClient,
        uri: []const u8,
        line: u32,
        character: u32,
        ch: u8,
        options: ?FormattingOptions,
    ) !?[]TextEdit {
        // Assert: URI, position, and character must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        std.debug.assert(ch > 0);
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        // Add position
        var position_obj = std.json.ObjectMap.init(self.allocator);
        defer position_obj.deinit();
        try position_obj.put("line", std.json.Value{ .integer = @intCast(line) });
        try position_obj.put("character", std.json.Value{ .integer = @intCast(character) });
        try params_obj.put("position", std.json.Value{ .object = position_obj });
        
        // Add character that triggered formatting
        var ch_str: [1]u8 = undefined;
        ch_str[0] = ch;
        try params_obj.put("ch", std.json.Value{ .string = &ch_str });
        
        // Add formatting options if provided
        if (options) |opts| {
            var options_obj = std.json.ObjectMap.init(self.allocator);
            try options_obj.put("tabSize", std.json.Value{ .integer = @intCast(opts.tab_size) });
            try options_obj.put("insertSpaces", std.json.Value{ .bool = opts.insert_spaces });
            try params_obj.put("options", std.json.Value{ .object = options_obj });
        }
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/onTypeFormatting", params);
        
        // Parse text edits array from response.result (same as document formatting)
        if (response.result) |result| {
            if (result == .array) {
                const items = result.array.items;
                var edits = std.ArrayList(TextEdit).init(self.allocator);
                errdefer {
                    // Free any allocated text on error
                    for (edits.items) |*edit| {
                        self.allocator.free(edit.new_text);
                    }
                    edits.deinit();
                }
                
                for (items) |item| {
                    if (item == .object) {
                        const obj = item.object;
                        
                        // Parse range
                        const range_val = obj.get("range") orelse continue;
                        if (range_val != .object) continue;
                        const edit_range_obj = range_val.object;
                        
                        const start_val = edit_range_obj.get("start") orelse continue;
                        const end_val = edit_range_obj.get("end") orelse continue;
                        if (start_val != .object or end_val != .object) continue;
                        
                        const edit_start_obj = start_val.object;
                        const edit_end_obj = end_val.object;
                        
                        const start_line_val = edit_start_obj.get("line") orelse continue;
                        const start_char_val = edit_start_obj.get("character") orelse continue;
                        const end_line_val = edit_end_obj.get("line") orelse continue;
                        const end_char_val = edit_end_obj.get("character") orelse continue;
                        
                        if (start_line_val != .integer or start_char_val != .integer or
                            end_line_val != .integer or end_char_val != .integer) continue;
                        
                        const start_line = @as(u32, @intCast(start_line_val.integer));
                        const start_char = @as(u32, @intCast(start_char_val.integer));
                        const end_line = @as(u32, @intCast(end_line_val.integer));
                        const end_char = @as(u32, @intCast(end_char_val.integer));
                        
                        // Parse newText
                        const new_text_val = obj.get("newText") orelse continue;
                        if (new_text_val != .string) continue;
                        const new_text_str = new_text_val.string;
                        
                        const new_text_copy = try self.allocator.dupe(u8, new_text_str);
                        errdefer self.allocator.free(new_text_copy);
                        
                        try edits.append(TextEdit{
                            .range = Range{
                                .start = Position{ .line = start_line, .character = start_char },
                                .end = Position{ .line = end_line, .character = end_char },
                            },
                            .new_text = new_text_copy,
                        });
                    }
                }
                
                return try edits.toOwnedSlice();
            }
        }
        return null;
    }
    
    /// Formatting options for document formatting.
    pub const FormattingOptions = struct {
        tab_size: u32, // Number of spaces per tab
        insert_spaces: bool, // Use spaces instead of tabs
    };
    
    /// Send textDocument/didOpen notification (document opened).
    pub fn didOpen(self: *LspClient, uri: []const u8, text: []const u8) !void {
        // Assert: URI and text must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        std.debug.assert(text.len <= 100 * 1024 * 1024); // Bounded text size (100MB)
        
        // Assert: Bounded snapshots
        std.debug.assert(self.snapshots.items.len < MAX_SNAPSHOTS);
        
        // Create snapshot
        const snapshot = DocumentSnapshot{
            .id = self.current_snapshot_id,
            .uri = try self.allocator.dupe(u8, uri),
            .version = 0,
            .text = try self.allocator.dupe(u8, text),
        };
        self.current_snapshot_id += 1;
        
        try self.snapshots.append(self.allocator, snapshot);
        
        // Assert: Snapshot added successfully
        std.debug.assert(self.snapshots.items.len <= MAX_SNAPSHOTS);
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try text_doc_obj.put("languageId", std.json.Value{ .string = "zig" });
        try text_doc_obj.put("version", std.json.Value{ .integer = 0 });
        try text_doc_obj.put("text", std.json.Value{ .string = text });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        const params = std.json.Value{ .object = params_obj };
        try self.sendNotification("textDocument/didOpen", params);
    }
    
    /// Send textDocument/didChange notification (incremental update, Matklad snapshot model).
    pub fn didChange(self: *LspClient, uri: []const u8, changes: []const TextDocumentChange) !void {
        // Find existing snapshot
        var snapshot_idx: ?u32 = null;
        for (self.snapshots.items, 0..) |*snapshot, i| {
            if (std.mem.eql(u8, snapshot.uri, uri)) {
                // Assert: Index fits in u32
                std.debug.assert(i <= std.math.maxInt(u32));
                snapshot_idx = @intCast(i);
                break;
            }
        }
        
        // Assert: Snapshot must exist
        std.debug.assert(snapshot_idx != null);
        const snapshot = &self.snapshots.items[snapshot_idx.?];
        
        // Apply incremental changes (Matklad snapshot model)
        var new_text = try self.allocator.dupe(u8, snapshot.text);
        errdefer self.allocator.free(new_text);
        
        for (changes) |change| {
            if (change.range) |range| {
                // Incremental edit: replace range with new text
                const start_byte = try self.positionToByte(snapshot.text, range.start);
                const end_byte = try self.positionToByte(snapshot.text, range.end);
                
                // Replace range in text
                var updated = try self.allocator.alloc(u8, new_text.len - (end_byte - start_byte) + change.text.len);
                @memcpy(updated[0..start_byte], new_text[0..start_byte]);
                @memcpy(updated[start_byte..start_byte + change.text.len], change.text);
                @memcpy(updated[start_byte + change.text.len..], new_text[end_byte..]);
                
                self.allocator.free(new_text);
                new_text = updated;
            } else {
                // Full document replacement
                self.allocator.free(new_text);
                new_text = try self.allocator.dupe(u8, change.text);
            }
        }
        
        // Update snapshot
        self.allocator.free(snapshot.text);
        snapshot.text = new_text;
        snapshot.version += 1;
        
        // Build LSP params
        var change_objects = std.ArrayList(std.json.Value){ .items = &.{}, .capacity = 0 };
        defer change_objects.deinit(self.allocator);
        
        for (changes) |change| {
            var change_obj = std.json.ObjectMap.init(self.allocator);
            if (change.range) |range| {
                var range_obj = std.json.ObjectMap.init(self.allocator);
                
                var start_obj = std.json.ObjectMap.init(self.allocator);
                try start_obj.put("line", std.json.Value{ .integer = @intCast(range.start.line) });
                try start_obj.put("character", std.json.Value{ .integer = @intCast(range.start.character) });
                try range_obj.put("start", std.json.Value{ .object = start_obj });
                
                var end_obj = std.json.ObjectMap.init(self.allocator);
                try end_obj.put("line", std.json.Value{ .integer = @intCast(range.end.line) });
                try end_obj.put("character", std.json.Value{ .integer = @intCast(range.end.character) });
                try range_obj.put("end", std.json.Value{ .object = end_obj });
                
                try change_obj.put("range", std.json.Value{ .object = range_obj });
                
                if (change.range_length) |len| {
                    try change_obj.put("rangeLength", std.json.Value{ .integer = @intCast(len) });
                }
            }
            try change_obj.put("text", std.json.Value{ .string = change.text });
            try change_objects.append(self.allocator, std.json.Value{ .object = change_obj });
        }
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try text_doc_obj.put("version", std.json.Value{ .integer = @intCast(snapshot.version) });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        const changes_slice = try change_objects.toOwnedSlice(self.allocator);
        try params_obj.put("contentChanges", std.json.Value{ .array = .{ .items = changes_slice, .capacity = changes_slice.len, .allocator = self.allocator } });
        
        const params = std.json.Value{ .object = params_obj };
        try self.sendNotification("textDocument/didChange", params);
    }
    
    /// Request textDocument/willSave (check if save should proceed).
    /// Why: Allow LSP server to request save confirmation or prepare for save.
    /// Contract: uri must be valid, reason must be valid (1=Manual, 2=AfterDelay, 3=FocusOut).
    /// Returns: True if save should proceed, false if save should be cancelled.
    pub fn requestWillSave(self: *LspClient, uri: []const u8, reason: u32) !bool {
        // Assert: URI must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        // Assert: Reason must be valid (1=Manual, 2=AfterDelay, 3=FocusOut)
        std.debug.assert(reason >= 1);
        std.debug.assert(reason <= 3);
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        try params_obj.put("reason", std.json.Value{ .integer = @intCast(reason) });
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/willSave", params);
        
        // WillSave is a notification, but some servers may respond
        // For now, assume save should proceed unless server explicitly rejects
        _ = response;
        return true;
    }
    
    /// Request textDocument/willSaveWaitUntil (get text edits before save).
    /// Why: Allow LSP server to provide text edits that should be applied before save.
    /// Contract: uri must be valid, reason must be valid (1=Manual, 2=AfterDelay, 3=FocusOut).
    /// Returns: Array of text edits to apply before save, or null if no edits needed.
    /// Note: Caller must free the returned edits array and new_text strings.
    pub fn requestWillSaveWaitUntil(
        self: *LspClient,
        uri: []const u8,
        reason: u32,
    ) !?[]TextEdit {
        // Assert: URI must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        // Assert: Reason must be valid (1=Manual, 2=AfterDelay, 3=FocusOut)
        std.debug.assert(reason >= 1);
        std.debug.assert(reason <= 3);
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        try params_obj.put("reason", std.json.Value{ .integer = @intCast(reason) });
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/willSaveWaitUntil", params);
        
        // Parse text edits array from response.result (same as document formatting)
        if (response.result) |result| {
            if (result == .array) {
                const items = result.array.items;
                var edits = std.ArrayList(TextEdit).init(self.allocator);
                errdefer {
                    // Free any allocated text on error
                    for (edits.items) |*edit| {
                        self.allocator.free(edit.new_text);
                    }
                    edits.deinit();
                }
                
                for (items) |item| {
                    if (item == .object) {
                        const obj = item.object;
                        
                        // Parse range
                        const range_val = obj.get("range") orelse continue;
                        if (range_val != .object) continue;
                        const inner_range_obj = range_val.object;
                        
                        const start_val = inner_range_obj.get("start") orelse continue;
                        const end_val = inner_range_obj.get("end") orelse continue;
                        if (start_val != .object or end_val != .object) continue;
                        
                        const inner_start_obj = start_val.object;
                        const inner_end_obj = end_val.object;
                        
                        const start_line_val = inner_start_obj.get("line") orelse continue;
                        const start_char_val = inner_start_obj.get("character") orelse continue;
                        const end_line_val = inner_end_obj.get("line") orelse continue;
                        const end_char_val = inner_end_obj.get("character") orelse continue;
                        
                        if (start_line_val != .integer or start_char_val != .integer or
                            end_line_val != .integer or end_char_val != .integer) continue;
                        
                        const start_line = @as(u32, @intCast(start_line_val.integer));
                        const start_char = @as(u32, @intCast(start_char_val.integer));
                        const end_line = @as(u32, @intCast(end_line_val.integer));
                        const end_char = @as(u32, @intCast(end_char_val.integer));
                        
                        // Parse newText
                        const new_text_val = obj.get("newText") orelse continue;
                        if (new_text_val != .string) continue;
                        const new_text_str = new_text_val.string;
                        
                        const new_text_copy = try self.allocator.dupe(u8, new_text_str);
                        errdefer self.allocator.free(new_text_copy);
                        
                        try edits.append(TextEdit{
                            .range = Range{
                                .start = Position{ .line = start_line, .character = start_char },
                                .end = Position{ .line = end_line, .character = end_char },
                            },
                            .new_text = new_text_copy,
                        });
                    }
                }
                
                return try edits.toOwnedSlice();
            }
        }
        return null;
    }
    
    /// Send textDocument/didSave notification (document saved).
    /// Why: Notify LSP server that document was saved.
    /// Contract: uri must be valid, text is optional (includeText parameter).
    pub fn didSave(self: *LspClient, uri: []const u8, text: ?[]const u8) !void {
        // Assert: URI must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        if (text) |t| {
            std.debug.assert(t.len <= 100 * 1024 * 1024); // Bounded text size (100MB)
        }
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        // Include text if provided
        if (text) |t| {
            try params_obj.put("text", std.json.Value{ .string = t });
        }
        
        const params = std.json.Value{ .object = params_obj };
        try self.sendNotification("textDocument/didSave", params);
    }
    
    /// Send textDocument/didClose notification (document closed).
    /// Why: Notify LSP server that document was closed.
    /// Contract: uri must be valid.
    pub fn didClose(self: *LspClient, uri: []const u8) !void {
        // Assert: URI must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        const params = std.json.Value{ .object = params_obj };
        try self.sendNotification("textDocument/didClose", params);
        
        // Remove snapshot for closed document
        var snapshot_idx: ?u32 = null;
        for (self.snapshots.items, 0..) |*snapshot, i| {
            if (std.mem.eql(u8, snapshot.uri, uri)) {
                // Assert: Index fits in u32
                std.debug.assert(i <= std.math.maxInt(u32));
                snapshot_idx = @intCast(i);
                break;
            }
        }
        
        if (snapshot_idx) |idx| {
            const snapshot = &self.snapshots.items[idx];
            self.allocator.free(snapshot.uri);
            self.allocator.free(snapshot.text);
            _ = self.snapshots.swapRemove(idx);
        }
        
        // Remove diagnostics for closed document
        if (self.diagnostics.get(uri)) |diags| {
            for (diags.items) |*diag| {
                self.allocator.free(diag.message);
                if (diag.source) |source| {
                    self.allocator.free(source);
                }
            }
            diags.deinit(self.allocator);
            _ = self.diagnostics.remove(uri);
        }
    }
    
    /// Cancel a pending request.
    pub fn cancelRequest(self: *LspClient, request_id: u64) !void {
        // Assert: Request must be pending
        std.debug.assert(self.pending_requests.contains(request_id));
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        try params_obj.put("id", std.json.Value{ .integer = @intCast(request_id) });
        
        const params = std.json.Value{ .object = params_obj };
        try self.sendNotification("$/cancelRequest", params);
        _ = self.pending_requests.remove(request_id);
    }
    
    /// Convert LSP Position to byte offset in text (for incremental edits).
    fn positionToByte(self: *LspClient, text: []const u8, pos: Position) !u32 {
        _ = self;
        var byte: u32 = 0;
        var line: u32 = 0;
        var char: u32 = 0;
        
        for (text) |c| {
            if (line == pos.line and char == pos.character) {
                return byte;
            }
            byte += 1;
            if (c == '\n') {
                line += 1;
                char = 0;
            } else {
                char += 1;
            }
        }
        
        // Position at end of document
        if (line == pos.line and char == pos.character) {
            return byte;
        }
        
        return error.InvalidPosition;
    }

    /// Serialize JSON Value to string (manual implementation for Zig 0.15 compatibility).
    /// Bounded: Max 10MB JSON output.
    fn serialize_json_value(
        self: *LspClient,
        value: std.json.Value,
    ) ![]const u8 {
        var buffer = std.ArrayList(u8){ .items = &.{}, .capacity = 0 };
        errdefer buffer.deinit(self.allocator);
        const writer = buffer.writer(self.allocator);
        
        try self.write_json_value(writer, value);
        
        return try buffer.toOwnedSlice(self.allocator);
    }
    
    /// Recursively write JSON value to writer.
    fn write_json_value(
        self: *LspClient,
        writer: anytype,
        value: std.json.Value,
    ) !void {
        switch (value) {
            .string => |s| {
                try writer.writeByte('"');
                // Escape JSON special characters
                for (s) |ch| {
                    switch (ch) {
                        '"' => try writer.writeAll("\\\""),
                        '\\' => try writer.writeAll("\\\\"),
                        '\n' => try writer.writeAll("\\n"),
                        '\r' => try writer.writeAll("\\r"),
                        '\t' => try writer.writeAll("\\t"),
                        else => try writer.writeByte(ch),
                    }
                }
                try writer.writeByte('"');
            },
            .integer => |i| try writer.print("{d}", .{i}),
            .float => |f| try writer.print("{d}", .{f}),
            .bool => |b| try writer.print("{}", .{b}),
            .null => try writer.writeAll("null"),
            .array => |arr| {
                try writer.writeByte('[');
                for (arr.items, 0..) |item, i| {
                    if (i > 0) try writer.writeByte(',');
                    try self.write_json_value(writer, item);
                }
                try writer.writeByte(']');
            },
            .object => |obj| {
                try writer.writeByte('{');
                var it = obj.iterator();
                var first = true;
                while (it.next()) |entry| {
                    if (!first) try writer.writeByte(',');
                    first = false;
                    // Write key
                    try writer.writeByte('"');
                    try writer.writeAll(entry.key_ptr.*);
                    try writer.writeByte('"');
                    try writer.writeByte(':');
                    // Write value
                    try self.write_json_value(writer, entry.value_ptr.*);
                }
                try writer.writeByte('}');
            },
            .number_string => |ns| {
                // Number stored as string (e.g., "123")
                try writer.writeAll(ns);
            },
        }
    }
    
    /// Send a JSON-RPC request; returns response message.
    fn sendRequest(
        self: *LspClient,
        method: []const u8,
        params: std.json.Value,
    ) !Message {
        const id = self.request_id;
        self.request_id += 1;
        
        // Assert: Bounded pending requests
        std.debug.assert(self.pending_requests.count() < MAX_PENDING_REQUESTS);
        try self.pending_requests.put(id, {});
        
        // Build request object
        var request_obj = std.json.ObjectMap.init(self.allocator);
        defer request_obj.deinit();
        try request_obj.put("jsonrpc", std.json.Value{ .string = "2.0" });
        try request_obj.put("id", std.json.Value{ .integer = @intCast(id) });
        try request_obj.put("method", std.json.Value{ .string = method });
        try request_obj.put("params", params);
        
        // Serialize to JSON string
        const request_value = std.json.Value{ .object = request_obj };
        const json_string = try self.serialize_json_value(request_value);
        defer self.allocator.free(json_string);
        
        // Write to server stdin (LSP uses Content-Length header)
        if (self.server_process) |*proc| {
            const stdin = proc.stdin orelse return error.NoStdin;
            const header = try std.fmt.allocPrint(
                self.allocator,
                "Content-Length: {d}\r\n\r\n",
                .{json_string.len},
            );
            defer self.allocator.free(header);
            
            try stdin.writeAll(header);
            try stdin.writeAll(json_string);
        }
        
        // Read response from server stdout
        const response = try self.readResponse();
        _ = self.pending_requests.remove(id);
        
        return response;
    }
    
    /// Send a JSON-RPC notification (no response expected).
    fn sendNotification(
        self: *LspClient,
        method: []const u8,
        params: std.json.Value,
    ) !void {
        // Build notification object
        var notification_obj = std.json.ObjectMap.init(self.allocator);
        defer notification_obj.deinit();
        try notification_obj.put("jsonrpc", std.json.Value{ .string = "2.0" });
        try notification_obj.put("method", std.json.Value{ .string = method });
        try notification_obj.put("params", params);
        
        // Serialize to JSON string
        const notification_value = std.json.Value{ .object = notification_obj };
        const json_string = try self.serialize_json_value(notification_value);
        defer self.allocator.free(json_string);
        
        // Write to server stdin
        if (self.server_process) |*proc| {
            const stdin = proc.stdin orelse return error.NoStdin;
            const header = try std.fmt.allocPrint(
                self.allocator,
                "Content-Length: {d}\r\n\r\n",
                .{json_string.len},
            );
            defer self.allocator.free(header);
            
            try stdin.writeAll(header);
            try stdin.writeAll(json_string);
        }
    }
    
    /// Read JSON-RPC response from server stdout.
    fn readResponse(self: *LspClient) !Message {
        if (self.server_process == null) return error.NoServer;
        const stdout = self.server_process.?.stdout orelse return error.NoStdout;
        
        // Read Content-Length header
        // Bounded: Max 1024 bytes for header
        var header_buf: [1024]u8 = undefined;
        var header_len: u32 = 0;
        
        // Assert: Bounded header length
        std.debug.assert(header_buf.len <= std.math.maxInt(u32));
        while (header_len < header_buf.len) {
            const byte = try stdout.readByte();
            // Assert: Header length within bounds
            std.debug.assert(header_len < header_buf.len);
            header_buf[header_len] = byte;
            header_len += 1;
            
            if (header_len >= 2 and header_buf[header_len - 2] == '\r' and header_buf[header_len - 1] == '\n') {
                if (header_len >= 4 and 
                    header_buf[header_len - 4] == '\r' and 
                    header_buf[header_len - 3] == '\n') {
                    // Double CRLF: end of headers
                    break;
                }
            }
        }
        
        // Parse Content-Length
        const header_str = header_buf[0..header_len];
        var content_length: u32 = 0;
        if (std.mem.indexOf(u8, header_str, "Content-Length: ")) |idx| {
            const start = idx + "Content-Length: ".len;
            const end = std.mem.indexOfScalar(u8, header_str[start..], '\r') orelse header_str.len;
            // Assert: Content length fits in u32
            const parsed = try std.fmt.parseInt(u64, header_str[start..end], 10);
            std.debug.assert(parsed <= std.math.maxInt(u32));
            content_length = @intCast(parsed);
        }
        
        // Assert: Bounded content length (prevent memory exhaustion)
        std.debug.assert(content_length <= 10 * 1024 * 1024); // Max 10MB
        
        // Read JSON body
        var json_buf = try self.allocator.alloc(u8, content_length);
        defer self.allocator.free(json_buf);
        
        var bytes_read: u32 = 0;
        while (bytes_read < content_length) {
            const read_count = try stdout.read(json_buf[bytes_read..]);
            // Assert: Read count fits in u32
            std.debug.assert(read_count <= std.math.maxInt(u32));
            bytes_read += @intCast(read_count);
        }
        
        // Assert: All bytes read
        std.debug.assert(bytes_read == content_length);
        
        // Parse JSON response
        var parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            json_buf,
            .{},
        );
        defer parsed.deinit();
        
        const root = parsed.value;
        var message = Message{};
        
        if (root == .object) {
            const obj = root.object;
            if (obj.get("id")) |id| {
                message.id = @intCast(id.integer);
            }
            if (obj.get("method")) |method| {
                message.method = method.string;
            }
            if (obj.get("result")) |result| {
                message.result = result;
            }
            if (obj.get("error")) |err| {
                if (err == .object) {
                    const err_obj = err.object;
                    message.lsp_error = LspError{
                        .code = if (err_obj.get("code")) |c| @intCast(c.integer) else 0,
                        .message = if (err_obj.get("message")) |m| m.string else "",
                        .data = if (err_obj.get("data")) |d| d else null,
                    };
                }
            }
        }
        
        return message;
    }
};

test "lsp client lifecycle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var client = LspClient.init(arena.allocator());
    defer client.deinit();
    // Stub: don't actually spawn ZLS in tests.
}

test "lsp snapshot model" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var client = LspClient.init(arena.allocator());
    defer client.deinit();
    
    // Test snapshot creation
    try client.didOpen("file:///test.zig", "const x = 1;");
    std.debug.assert(client.snapshots.items.len == 1);
    std.debug.assert(client.snapshots.items[0].version == 0);
    
    // Test incremental change
    const change = LspClient.TextDocumentChange{
        .range = LspClient.Range{
            .start = LspClient.Position{ .line = 0, .character = 10 },
            .end = LspClient.Position{ .line = 0, .character = 11 },
        },
        .text = "2",
    };
    try client.didChange("file:///test.zig", &.{change});
    std.debug.assert(client.snapshots.items[0].version == 1);
    std.debug.assert(std.mem.eql(u8, client.snapshots.items[0].text, "const x = 2;"));
}

