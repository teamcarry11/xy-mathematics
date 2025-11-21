//! grainwrap: precise code wrapping for grain network
//!
//! What is grainwrap? It's how we enforce width constraints on zig
//! code, ensuring it fits perfectly in graincard displays.
//!
//! Every line is measured. Every violation is reported. Every wrap
//! preserves readability. That's the grainwrap way.

const std = @import("std");

// Re-export our modules for external use.
//
// Why re-export? This pattern creates a clean public API.
// Users import "grainwrap" and get everything they need,
// but internally we keep concerns separated into modules.
pub const types = @import("types.zig");
pub const validate_mod = @import("validate.zig");
pub const wrap_mod = @import("wrap.zig");

// Re-export commonly used types for convenience.
pub const Violation = types.Violation;
pub const WrapConfig = types.WrapConfig;
pub const ValidationResult = types.ValidationResult;

// Re-export functions with shorter names.
pub const validate = validate_mod.validate;
pub const free_result = validate_mod.free_result;
pub const wrap = wrap_mod.wrap;

// Default configuration for graincard compatibility.
//
// 73 characters is the graincard content width (75 total - 2 borders).
// This ensures code fits perfectly when displayed in graincards.
pub const default_config = types.WrapConfig{
    .max_width = 73,
    .preserve_indentation = true,
    .break_on_operators = true,
};

test "grainwrap module" {
    const testing = std.testing;
    _ = testing;

    // This test just ensures all modules compile and link.
    // Individual functionality is tested in their respective
    // module files.
}

