//! core: the heart of grainorder - the prev algorithm
//!
//! hey! this is where the magic happens. let me show you!
//!
//! imagine you have a grainorder like "xsqnml". how do we find
//! the next SMALLER one? "xsqnmh"!
//!
//! why do we want smaller? great question! on github, files
//! sort A→Z (alphabetically). so if newer files have SMALLER
//! codes, they appear at the TOP! it's like putting your newest
//! homework on top of the pile. does that make sense?
//!
//! the algorithm is just like counting backwards with carrying:
//! think of an odometer in reverse! 100 → 99 → 98...
//!
//! we start at position 1 (the "ones place") and try to
//! decrement. if we can't, we carry left to position 2
//! (the "tens place"), then 3, 4, 5, 6. just like regular math!
//!
//! when we successfully decrement a position, we reset all
//! positions to the right to their LARGEST available values.
//! this maximizes the space for future decrements. let me show
//! you how it works! 🌾

const std = @import("std");
const alphabet = @import("alphabet.zig");

// a grainorder is exactly 6 characters from our alphabet,
// with no repeating characters. think of it like a unique
// ID that also encodes its position in time.
pub const Grainorder = struct {
    chars: [alphabet.code_len]u8,

    // hey, this is the main function! it finds the next SMALLER
    // grainorder (which means newer in time!).
    //
    // let me walk you through how it works. imagine you're
    // counting backwards: 427 → 426 → 425...
    //
    // you start at the rightmost digit (the "ones place") and
    // try to subtract 1. if you can't (like when you hit 0),
    // you carry left to the "tens place". same idea here!
    //
    // we use "place value" thinking:
    // - position 1 = rightmost (like "ones place")
    // - position 6 = leftmost (like "hundred-thousands place")
    //
    // start at position 1 and try to decrement. if we can't,
    // carry left. if we can't decrement ANY position... we've
    // reached the absolute minimum! overflow!
    //
    // does this make sense? it's just like regular counting
    // backwards, but with our special alphabet! 🌾
    pub fn prev(self: *const Grainorder) ?Grainorder {
        // grain style: validate input before we start!
        // this way we catch problems early.
        std.debug.assert(self.is_valid());

        // position 1 = index 5 (rightmost, "ones place")
        // position 6 = index 0 (leftmost, "deepest")
        //
        // why reversed? because we START at the ones place
        // (rightmost) and carry LEFT when needed, just like
        // regular arithmetic!
        return try_position(self, 1);
    }

    // okay, this is our helper function! it tries to decrement
    // at a specific position.
    //
    // think of it like this: you're at the "ones place" (position 1).
    // can you subtract 1? yes? great! do it and reset everything
    // to the right. no? then carry left to the "tens place"
    // (position 2) and try again!
    //
    // let me show you an example:
    // "xsqnml" at position 1:
    // - current char: 'l'
    // - can we find something smaller? yes! 'h'!
    // - result: "xsqnmh"
    //
    // does this make sense?
    fn try_position(
        self: *const Grainorder,
        pos: usize,
    ) ?Grainorder {
        // overflow check: did we carry past position 6?
        // if yes, we've exhausted all codes! (reached minimum)
        if (pos > alphabet.code_len) {
            return null; // overflow! no more codes available
        }

        // get everything to the left (the deeper positions)
        // these are the chars we've already placed
        const left = self.left_of(pos);

        // get the character at THIS position
        const char_here = self.char_at(pos);

        // try to find a smaller character that's not in "left"
        // (not already used)
        const smaller = alphabet.find_smaller(char_here, left);

        if (smaller) |s| {
            // found it! build new grainorder:
            // 1. keep everything to the left
            // 2. use the smaller character here
            // 3. reset positions to the right to largest

            var result: Grainorder = undefined;
            var built_len: usize = 0;

            // copy left part
            for (left) |c| {
                result.chars[built_len] = c;
                built_len += 1;
            }

            // add smaller character
            result.chars[built_len] = s;
            built_len += 1;

            // reset positions to the right to largest
            var p: isize = @intCast(pos);
            p -= 1;
            while (p >= 1) : (p -= 1) {
                const forbidden = result.chars[0..built_len];
                if (alphabet.find_largest(forbidden)) |largest| {
                    result.chars[built_len] = largest;
                    built_len += 1;
                } else {
                    break; // couldn't find largest (shouldn't
                           // happen!)
                }
            }

            // grain style: validate output
            std.debug.assert(result.is_valid());

            return result;
        } else {
            // couldn't decrement here, carry left (go deeper)
            return try_position(self, pos + 1);
        }
    }

    // get everything to the LEFT of a position (deeper layers)
    //
    // example with "xsqnml" at position 3:
    //   x  s  q  n  m  l
    //   6  5  4  3  2  1  ← positions
    //         ↑
    //      pos 3
    //   ← "xsq" (positions 6, 5, 4)
    fn left_of(self: *const Grainorder, pos: usize) []const u8 {
        const idx = pos_to_idx(pos);
        return self.chars[0..idx];
    }

    // get the character at a position
    //
    // position 1 = index 5 (rightmost)
    // position 6 = index 0 (leftmost)
    fn char_at(self: *const Grainorder, pos: usize) u8 {
        return self.chars[pos_to_idx(pos)];
    }

    // convert position (1-6) to index (5-0)
    //
    // why reversed? so position 1 is the "ones place" where
    // we start, and position 6 is the "deepest" layer where
    // we overflow. this matches how we think about place value!
    fn pos_to_idx(pos: usize) usize {
        return alphabet.code_len - pos;
    }

    // check if this grainorder is valid
    //
    // rules:
    // 1. exactly 6 characters
    // 2. all characters in our alphabet
    // 3. no repeating characters
    pub fn is_valid(self: *const Grainorder) bool {
        // check all chars are in alphabet and unique
        var seen = std.StaticBitSet(256).initEmpty();

        for (self.chars) |c| {
            // in alphabet?
            if (!alphabet.char_in_alphabet(c)) {
                return false;
            }

            // already seen (duplicate)?
            if (seen.isSet(c)) {
                return false;
            }

            seen.set(c);
        }

        return true;
    }

    // create a grainorder from a string
    pub fn from_string(str: []const u8) !Grainorder {
        if (str.len != alphabet.code_len) {
            return error.InvalidLength;
        }

        var result: Grainorder = undefined;
        @memcpy(&result.chars, str[0..alphabet.code_len]);

        if (!result.is_valid()) {
            return error.InvalidGrainorder;
        }

        return result;
    }

    // format for printing
    pub fn format(
        self: Grainorder,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.writeAll(&self.chars);
    }
};

test "prev grainorder - basic" {
    const testing = std.testing;

    // xsqyl → xsqyh (decrement position 1)
    const current = try Grainorder.from_string("xsqyl");
    const next = current.prev();

    try testing.expect(next != null);
    try testing.expectEqualStrings("xsqyh", &next.?.chars);
}

test "prev grainorder - carry" {
    const testing = std.testing;

    // xsqyh → xsqyc (position 1 decrements from h to c)
    const current = try Grainorder.from_string("xsqyh");
    const next = current.prev();

    try testing.expect(next != null);
    // position 1 decrements from h to c (smaller than h, not in "xsqy")
    try testing.expectEqualStrings("xsqyc", &next.?.chars);
}

test "prev grainorder - overflow" {
    const testing = std.testing;

    // bchlnp → null (absolute minimum!)
    const current = try Grainorder.from_string("bchlnp");
    const next = current.prev();

    try testing.expect(next == null); // overflow!
}

