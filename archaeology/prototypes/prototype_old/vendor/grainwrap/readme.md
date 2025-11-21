# grainwrap

precise code wrapping for grain network

## what is grainwrap?

grainwrap enforces 73-character hard wrapping for zig code, ensuring
perfect fit within graincard constraints. every line is measured,
validated, and wrapped with precision.

when you use grainwrap, you're not just formatting code - you're
aligning it with grain network's visual constraints. 73 characters
per line, 70 lines per function. these limits breed clarity and
force thoughtful design.

## why 73 characters?

graincards are 75×100 monospace teaching cards. with 1-character
borders on each side, the content area is 73 characters wide.

this constraint:
- ensures code fits in graincard displays
- forces concise, clear code
- creates visual consistency across the grain network
- makes code easier to read and understand

## architecture

grainwrap is decomplected into focused modules:

- `types.zig` - data structures and configuration
- `wrap.zig` - line wrapping logic
- `validate.zig` - line length validation
- `grainwrap.zig` - public API and re-exports
- `cli.zig` - command line interface (work in progress - Zig 0.15.2 API)

each module has one clear responsibility. this makes the code
easier to understand, test, and extend.

note: the CLI interface is currently being updated for Zig 0.15.2
API compatibility. the core functionality (validation and wrapping)
works through the library API and test executables.

## usage

### as a library

```zig
const std = @import("std");
const grainwrap = @import("grainwrap");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // validate code
    const code = "const very_long_line_that_exceeds_seventy_three_characters = true;";
    const result = try grainwrap.validate(allocator, code, 73);
    defer grainwrap.free_result(allocator, result);

    if (!result.compliant) {
        for (result.violations) |violation| {
            std.debug.print(
                "Line {d}: {d} chars\n",
                .{ violation.line_number, violation.length },
            );
        }
    }

    // wrap code to 73 characters
    const config = grainwrap.default_config;
    const wrapped = try grainwrap.wrap(allocator, code, config);
    defer allocator.free(wrapped);

    std.debug.print("{s}\n", .{wrapped});
}
```

### as a CLI tool

```bash
# validate a zig file
grainwrap validate src/main.zig

# wrap a zig file
grainwrap wrap src/main.zig --output src/main.wrapped.zig

# check all files in a directory
grainwrap check src/

# format with zig fmt, then wrap
zig fmt src/ && grainwrap wrap src/
```

## constraints

grainwrap enforces grain style constraints:

- **max line length**: 73 characters (hard limit)
- **max function length**: 70 lines (recommended)
- **wrapping**: preserves code readability
- **validation**: reports violations with line numbers

these constraints ensure code fits in graincards while maintaining
readability and clarity.

## integration

grainwrap integrates with the zig workflow:

1. write your code normally
2. run `zig fmt` for standard formatting
3. run `grainwrap wrap` to enforce 73-char limit
4. run `grainwrap validate` to check compliance

this ensures your code follows grain style while maintaining
zig's standard formatting.

## team

**teamprecision06** (Virgo ♍ / VI. The Lovers)

the precision-makers who measure, validate, and enforce boundaries.
virgo's analytical nature meets the lovers' conscious choice. we make
constraints visible, measurable, and beautiful.

## license

multi-licensed: MIT / Apache 2.0 / CC BY 4.0

choose whichever license suits your needs.

