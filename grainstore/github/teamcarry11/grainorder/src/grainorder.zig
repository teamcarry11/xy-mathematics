//! grainorder: permutation-based chronological file naming
//!
//! this is the main module that brings together all the pieces:
//! alphabet, core algorithm, and validation.
//!
//! **what is grainorder?**
//!
//! imagine you have markdown files on github. github sorts
//! them A→Z alphabetically. you want the NEWEST files at the
//! TOP. how do you make that happen?
//!
//! give newer files SMALLER prefixes! like this:
//!   bchlnp-newest.md   ← appears first (smallest)
//!   bchlnq-middle.md   ← appears second
//!   zyxvsq-oldest.md   ← appears last (largest)
//!
//! grainorder generates these prefixes using:
//! - 6 characters from an 11-letter alphabet (bchlnpqsxyz)
//! - all characters unique (no repeats!)
//! - 332,640 possible codes
//! - deterministic decrement algorithm
//!
//! **grain style principles applied:**
//! - explicit limits (bounded to 332,640 codes)
//! - clear validation (helpful error messages)
//! - code that teaches (every function explains itself)
//! - decomplected design (alphabet, core, validation separate)

// hey, what's "std", short for "standard"? great question!
//
// "std" is zig's standard library - it's like a toolbox that
// comes with zig. it has all the basic tools you need:
// - printing to the screen
// - working with files
// - doing math
// - managing memory
//
// we import it here so we can use those tools throughout
// grainorder. does that make sense?
const std = @import("std");

// okay, now what's "re-exporting"? let me explain!
//
// we have three separate files (alphabet.zig, core.zig,
// validation.zig). each one is like a chapter in a book.
//
// instead of making people import each chapter separately:
//   const alphabet = @import("alphabet.zig");
//   const core = @import("core.zig");
//   const validation = @import("validation.zig");
//
// we "re-export" them here, so people can just import
// grainorder once and get everything!
//   const grainorder = @import("grainorder");
//   grainorder.alphabet  ← has everything from alphabet.zig
//   grainorder.core      ← has everything from core.zig
//
// it's like a table of contents that also includes the
// chapters themselves. neat, right? this is called
// "decomplecting" - we keep the code separate (easy to
// understand) but make it easy to use together! 🌾
pub const alphabet = @import("alphabet.zig");
pub const core = @import("core.zig");
pub const validation = @import("validation.zig");

// re-export the main types
pub const Grainorder = core.Grainorder;
pub const ValidationError = validation.ValidationError;

// re-export key functions
pub const prev = core.Grainorder.prev;
pub const from_string = core.Grainorder.from_string;
pub const is_valid = validation.is_valid;
pub const validate = validation.validate;

// constants for easy reference
pub const ALPHABET = alphabet.alphabet;
pub const CODE_LEN = alphabet.code_len;
pub const MAX_CODES = alphabet.max_codes;

// special grainorders with meaning
pub const ARCHIVE = "zyxsqp"; // largest possible, always last
pub const MINIMUM = "bchlnp"; // smallest possible, absolute minimum

test {
    // run all tests from submodules
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(alphabet);
    std.testing.refAllDecls(core);
    std.testing.refAllDecls(validation);
}

