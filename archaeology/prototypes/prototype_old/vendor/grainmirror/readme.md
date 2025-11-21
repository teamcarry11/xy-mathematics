# grainmirror

external repository mirroring for grain network

## what is grainmirror?

grainmirror clones and updates external repositories into your
grainstore based on the declarative manifest specification. it
brings external wisdom into your workspace for study and learning.

## philosophy

like the star xvii pouring eternal waters, grainmirror brings
external knowledge into internal pools for study. we mirror
excellent work (tigerbeetle, rust-analyzer) to learn from while
keeping our monorepo clean.

no nested .git folders. no bloated commits. just reproducible
workspace content.

## how it works

1. you declare what to mirror in `grainstore-manifest`
2. grainmirror reads the manifest
3. clones missing repos, pulls updates for existing ones
4. stores them in `grainstore/{platform}/{org}/{repo}`
5. .gitignore keeps them out of your commits

## structure

```
grainstore/
  github/
    tigerbeetle/
      tigerbeetle/    ← cloned from github, not committed
    matklad/
      rust-analyzer/  ← cloned from github, not committed
```

pattern: `grainstore/{platform}/{org}/{repo}`

## architecture

grainmirror is decomplected into focused modules:

- `sync.zig` - repository cloning and updating logic
- `grainmirror.zig` - public API and re-exports
- `cli.zig` - command line interface

each module has one clear responsibility. this makes the code
easier to understand, test, and extend.

## usage

```bash
# Sync all repositories from manifest
grainmirror sync

# Check status of mirrored repositories
grainmirror status

# Sync specific repository
grainmirror sync tigerbeetle/tigerbeetle
```

## integration

grainstore-manifest declares what should exist.
grainmirror reads the manifest and makes it real.

together they provide reproducible workspace content without
committing external code to your repository.

## team

**teamcarry11** (Aquarius ♒ / XVII. The Star)

the wisdom carriers who preserve knowledge and pour it forward.
the star brings external waters (repos) into internal pools
(grainstore) for study and learning.

## dependencies

- teamtreasure02/grain-foundations (graindevname, grainspace)
- teamcarry11/grainstore-manifest (manifest specification)

## license

triple licensed: MIT / Apache 2.0 / CC BY 4.0

choose whichever license suits your needs.

