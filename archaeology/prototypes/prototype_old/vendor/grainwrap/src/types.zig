//! types: grainwrap data structures
//!
//! What makes up a line violation? What configuration do we need?
//! This module defines the core data structures for grainwrap.

// Line violation represents a line that exceeds the maximum width.
//
// Why separate this into a struct? It makes violations explicit and
// easy to report. You get line number, actual length, and the line
// content itself.
pub const Violation = struct {
    line_number: usize,
    length: usize,
    content: []const u8,
};

// Wrapping configuration for code formatting.
//
// This struct holds all the parameters needed to wrap code properly.
// Making it explicit means callers understand what options they have.
pub const WrapConfig = struct {
    max_width: usize = 73,
    preserve_indentation: bool = true,
    break_on_operators: bool = true,
};

// Validation result containing all violations found.
//
// Why a separate result? It makes the API explicit. You can check
// if there are violations, iterate over them, and handle them
// appropriately. No hidden state, no side effects.
pub const ValidationResult = struct {
    violations: []Violation,
    total_lines: usize,
    compliant: bool,
};

