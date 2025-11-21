# grainorder

**permutation-based chronological file naming**

grainorder generates unique 6-character codes that sort chronologically
when listed alphabetically. newer files get smaller codes, so they appear
at the top in github's A→Z sort.

## quick start

```zig
const grainorder = @import("grainorder");

// create a grainorder
const current = try grainorder.fromString("xsqyl");

// get the next smaller (newer!) grainorder
if (current.prev()) |next| {
    std.debug.print("{}\n", .{next}); // prints: xsqyh
}
```

## the alphabet

`bchlnpqsxyz` (11 consonants, alphabetically ordered)

**mnemonic:** "batch line pick six yeezy"  
(`bch` `ln` `pq` `sx` `yz`)

why these letters?
- removed vowels (avoid forming words)
- removed d, j, k (visual clarity, redundancy)
- removed f, g, m (visual clarity, pattern avoidance)
- removed v (reduced to 11 characters for new mnemonic)
- added p, y (common and distinct)

## how it works

grainorder uses a "place value" algorithm, just like counting backwards:

```
position:  6  5  4  3  2  1  (like place value!)
code:      x  s  q  y  l

start at position 1 ("ones place") and try to decrement.
if we can't, carry left to position 2 ("tens place").
when we decrement, reset positions to the right to largest.
```

**progression** (oldest → newest, read bottom to top):
```
xsqypz  ← position 2 decremented, position 1 reset to largest
xsqyb   ← position 1 exhausted
xsqyc
xsqyh
xsqyl   ← starting point (older code)
```

## building

```bash
# run tests
zig build test

# run demo
zig build run

# build library
zig build
```

## file structure

```
grainorder/
├── src/
│   ├── alphabet.zig      # alphabet utilities
│   ├── core.zig          # prev algorithm
│   ├── validation.zig    # validation logic
│   ├── grainorder.zig    # main module
│   └── demo.zig          # demonstration program
├── test/                 # integration tests
├── docs/                 # documentation
├── build.zig            # build system
└── readme.md            # this file
```

## grain style

this codebase follows grain style principles:
- **explicit limits**: bounded to 332,640 codes
- **zero technical debt**: every line crafted to last
- **code that teaches**: comments explain why, not just what
- **decomplected design**: separate concerns, clear boundaries

## special codes

- `bchlnp` — absolute minimum (overflow point)
- `zyxsqp` — archives (largest possible, always sorts last)

## license

Multi-licensed for maximum freedom:
- mit license (see `license-mit`)
- apache 2.0 (see `license-apache`)
- cc by 4.0 (see `license-cc-by-4.0`)

choose whichever license best suits your needs.

now == next + 1 🌾⚒️
