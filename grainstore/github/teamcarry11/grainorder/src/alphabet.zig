//! alphabet: the foundation of grainorder
//!
//! What letters should we use for chronological file names?
//!
//! We chose 11 consonants that are visually distinct, easy to
//! type, and never accidentally form words: bchlnpqsxyz
//!
//! No vowels means codes stay codes (never words like "bad").
//! Already sorted alphabetically for simpler decrement logic.
//! Exactly 11 gives us 332,640 permutations (11×10×9×8×7×6).

const std = @import("std");

// The alphabet is alphabetically sorted so smaller codes
// mean newer files (they rise to the top in A→Z sorting).
//
// Mnemonic: "batch line pick six yeezy" (bch ln pq sx yz)
pub const alphabet = "bchlnpqsxyz";

pub const alphabet_len = alphabet.len; // 11 consonants
pub const code_len = 6; // permutation length
pub const max_codes = 332_640; // 11×10×9×8×7×6

// Find the position of a character in our alphabet.
// Returns null if the character isn't in the alphabet.
//
// Examples: 'b'→0, 'c'→1, 'h'→2, 'z'→10, 'a'→null
pub fn char_position(c: u8) ?usize {
    return std.mem.indexOfScalar(u8, alphabet, c);
}

// Check if a character exists in our alphabet.
pub fn char_in_alphabet(c: u8) bool {
    return char_position(c) != null;
}

// Find the next smaller character that isn't forbidden.
//
// Why smaller? In grainorder, smaller codes mean newer files
// (they rise to the top in A→Z sorting).
//
    // Example: find_smaller('q', "ch") → 'h' is forbidden, so 'c'
    //          is forbidden too, so return 'b'
pub fn find_smaller(c: u8, forbidden: []const u8) ?u8 {
    const pos = char_position(c) orelse return null;

    // start one position earlier and walk backward
    var i: isize = @intCast(pos);
    i -= 1;
    while (i >= 0) : (i -= 1) {
        const candidate = alphabet[@intCast(i)];
        // is this candidate forbidden (already used)?
        if (std.mem.indexOfScalar(u8, forbidden, candidate) ==
            null)
        {
            return candidate; // nope! use it!
        }
    }

    return null; // couldn't find anything smaller
}

// Find the largest character that isn't forbidden.
//
// When decrementing, positions to the right reset to their
// largest available values (like 100→99 resets rightmost to 9).
//
    // Example: find_largest("yz") → 'x' (largest not forbidden)
pub fn find_largest(forbidden: []const u8) ?u8 {
    // start from the end (largest) and work backward
    var i: isize = @intCast(alphabet_len);
    i -= 1;
    while (i >= 0) : (i -= 1) {
        const candidate = alphabet[@intCast(i)];
        if (std.mem.indexOfScalar(u8, forbidden, candidate) ==
            null)
        {
            return candidate; // found it!
        }
    }

    return null; // all characters are forbidden (shouldn't
                 // happen in practice!)
}

// test our alphabet utilities to make sure they work!
test "char position" {
    const testing = std.testing;

    // 'b' is first (position 0)
    try testing.expectEqual(@as(?usize, 0), char_position('b'));

    // 'z' is last (position 10)
    try testing.expectEqual(
        @as(?usize, 10),
        char_position('z'),
    );

    // 'a' isn't in our alphabet
    try testing.expectEqual(@as(?usize, null), char_position('a'));
}

test "find smaller" {
    const testing = std.testing;

    // find smaller than 'z' (not in "bch") → should be 'y'
    try testing.expectEqual(
        @as(?u8, 'y'),
        find_smaller('z', "bch"),
    );

    // find smaller than 'c' (not in "") → should be 'b'
    try testing.expectEqual(@as(?u8, 'b'), find_smaller('c', ""));

    // find smaller than 'b' → null (nothing smaller!)
    try testing.expectEqual(
        @as(?u8, null),
        find_smaller('b', ""),
    );
}

test "find largest" {
    const testing = std.testing;

    // largest not in "yz" → should be 'x'
    try testing.expectEqual(@as(?u8, 'x'), find_largest("yz"));

    // largest not in "" → should be 'z' (the actual largest)
    try testing.expectEqual(@as(?u8, 'z'), find_largest(""));

    // largest not in entire alphabet → null
    try testing.expectEqual(@as(?u8, null), find_largest(alphabet));
}
