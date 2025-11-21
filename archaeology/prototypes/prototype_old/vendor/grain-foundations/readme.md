# grain-foundations

foundational types and utilities for grain network

## what is grain-foundations?

grain-foundations provides the core building blocks used across all
grain network tools: workspace structure, developer identity, and
path conventions.

## architecture

grain-foundations is decomplected into focused modules:

- `graindevname.zig` - developer identity normalization
- `grainspace.zig` - workspace structure and operations
- `grain-foundations.zig` - public API and re-exports

each module has one clear responsibility. this makes the code
easier to understand, test, and extend.

## modules

### graindevname

normalizes developer identities from various input formats while
preserving the original identity.

accepts real GitHub usernames (`@jorangreef`, `matklad`) rather
than forcing artificial naming constraints. normalizes to lowercase
without @ prefix for consistent filesystem paths.

### grainspace

defines grain workspace structure and provides operations for
working with grainspaces.

convention: `~/devname/graindevname/`

example: `~/kae3g/grainkae3g/`

the grainstore lives inside: `~/kae3g/grainkae3g/grainstore/`

## usage

```zig
const std = @import("std");
const grain = @import("grain-foundations");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Normalize a developer name
    const devname = try grain.graindevname.normalize(
        allocator,
        "@kae3g"
    );
    defer allocator.free(devname.name);
    
    // Create grainspace from devname
    const space = try grain.grainspace.from_devname(
        allocator,
        devname
    );
    defer allocator.free(space.base_path);
    defer allocator.free(space.grainstore_path);
    
    // Ensure grainstore exists
    try grain.grainspace.ensure_grainstore(space);
}
```

## philosophy

grain network embraces real identities rather than forcing
artificial constraints. we normalize for consistency while
respecting how people identify themselves.

the workspace structure follows simple conventions that make
sense: developer names group their work, grain prefix indicates
grain network affiliation, grainstore contains the manifest.

## building

```bash
zig build test
```

## team

**teamtreasure02** (Taurus ♉ / II. The High Priestess)

the patient builders who create lasting foundations. these types
and utilities underpin all grain network tools, providing the
bedrock for temporal awareness, file organization, and workspace
management.

## used by

- teamcarry11/grainstore-manifest - workspace manifest tool
- teamcarry11/grainmirror - external repository mirroring
- future grain network tools

## license

triple licensed: MIT / Apache 2.0 / CC BY 4.0

choose whichever license suits your needs.

