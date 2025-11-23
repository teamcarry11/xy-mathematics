# grainvalidate-70

complete style validation for grain network

## what is grainvalidate-70?

grainvalidate-70 enforces all Grain Style constraints on zig code. it
checks function length, line width, naming conventions, and other
grain_style rules. every violation is reported with precision.

when you use grainvalidate-70, you're ensuring your code follows
Grain Style standards. 70-line functions, 100-character lines,
explicit error handling. these constraints breed clarity and force
thoughtful design.

the work is hard. we know. writing code that fits within these
boundaries requires discipline. but here's what we've learned:
constraints make us better. they force us to decompose complex
functions, to choose clear names, to structure our code with
intention.

## what does it validate?

grainvalidate-70 checks:

- **function length**: max 70 lines per function
- **line width**: max 100 characters per line (uses grainwrap-100)
- **naming conventions**: snake_case for functions, PascalCase for types
- **explicit error handling**: no generic `anyerror`
- **module organization**: decomplected, focused modules

these constraints ensure code maintains readability while staying
within reasonable bounds. every limit is a choice, and we choose
clarity.

## architecture

grainvalidate-70 is decomplected into focused modules:

- `types.zig` - data structures and configuration
- `function_length.zig` - function length validation
- `style.zig` - naming and error type validation
- `grainvalidate.zig` - public API and re-exports
- `cli.zig` - command line interface

each module has one clear responsibility. this makes the code
easier to understand, test, and extend.

## usage

### as a library

```zig
const std = @import("std");
const grainvalidate = @import("grainvalidate");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const code = @embedFile("src/main.zig");
    const config = grainvalidate.default_config;
    const result = try grainvalidate.validate(allocator, code, config);
    defer grainvalidate.free_result(allocator, result);

    if (!result.compliant) {
        std.debug.print(
            "Found {d} violations:\n",
            .{result.violations.len},
        );
        for (result.violations) |violation| {
            std.debug.print(
                "  {s} at line {d}: {s}\n",
                .{
                    @tagName(violation.violation_type),
                    violation.line,
                    violation.message,
                },
            );
        }
    }
}
```

### as a CLI tool

```bash
# validate a zig file
grainvalidate-70 check src/main.zig

# validate all files in directory
grainvalidate-70 check src/

# check only function length
grainvalidate-70 check --function-length src/main.zig

# check only line width (uses grainwrap-100)
grainvalidate-70 check --line-width src/main.zig
```

## integration

grainvalidate-70 integrates with the zig workflow:

1. write your code normally
2. run `zig fmt` for standard formatting
3. run `grainwrap-100 wrap` to enforce 100-char limit
4. run `grainvalidate-70 check` to validate all style rules

this ensures your code follows Grain Style completely.

## the discipline of constraint

we're not here to make your life harder. we're here to help you
write code that teaches, code that lasts, code that grows.

the 70-line function limit might feel arbitrary at first. it's not.
it's a boundary that forces decomposition. when a function gets
too long, it's trying to do too much. break it down. extract
helpers. clarify intent.

the naming conventions might feel pedantic. they're not. they're
a shared language. when we all speak the same way, we understand
each other faster.

the explicit error handling might feel verbose. it is. and that's
the point. errors are important. they deserve visibility. they
deserve thought.

## team

**teamcarry11**

we build tools that enforce boundaries with grace. we validate
with precision, report with clarity, and guide with understanding.
every constraint is a choice, and we choose teaching.

## license

multi-licensed: MIT / Apache 2.0 / CC BY 4.0

choose whichever license suits your needs.

---

**footnote**: grainvalidate-70's 70-line function limit and explicit
error handling principles draw inspiration from
[Tiger Style](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md),
which emphasizes safety, performance, and developer experience through
strict coding standards. we've adapted these principles for Grain Style's
teaching-first philosophy.

