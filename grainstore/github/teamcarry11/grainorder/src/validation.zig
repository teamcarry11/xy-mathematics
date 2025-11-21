//! validation: checking if grainorders are correct
//!
//! when you're working with file names and database IDs, you
//! need to know: is this a valid grainorder? this module
//! provides clear, helpful validation.
//!
//! grain style principle: explicit validation with helpful
//! error messages. never silently accept bad input!

const std = @import("std");
const alphabet = @import("alphabet.zig");
const Grainorder = @import("core.zig").Grainorder;

// validation errors - each one tells you exactly what went
// wrong. no mysterious "invalid input" messages!
pub const ValidationError = error{
    TooShort,
    TooLong,
    InvalidCharacter,
    DuplicateCharacter,
};

// validate a string and return helpful error if invalid
//
// this is more detailed than Grainorder.isValid() because
// it tells you WHAT'S wrong, not just that it's wrong.
pub fn validate(str: []const u8) ValidationError!void {
    // check length
    if (str.len < alphabet.code_len) {
        return error.TooShort;
    }
    if (str.len > alphabet.code_len) {
        return error.TooLong;
    }

    // check all characters
    var seen = std.StaticBitSet(256).initEmpty();

    for (str) |c| {
        // in alphabet?
        if (!alphabet.char_in_alphabet(c)) {
            return error.InvalidCharacter;
        }

        // duplicate?
        if (seen.isSet(c)) {
            return error.DuplicateCharacter;
        }

        seen.set(c);
    }
}

// check if a string is a valid grainorder (yes/no)
pub fn is_valid(str: []const u8) bool {
    validate(str) catch return false;
    return true;
}

test "validation - valid codes" {
    const testing = std.testing;

    // all valid!
    try validate("xsqyl");
    try validate("bchlnp");
    try validate("zyxsqp");

    try testing.expect(is_valid("xsqyl"));
}

test "validation - too short" {
    const testing = std.testing;

    const result = validate("xsqn");
    try testing.expectError(error.TooShort, result);

    try testing.expect(!is_valid("xsqn"));
}

test "validation - too long" {
    const testing = std.testing;

    const result = validate("xsqylp");
    try testing.expectError(error.TooLong, result);

    try testing.expect(!is_valid("xsqylp"));
}

test "validation - invalid character" {
    const testing = std.testing;

    // 'a' is not in our alphabet
    const result = validate("avsnml");
    try testing.expectError(error.InvalidCharacter, result);

    try testing.expect(!is_valid("avsnml"));
}

test "validation - duplicate character" {
    const testing = std.testing;

    // 'x' appears twice
    const result = validate("xsqxl");
    try testing.expectError(error.DuplicateCharacter, result);

    try testing.expect(!is_valid("xsqxl"));
}

