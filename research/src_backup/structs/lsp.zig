const std = @import("std");

/// LSP client structs: Language Server Protocol communication.
/// All LSP-related struct definitions in one place.

/// LSP message: JSON-RPC 2.0 protocol message.
pub const LspMessage = struct {
    jsonrpc: []const u8 = "2.0",
    id: ?u64 = null,
    method: ?[]const u8 = null,
    params: ?std.json.Value = null,
    result: ?std.json.Value = null,
    lsp_error: ?LspError = null,
};

/// LSP error: error code, message, and optional data.
pub const LspError = struct {
    code: i32,
    message: []const u8,
    data: ?std.json.Value = null,
};

/// Completion item: code completion suggestion from LSP server.
pub const CompletionItem = struct {
    label: []const u8,
    kind: ?u32 = null,
    detail: ?[]const u8 = null,
    documentation: ?[]const u8 = null,
};

/// Diagnostic: error or warning from LSP server.
pub const Diagnostic = struct {
    range: Range,
    severity: ?u32 = null,
    message: []const u8,
    source: ?[]const u8 = null,
};

/// Range: start and end positions in a document.
pub const Range = struct {
    start: Position,
    end: Position,
};

/// Position: line and character offset in a document.
pub const Position = struct {
    line: u32,
    character: u32,
};

