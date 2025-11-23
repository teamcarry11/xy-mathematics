# grainwrap-100

precise code wrapping for grain network

## what is grainwrap-100?

grainwrap-100 enforces 100-character hard wrapping for zig code, ensuring
your code aligns with Grain Style constraints. every line is measured,
validated, and wrapped with precision.

when you use grainwrap-100, you're not just formatting code—you're
aligning it with grain network's visual constraints. 100 characters
per line, 70 lines per function. these limits breed clarity and
force thoughtful design.

the ache of constraint is real. we feel it too. but here's the thing:
boundaries make us better. they force us to choose our words carefully,
to structure our thoughts clearly, to write code that teaches.

## why 100 characters?

Grain Style uses a 100-character limit, which balances readability
with modern display constraints. this constraint:

- ensures code fits comfortably in modern terminals and editors
- forces concise, clear code without being overly restrictive
- creates visual consistency across the grain network
- makes code easier to read and understand
- allows for meaningful variable names and clear expressions

we acknowledge the tension here. 73 characters fit graincards perfectly,
but 100 characters give us breathing room for the kind of code that
teaches. we've chosen the path that serves both purposes: clarity
and teaching.

## architecture

grainwrap-100 is decomplected into focused modules:

- `types.zig` - data structures and configuration
- `wrap.zig` - line wrapping logic
- `validate.zig` - line length validation
- `grainwrap.zig` - public API and re-exports
- `cli.zig` - command line interface

each module has one clear responsibility. this makes the code
easier to understand, test, and extend.

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
    const code = "const very_long_line_that_exceeds_one_hundred_characters_and_needs_wrapping = true;";
    const result = try grainwrap.validate(allocator, code, 100);
    defer grainwrap.free_result(allocator, result);

    if (!result.compliant) {
        for (result.violations) |violation| {
            std.debug.print(
                "Line {d}: {d} chars\n",
                .{ violation.line_number, violation.length },
            );
        }
    }

    // wrap code to 100 characters
    const config = grainwrap.default_config;
    const wrapped = try grainwrap.wrap(allocator, code, config);
    defer allocator.free(wrapped);

    std.debug.print("{s}\n", .{wrapped});
}
```

### as a CLI tool

```bash
# validate a zig file
grainwrap-100 validate src/main.zig

# wrap a zig file
grainwrap-100 wrap src/main.zig --output src/main.wrapped.zig

# check all files in a directory
grainwrap-100 check src/

# format with zig fmt, then wrap
zig fmt src/ && grainwrap-100 wrap src/
```

## constraints

grainwrap-100 enforces Grain Style constraints:

- **max line length**: 100 characters (hard limit)
- **max function length**: 70 lines (recommended)
- **wrapping**: preserves code readability
- **validation**: reports violations with line numbers

these constraints ensure code maintains readability while staying
within reasonable bounds. we've chosen 100 characters as a balance
between the strict 73-character graincard limit and the practical
needs of modern code.

## integration

grainwrap-100 integrates with the zig workflow:

1. write your code normally
2. run `zig fmt` for standard formatting
3. run `grainwrap-100 wrap` to enforce 100-char limit
4. run `grainwrap-100 validate` to check compliance

this ensures your code follows Grain Style while maintaining
zig's standard formatting.

## the path forward

we're building tools that help us write better code. not perfect
code—better code. code that teaches, code that lasts, code that
grows sustainably.

the constraints might feel tight at first. that's okay. lean into
them. let them guide your design. you'll find that the boundaries
you thought were limitations are actually liberations.

## team

**teamcarry11**

we build tools that enforce boundaries with grace. we measure with
precision, validate with care, and wrap with understanding. every
constraint is a choice, and we choose clarity.

## license

multi-licensed: MIT / Apache 2.0 / CC BY 4.0

choose whichever license suits your needs.

---

**footnote**: grainwrap-100's 100-character limit draws inspiration from
[Tiger Style](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md),
which enforces a 100-column limit for safety, performance, and developer
experience. we've adapted this constraint for Grain Style's teaching-first
philosophy.

