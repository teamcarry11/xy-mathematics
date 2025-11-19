# grain style

zig development guidelines for the grain network

## what is grain style?

grain style is a philosophy of writing code that teaches. every line should
help the next generation understand not just how something works, but why it
works. we write code that lasts, code that teaches, code that grows
sustainably like grain in a field.

when you follow grain style, you're not just solving a problem - you're
creating a teaching moment. future developers (including yourself) will
read your code and understand the choices you made. they'll learn from your
decisions, not just execute them.

## core principles

### patient discipline

code is written once, read many times. take the time to write it right the
first time. this doesn't mean perfection - it means intention. every
decision should be made consciously, with awareness of the consequences.

when you're about to write a quick hack, pause. ask yourself: "will i
remember why i did this in six months? will someone else understand this?"
if the answer is no, take a moment to write it more clearly.

### explicit limits

zig gives us the power to be explicit. use it. don't hide complexity behind
abstractions - make it visible and understandable.

- use explicit error types, not generic `anyerror`
- set bounds explicitly in your types
- document your assumptions in comments
- make your allocators explicit

when you see a function that takes `[]const u8`, you know exactly what it
expects. when you see `!void`, you know it can fail. this explicitness
makes code easier to understand and maintain.

### sustainable practice

code that works today but breaks tomorrow isn't sustainable. code that
works for one case but breaks for another isn't sustainable. write code
that can grow without breaking.

think about the boundaries of your code:
- what are the valid inputs?
- what are the edge cases?
- what happens when memory is exhausted?
- what happens when the system is under load?

write code that handles these cases gracefully, not code that crashes when
they occur.

### code that teaches

comments should explain why, not what. if you need a comment to explain what
the code does, the code should be clearer. if you need a comment to explain
why you made a choice, that's valuable - write it.

good comments answer questions like:
- "why did we choose this algorithm?"
- "what edge case does this handle?"
- "what assumption does this code rely on?"
- "what would break if we changed this?"

## graincard constraints

graincards are 75×100 monospace teaching cards used throughout the grain
network. all zig code should be written to fit within these constraints.

### dimensions

- **total size**: 75 characters wide × 100 lines tall
- **content area**: 73 characters wide × 98 lines tall (after borders)
- **borders**: 1 character on each side (left, right, top, bottom)

this means:
- **zig code lines**: max 73 characters per line (hard wrap)
- **zig functions**: max 70 lines (leaves 28 lines for title/metadata)
- **borders included**: the 1-char borders are part of the 75×100 total

### why these constraints?

graincards are designed to be:
- **portable**: viewable in any terminal
- **consistent**: all cards same size
- **focused**: forces concise, clear code
- **beautiful**: ASCII art borders create visual structure

when you write zig code for graincards, you're writing for a specific
display format. this constraint breeds creativity - it forces you to
think carefully about every line.

### hard wrapping

zig code should be hard-wrapped to 73 characters per line. this ensures
code fits perfectly in graincard content areas without breaking the
visual structure.

use `zig fmt` but also manually wrap lines that exceed 73 characters.
if a line is too long, break it across multiple lines in a way that
maintains readability.

```zig
// good: fits in 73-char width
const result = try std.fmt.allocPrint(
    allocator,
    "branch: {s}",
    .{branch_name},
);

// also acceptable: if breaking would hurt readability
const short_msg = "this fits";
```

### function size

functions should be max 70 lines. this leaves 28 lines in a graincard
for:
- title and metadata
- function signature documentation
- brief usage examples
- related functions or notes

if a function exceeds 70 lines, consider:
- breaking it into smaller functions
- extracting helper functions
- moving complex logic to separate modules

remember: code that fits in a graincard is easier to understand,
teach, and maintain.

### source code vs graincard display

it's important to understand the distinction:

- **source code files** (`.zig` files): no borders, but still respect
  73-char limit for graincard compatibility. this ensures code can be
  displayed in graincards without modification.

- **graincard display format**: borders are part of the 75×100 total.
  when code is displayed in a graincard, the borders consume 2 characters
  horizontally (left + right) and 2 lines vertically (top + bottom).

this means:
- zig source code files should be hard-wrapped to 73 characters
- the 73-char limit applies even though source files don't have borders
- this ensures code fits perfectly when displayed in graincards later

why this approach? it's better to write code that fits the constraint
from the start, rather than having to reformat it later when you want
to display it in a graincard. the constraint is a feature, not a
limitation - it forces clear, concise code.

## zig-specific guidelines

### memory management

zig gives us explicit control over memory. use it wisely.

#### allocators

always make allocators explicit. pass them as parameters, don't use global
allocators unless absolutely necessary.

```zig
// good: explicit allocator
fn create_buffer(allocator: std.mem.Allocator, size: usize) ![]u8 {
    return try allocator.alloc(u8, size);
}

// bad: implicit global allocator
fn create_buffer(size: usize) ![]u8 {
    return try std.heap.page_allocator.alloc(u8, size);
}
```

when you take an allocator, document its lifetime expectations. does the
caller need to keep it alive? does the function own it? make this clear.

#### error handling

zig's error handling is explicit and powerful. use it.

```zig
// good: explicit error handling
fn parse_number(str: []const u8) !u32 {
    return std.fmt.parseInt(u32, str, 10) catch |err| {
        std.log.err("failed to parse '{s}': {s}", .{ str, @errorName(err) });
        return err;
    };
}

// acceptable: simple error propagation
fn parse_number(str: []const u8) !u32 {
    return std.fmt.parseInt(u32, str, 10);
}
```

don't swallow errors. if something can fail, handle it or propagate it.
silent failures make debugging impossible.

### type safety

zig's type system is powerful. use it to make your code safer.

#### structs over primitives

if you're passing around multiple related values, use a struct. it's
self-documenting and type-safe.

```zig
// good: explicit structure
const Point = struct {
    x: f32,
    y: f32,
};

fn distance(p1: Point, p2: Point) f32 {
    const dx = p1.x - p2.x;
    const dy = p1.y - p2.y;
    return std.math.sqrt(dx * dx + dy * dy);
}

// bad: magic numbers
fn distance(x1: f32, y1: f32, x2: f32, y2: f32) f32 {
    const dx = x1 - x2;
    const dy = y1 - y2;
    return std.math.sqrt(dx * dx + dy * dy);
}
```

#### enums for state

use enums to represent states, not magic numbers or strings.

```zig
// good: explicit state machine
const ConnectionState = enum {
    disconnected,
    connecting,
    connected,
    error,
};

// bad: magic numbers
// 0 = disconnected, 1 = connecting, 2 = connected, 3 = error
```

### decomplection

separate concerns. each module should have one clear responsibility. if you
find yourself saying "this module does X and also Y", consider splitting it.

#### module organization

organize your code into focused modules:

```
src/
├── types.zig          # data structures and constants
├── format.zig         # formatting logic
├── parse.zig          # parsing logic
├── graintime.zig      # public API and re-exports
└── cli.zig            # command line interface
```

each module should be importable on its own. if `format.zig` needs
something from `types.zig`, that's fine. if it needs something from `cli.zig`,
that's a code smell - you might have your dependencies backwards.

#### function size

functions should do one thing. if your function is longer than 50 lines,
ask yourself: "can this be broken down?" usually the answer is yes.

this doesn't mean every function should be tiny - sometimes you need 100
lines to do one thing well. but if you find yourself scrolling through a
function to understand it, it's probably doing too much.

### naming conventions

names should be clear and descriptive. prefer clarity over brevity.

#### variables

use `snake_case` for variables and functions. be descriptive - `user_data`
is better than `ud`, `buffer_size` is better than `bufsz`.

```zig
// good: clear and descriptive
const user_name = "alice";
const buffer_size: usize = 1024;

// acceptable: when context is clear
const name = "alice";
const size: usize = 1024;

// bad: cryptic abbreviations
const un = "alice";
const bufsz: usize = 1024;
```

#### types

use `PascalCase` for types (structs, enums, unions). the name should
describe what the type represents, not how it's implemented.

```zig
// good: describes what it is
const User = struct {
    name: []const u8,
    age: u32,
};

// bad: describes implementation
const UserStruct = struct {
    name: []const u8,
    age: u32,
};
```

#### constants

use `SCREAMING_SNAKE_CASE` for compile-time constants. make them const when
possible, and use `comptime` when the value is known at compile time.

```zig
// good: compile-time constant
const MAX_BUFFER_SIZE: usize = 4096;
const DEFAULT_TIMEOUT_MS: u64 = 5000;

// good: computed at compile time
const MAX_PATH_LEN = comptime std.fs.MAX_PATH_BYTES;
```

### formatting

consistency makes code easier to read. use `zig fmt` to format your code.
it's the standard, and it removes the need for style debates.

```bash
zig fmt src/
```

if you disagree with a formatting decision, that's okay - but use `zig fmt`
anyway. consistency is more valuable than personal preference.

**important**: after running `zig fmt`, use `grainwrap` to enforce
73-character line length. `zig fmt` doesn't enforce line length, so
you need a tool to wrap long lines.

```bash
# format with zig fmt
zig fmt src/

# then wrap to 73 chars with grainwrap
grainwrap wrap src/
```

see `teamprecision06/grainwrap` for the wrapping tool that enforces
grain style line length constraints.

### comments

comments should explain why, not what. if the code needs a comment to
explain what it does, make the code clearer instead.

#### good comments

```zig
// we use a linear search here because the array is small (< 10 elements)
// and sorted. binary search would be overkill and add complexity.
for (items) |item| {
    if (item.id == target_id) return item;
}
```

```zig
// this function can fail if the system is out of memory. we don't
// retry here because the caller should handle retries with backoff.
const buffer = try allocator.alloc(u8, size);
```

#### bad comments

```zig
// loop through items
for (items) |item| {
    // check if id matches
    if (item.id == target_id) {
        // return the item
        return item;
    }
}
```

if you need a comment to explain what the code does, the code should be
clearer. comments should add value, not restate the obvious.

### testing

write tests. they're how you verify your code works, and they're how you
document how your code should be used.

#### test organization

put tests near the code they test. use `test` blocks in the same file, or
create a `test.zig` file in the same directory.

```zig
// src/format.zig
pub fn format_branch(branch: GrainBranch, allocator: std.mem.Allocator) ![]u8 {
    // ... implementation
}

// test in same file
test "format_branch creates valid grainbranch name" {
    // ... test code
}
```

#### test names

test names should describe what they're testing. "test format" is not
helpful. "test format_branch_with_all_fields" is better.

```zig
test "format_branch creates valid grainbranch name" {
    // ...
}

test "format_branch handles missing optional fields" {
    // ...
}

test "format_branch fails on invalid input" {
    // ...
}
```

### error messages

when your code fails, it should tell the user why. error messages should be
actionable and specific.

```zig
// good: specific and actionable
return error.InvalidTemperature;
// user sees: "error: InvalidTemperature"
// they know: temperature was invalid

// better: with context
std.log.err("invalid temperature: {d}K (must be 1700-4700K)", .{temp});
return error.InvalidTemperature;
```

don't use generic errors when you can be specific. `error.InvalidInput` is
less helpful than `error.InvalidTemperature` or `error.InvalidFormat`.

## project structure

### directory layout

organize your project clearly. here's a suggested structure:

```
project/
├── src/
│   ├── types.zig          # data structures
│   ├── api.zig            # public API
│   ├── internal/          # internal modules
│   │   ├── format.zig
│   │   └── parse.zig
│   └── cli.zig            # CLI entry point
├── tests/                 # integration tests
├── build.zig              # build configuration
├── readme.md              # project documentation
└── license                # license information
```

### build.zig

keep your build configuration clear and minimal. document any non-obvious
choices.

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // create the library module
    const lib_mod = b.addModule("project", .{
        .root_source_file = b.path("src/api.zig"),
    });

    // create executable
    const exe = b.addExecutable(.{
        .name = "project",
        .root_source_file = b.path("src/cli.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("project", lib_mod);

    b.installArtifact(exe);
}
```

## common patterns

### initialization

when initializing structs, use `.{}` syntax for clarity:

```zig
const config = Config{
    .enabled = true,
    .temperature = 3000,
    .schedule_automatic = false,
};
```

### optional values

use optionals explicitly. don't use sentinel values when you can use `?T`.

```zig
// good: explicit optional
fn find_user(id: u32) ?User {
    // ...
}

// bad: sentinel value
const INVALID_USER_ID: u32 = 0;
fn find_user(id: u32) User {
    if (id == INVALID_USER_ID) return User{ .id = 0, .name = "" };
    // ...
}
```

### iteration

prefer explicit iteration over magic. when you iterate, make it clear what
you're iterating over.

```zig
// good: explicit iteration
for (users, 0..) |user, index| {
    std.log.info("user {d}: {s}", .{ index, user.name });
}

// good: simple iteration
for (users) |user| {
    process_user(user);
}
```

## when to break the rules

these guidelines are principles, not laws. sometimes you need to break them.
when you do, document why.

```zig
// we use a global allocator here because this function is called
// from C code and we can't pass allocators through the C API.
// this is a known limitation - see issue #123.
const global_allocator = std.heap.page_allocator;
```

if you're breaking a rule, there should be a good reason. if you can't
articulate the reason, you probably shouldn't break the rule.

## learning resources

- [zig language reference](https://ziglang.org/documentation/)
- [zig standard library documentation](https://ziglang.org/documentation/master/std/)
- [zig learn](https://ziglearn.org/) - excellent tutorial resource
- [zig news](https://zig.news/) - community articles

## questions?

if you're unsure about a style choice, ask yourself:

1. **will this be clear in six months?** if you can't answer yes, make it clearer.

2. **does this teach something?** good code teaches. does yours?

3. **is this sustainable?** will this code work when requirements change?

4. **is this explicit?** zig gives us the power to be explicit. are you using it?

if you're still unsure, ask the team. we're here to help each other write
better code.

---

remember: code is written once, read many times. write it for the reader.
write it to teach. write it to last.

now == next + 1 🌾⚒️

