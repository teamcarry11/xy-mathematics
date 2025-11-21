# graintime

temporal awareness for grain network

## what is graintime?

graintime formats grainbranch names with temporal and astronomical
context. Every branch captures not just clock time, but cosmic
cycles: moon nakshatras, ascendant positions, sun houses.

## format

```
12025-11-02--1515--pdt--moon-shatabhisha--asc-pisc00--sun-09h--kae3g
│     │  │   │ │   │    │    │             │   │    │   │   │   │
│     │  │   │ │   │    │    │             │   │    │   │   │   └─ author
│     │  │   │ │   │    │    │             │   │    │   │   └───── sun house (1-12)
│     │  │   │ │   │    │    │             │   │    │   └───────── h suffix
│     │  │   │ │   │    │    │             │   │    └───────────── asc degrees (0-29)
│     │  │   │ │   │    │    │             │   └────────────────── asc sign (4 chars)
│     │  │   │ │   │    │    │             └────────────────────── asc marker
│     │  │   │ │   │    │    └──────────────────────────────────── nakshatra name
│     │  │   │ │   │    └───────────────────────────────────────── moon marker
│     │  │   │ │   └────────────────────────────────────────────── timezone
│     │  │   │ └────────────────────────────────────────────────── minute
│     │  │   └──────────────────────────────────────────────────── hour
│     │  └──────────────────────────────────────────────────────── day
│     └─────────────────────────────────────────────────────────── month
└───────────────────────────────────────────────────────────────── year (holocene calendar)
```

## architecture

graintime is decomplected into focused modules:

- `types.zig` - data structures and astronomical constants
- `format.zig` - grainbranch name formatting logic
- `graintime.zig` - public API and re-exports

each module has one clear responsibility. this makes the code
easier to understand, test, and extend.

## usage

```zig
const std = @import("std");
const graintime = @import("graintime");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    const branch = graintime.GrainBranch{
        .year = 12025,
        .month = 11,
        .day = 2,
        .hour = 15,
        .minute = 15,
        .timezone = "pdt",
        .moon_nakshatra = "shatabhisha",
        .asc_sign = "pisc",
        .asc_degrees = 0,
        .sun_house = 9,
        .author = "kae3g",
    };
    
    const name = try graintime.format_branch(
        gpa.allocator(),
        branch
    );
    defer gpa.allocator().free(name);
    
    std.debug.print("{s}\n", .{name});
}
```

## astronomical context

### nakshatras

graintime follows mantreshwara's classical vedic tradition from
phaladeepika, where krittika (not ashwini) is the first nakshatra,
aligned with 0° aries.

the 27 nakshatras cycle: krittika → rohini → ... → bharani

each nakshatra is 13°20' of arc. the moon completes the full cycle
in approximately 27.3 days.

note: since mantreshwara's time, precession has shifted the alignment
between nakshatras and tropical zodiac. this is work in progress -
future versions will calculate the current alignment more precisely.

### zodiac signs

signs are abbreviated to 4 characters for consistent formatting:
arie, taur, gemi, canc, leo_, virg, libr, scor, sagi, capr, aqua, pisc

### sun houses

houses 1-12 represent the sun's position in the birth chart,
marking different life areas and temporal qualities.

## current version

this is a simple formatter that takes manually-provided astronomical
data and formats it into grainbranch names.

future versions may add:
- astronomical calculation libraries
- current time + location → automatic nakshatra/house
- graintime parsing (branch name → struct)
- validation and error checking

for now: you provide the data by hand, graintime formats it
beautifully.

## building

```bash
zig build test
```

## team

**teamcarry11** (Leo ♌ / V. The Hierophant)

the illuminators who teach time, wisdom, and tradition. leo's solar
radiance meets the hierophant's patient teaching. we make time
visible, understandable, and beautiful.

## archived steel version

the previous steel (scheme) implementation lives in:
https://github.com/teamcarry11/archive-steel-graintime

## license

Multi-licensed: MIT / Apache 2.0 / CC BY 4.0

choose whichever license suits your needs.

