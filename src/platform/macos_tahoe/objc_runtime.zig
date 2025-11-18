/// Shared Objective-C runtime C import for macOS platform.
/// Why: Ensures type compatibility across cocoa_bridge.zig and window.zig.
/// 
/// Pointer design (GrainStyle single-level only):
/// - All Objective-C runtime types use single-level pointers.
/// Note: We don't include Foundation.h here because it requires Objective-C syntax.
/// The Objective-C runtime functions work without it, and Foundation framework
/// classes are available once the framework is linked.
pub const c = @cImport({
    @cInclude("objc/runtime.h");
    @cInclude("objc/message.h");
});

/// Core Graphics imports for image creation and drawing.
pub const cg = @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
});

