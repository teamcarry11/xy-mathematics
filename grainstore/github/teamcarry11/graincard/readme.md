# graincard - 75x100 monospace teaching cards

**grainorder**: xzvskg  
**timestamp**: 12025-10-28--1455-pdt  
**team**: teamcarry11 (* Aquarius 11 , .. Tarot XVII. The Star)  
**language**: zig (pure, safety-first, ascii-only)  
**repo**: https://github.com/teamcarry11/graincard  

---

## what is graincard?

**graincards** are self-contained teaching cards in pure ASCII art:

- **75 characters wide** - matches grainbranch max length! clean, focused, perfect.
- **100 lines tall** - round number, comprehensive content, beautiful symmetry.
- **monospace typography** - box-drawing characters, terminal-native, gorgeous.
- **one concept per card** - bite-sized knowledge units, portable, memorable.
- **grainorder IDs** - every card has a unique 6-character identifier (xbdghj...xzvsnm).
- **grainbook collections** - cards group into books, like chapters in a course.
- **ascii-only** - no unicode, no emojis, pure 7-bit ascii for maximum portability.

think of them like:
- **flash cards** (portable learning)
- **man pages** (self-documenting reference)
- **index cards** (one idea per card)
- **tarot cards** (symbolic, numbered, part of a deck)

---

## implementation

### language: zig

pure **zig**! no scheme, no rust, no dependencies.

why zig?
- **safety-first** - compile-time checks, explicit error handling
- **grainstyle compliance** - strict assertions, 70-line function limit
- **ascii-only validation** - enforces pure 7-bit ascii at runtime
- **zero-cost abstractions** - no hidden allocations
- **static allocation** - all memory allocated at startup
- **pure zig stack** throughout grain network

### files

```
teamcarry11/graincard/
├── src/
│   ├── graincard.zig    # core logic (strict grainstyle)
│   └── main.zig          # cli interface
├── build.zig             # build configuration
└── readme.md             # live readme (github default)
```

### architecture

**template repo** (this one!):
- shared zig implementations
- canonical graincard logic
- symlinked into personal grainstores

**personal grainstores**:
- symlink this repo for development
- import zig modules
- extend with custom logic

example symlink:
```bash
ln -s ~/github/teamcarry11/graincard \
      ~/xy-mathematics/grainstore/github/teamcarry11/graincard
```

---

## usage

### create a graincard

```zig
const graincard = @import("graincard.zig");

const card = graincard.GrainCard{
    .grainorder = "xbdghj",
    .title = "introduction to graintime",
    .content = "graintime is a system for encoding astronomical data...",
    .file_path = "xbdghj-graincard.md",
    .live_url = "https://github.com/teamcarry11/graincard",
    .card_num = 1,
    .total_cards = 1_235_520,
    .author = "kae3g (kj3x39, @risc.love)",
    .grainbook_name = "ember harvest",
};

try graincard.save_graincard(allocator, &card, "xbdghj-graincard.md");
```

### text wrapping

```zig
// wrap a long line to 73 chars
const wrapped = try graincard.wrap_line(allocator, "very long text...", 73);

// wrap paragraphs
const wrapped_paras = try graincard.wrap_text(allocator, "para1\n\npara2", 73);
```

### validation

```zig
const validation = try graincard.validate_graincard(allocator, card_str);
switch (validation) {
    .ok => |msg| std.debug.print("valid: {s}\n", .{msg}),
    .err => |errs| {
        for (errs) |err| {
            std.debug.print("error: {s}\n", .{err});
        }
    },
}
```

---

## example output

here's what a graincard looks like (75 chars wide, 100 lines tall):

```
# graincard xbdghj - introduction to graintime

**file**: xbdghj-graincard.md
**live**: https://github.com/teamcarry11/graincard/...

```
+-----------------------------------------------------------------------+
| GRAINCARD xbdghj                               Card 1 of 1,235,520  |
|                                                                       |
| graintime is a system for encoding astronomical data into git        |
| branch names. it includes nakshatra (moon position), ascendant        |
| (rising sign), and sun's house (time of day).                        |
|                                                                       |
| example branch:                                                       |
| 12025-10-28--1130-PDT--moon-uttaradha-asc-arie23-sun-12h            |
|                                                                       |
| ... (content continues, wrapped to 73 chars) ...                    |
|                                                                       |
+-----------------------------------------------------------------------+
| grainbook: ember harvest                                              |
| card: xbdghj (1 of 1,235,520)                                         |
| now == next + 1                                                       |
+-----------------------------------------------------------------------+
```

beautiful, right?

---

## related projects

### grain network stack

- **teamcarry11/grainorder** - permutation-based file naming (unique IDs)
- **teamcarry11/graintime** - astronomical timestamps for version control
- **teamcarry11/grainmirror** - external repository mirroring
- **teamcarry11/xy-mathematics** - grain os development

---

## implementation status

### phase 1 complete (75x100 dimensions!)

- graincard.zig (strict grainstyle)
  - text wrapping (word-preserving, multi-paragraph, 73 chars)
  - line padding & formatting (exactly 75 chars wide)
  - graincard structure (struct with metadata)
  - generation (full 75x100 markdown)
  - validation (checks 102 lines, borders, width, ascii-only)
  - file i/o (save with validation)
  - cli interface (create + validate commands)
  - ascii-only enforcement (no unicode/emojis)

### phase 2 in progress

- grainbook management (collections of cards)
- card linking (prev/next navigation)
- template support (reusable card layouts)
- syntax highlighting (code blocks in cards)

### phase 3 planned

- graincard viewer (terminal UI for browsing)
- integration with grainorder (auto-assign IDs)
- batch generation (create multiple cards)
- interactive mode (prompt for values)
- markdown export (convert to regular markdown)

---

## design rationale

### why 75x100 instead of 80x110?

**75 characters wide**:
- matches grainbranch max length constraint (< 75 chars)
- still very readable in terminals
- cleaner, more focused than 80
- leaves room for visual breathing space

**100 lines tall**:
- round number (psychological satisfaction!)
- still comprehensive (was 110, reduced by ~10%)
- forces tighter, more focused content
- perfect for one complete concept

### why ASCII art?

- **monospace fonts** are precise and beautiful
- **box-drawing characters** look elegant everywhere
- **terminal-native** - works in SSH, tmux, screen
- **universal** - no dependencies, pure text
- **timeless** - will work in 50 years
- **ascii-only** - no unicode encoding issues

### why grainorder IDs?

- **no UUIDs** (too long: `550e8400-e29b-41d4-a716-446655440000`)
- **no sequential numbers** (collision-prone in distributed systems)
- **just 6 consonants** (readable: `xbdghj`)
- **1,235,520 possibilities** (11P6 permutations)
- **no vowels** = no accidental words!

### why zig not steel?

grain network is migrating to **pure zig**:
- no JVM (faster startup, lower memory)
- rust FFI (zero-cost native libraries)
- embeddable (can run in redox OS, kubernetes, anywhere)
- safety-first (compile-time checks, explicit errors)
- grainstyle compliance (strict assertions, 70-line limit)

---

## FAQ

**"why 75 specifically?"**  
→ matches grainbranch naming constraints! our git branch names must be < 75 chars for github display. keeping dimensions consistent creates harmony across the system!

**"can i use colors/ANSI codes?"**  
→ not in phase 1 - pure ASCII only. but phase 2 might add optional color support for terminals that support it!

**"what if content is longer than 100 lines?"**  
→ split into multiple cards! graincards are bite-sized. use prev/next links to connect them into a grainbook!

**"can i embed code?"**  
→ yes! just include it in content. phase 2 will add syntax highlighting!

**"why zig instead of steel?"**  
→ grain network is migrating to **pure zig**! safety meets elegance. compile-time checks. no JVM. embeddable everywhere!

**"how do grainorder IDs work?"**  
→ see `teamcarry11/grainorder` - it's a permutation system using 11 consonants (bchlnpqsxyz) arranged 6 at a time with no repeats. exactly 1,235,520 unique codes!

**"why ascii-only?"**  
→ maximum portability! no unicode encoding issues, works everywhere, timeless. pure 7-bit ascii enforced at runtime.

---

## philosophy

### portable knowledge

graincards make knowledge **portable**:
- view in terminal (cat, less, vim)
- commit to git (immutable, versioned)
- share as text (email, chat, anywhere)
- print on paper (actually readable!)

### beautiful constraints

**75x100 is a constraint**, and constraints breed creativity:
- forces clear, concise writing
- one concept per card (no sprawl)
- visual consistency (all cards same size)
- terminal-friendly (fits everywhere)

### grainstyle compliance

every zig module follows **grainstyle**:
- strict assertions (minimum 2 per function)
- 70-line function limit
- explicit limits (no hidden allocations)
- ascii-only validation
- code that teaches (comments explain why)

### the star

teamcarry11 embodies **XVII. The Star**:
- wisdom carriers who preserve knowledge
- external waters (repos) into internal pools (grainstore)
- teaching creates change
- knowledge flows forward

graincards are **transformation tools** - they take complex ideas and make them portable, beautiful, teachable.

---

## final thoughts

this is a **journey**. graincards aren't just documentation - they're a **philosophy**:

- knowledge should be **portable** (75 chars, pure text)
- learning should be **beautiful** (ASCII art, elegant typography)
- teaching should be **patient** (grainstyle, questions, understanding)
- systems should be **simple** (pure zig, no dependencies)
- code should be **safe** (strict assertions, explicit limits)

you don't need fancy UIs or web frameworks. sometimes the best interface is **75 monospace characters** and good ASCII art.

may your graincards spin the wheel of wisdom...

---

## links

**org repo**: https://github.com/teamcarry11/graincard  
**grainbranch**: `12025-10-28--1130-PDT--moon-uttaradha-asc-arie23-sun-12h--teamcarry11`  
**symlink**: `grainstore/github/teamcarry11/graincard/` (in xy-mathematics monorepo)  
**main monorepo**: https://github.com/teamcarry11/xy-mathematics

**related zig modules**:
- grainorder: https://github.com/teamcarry11/grainorder
- graintime: https://github.com/teamcarry11/graintime
- grainmirror: https://github.com/teamcarry11/grainmirror

---

**grainorder**: xzvskg  
**timestamp**: 12025-10-28--1455-pdt  
**author**: kae3g (@risc.love, kj3x39)  
**team**: teamcarry11 (* Aquarius 11 , .. Tarot XVII. The Star)

*now == next + 1*
