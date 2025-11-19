# Installation Guide — Grain Aurora

## Zig Toolchain

**Use the official Zig release from ziglang.org, not Homebrew.**

For determinism and TigerStyle compliance, download Zig 0.15.2 directly:

```bash
# macOS (aarch64)
curl -L https://ziglang.org/download/0.15.2/zig-aarch64-macos-0.15.2.tar.xz -o zig.tar.xz
tar -xf zig.tar.xz
sudo mv zig-aarch64-macos-0.15.2 /usr/local/zig-0.15.2
sudo ln -sf /usr/local/zig-0.15.2/zig /usr/local/bin/zig
```

Verify installation:
```bash
zig version  # Should output: 0.15.2
which zig    # Should point to /usr/local/bin/zig
```

**Why official release over Homebrew?**
- Official releases are the canonical source for reproducibility.
- Homebrew bottles may have subtle build differences.
- TigerStyle emphasizes determinism: everyone should use identical binaries.
- Version pinning is more explicit with official releases.

## Other Dependencies

See `Brewfile` for declarative macOS package management:
```bash
brew bundle
```

This installs:
- `git` — version control
- `gh` — GitHub CLI
- `cursor` — Cursor IDE (cask)
- `iterm2` — Terminal emulator (cask)

## Verification

After installation, verify the build works:
```bash
zig build test
zig build tahoe
```

