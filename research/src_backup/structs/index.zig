/// Struct definitions index: re-exports all struct definitions.
/// ~<~ Glow Earthbend: all structs visible in one place for easy review.
///
/// This file provides a central location to view all struct definitions
/// across the codebase. Structs remain in their implementation files for
/// tight coupling, but are re-exported here for documentation and review.

// Platform structs
pub const Platform = @import("../platform.zig").Platform;
pub const PlatformVTable = Platform.VTable;
pub const MacWindow = @import("../platform/macos_tahoe/window.zig").Window;
pub const RiscvWindow = @import("../platform/riscv/impl.zig").RiscvWindow;
pub const NullWindow = @import("../platform/null/impl.zig").NullWindow;

// Aurora UI structs
pub const GrainAurora = @import("../grain_aurora.zig").GrainAurora;
pub const AuroraNode = GrainAurora.Node;
pub const AuroraColumn = GrainAurora.Column;
pub const AuroraRow = GrainAurora.Row;
pub const AuroraButton = GrainAurora.Button;
pub const AuroraRenderContext = GrainAurora.RenderContext;
pub const AuroraRenderResult = GrainAurora.RenderResult;
pub const AuroraSpan = GrainAurora.Span;
pub const TextRenderer = @import("../aurora_text_renderer.zig").TextRenderer;
pub const FluxState = @import("../aurora_filter.zig").FluxState;

// Sandbox structs
pub const TahoeSandbox = @import("../tahoe_window.zig").TahoeSandbox;

// LSP structs
pub const LspClient = @import("../aurora_lsp.zig").LspClient;
pub const LspMessage = LspClient.Message;
pub const LspError = LspClient.LspError;
pub const CompletionItem = LspClient.CompletionItem;
pub const Diagnostic = LspClient.Diagnostic;
pub const LspRange = LspClient.Range;
pub const LspPosition = LspClient.Position;

// Editor structs
pub const Editor = @import("../aurora_editor.zig").Editor;

// Crash handler structs
pub const CrashHandler = @import("../aurora_crash.zig").CrashHandler;

