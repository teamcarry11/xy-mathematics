# Getting Started with Grain Aurora — Your Zig IDE

Welcome to Grain Aurora, a native macOS IDE built in Zig for Zig development. If you've used Cursor before, you'll find Aurora familiar yet refreshingly different—think Cursor's AI-powered coding, but with a focus on Zig's static type system, zero-cost abstractions, and TigerStyle safety.

## What is Grain Aurora?

Grain Aurora is a **Zig-first IDE** that combines:
- **Native macOS performance**: Built with Cocoa, no Electron overhead
- **Zig Language Server Protocol (LSP)**: Full semantic understanding of your Zig codebase
- **Agentic coding**: Cursor CLI and Claude Code integration for AI-assisted development
- **Matklad-inspired architecture**: Incremental analysis, cancellation-aware, snapshot-based state management

## How Aurora Compares to Cursor

### Similarities
- **AI-powered coding**: Both use AI agents to help write and refactor code
- **Semantic understanding**: Both understand your codebase deeply
- **Multi-file editing**: Both handle large codebases gracefully
- **Terminal integration**: Both blend editor and terminal workflows

### Key Differences
- **Language focus**: Aurora is Zig-first (though extensible); Cursor is language-agnostic
- **Performance**: Aurora is native macOS (Cocoa), Cursor uses Electron
- **Architecture**: Aurora uses Matklad's snapshot-based LSP model; Cursor uses traditional LSP
- **Static typing emphasis**: Aurora leverages Zig's compile-time guarantees for better completions

## Installation

### Prerequisites
- macOS Tahoe (or later)
- Zig 0.15.2 (install from [ziglang.org](https://ziglang.org))
- Cursor Ultra subscription (for agentic coding features)

### Step 1: Install Zig

```bash
# Download Zig 0.15.2 from ziglang.org
# Extract to /usr/local/zig or ~/zig
# Add to PATH in ~/.zshrc:
export PATH="$HOME/zig:$PATH"
```

### Step 2: Clone Aurora

```bash
git clone https://github.com/kae3g/xy.git
cd xy
zig build tahoe
```

### Step 3: Run Aurora

```bash
./zig-out/bin/tahoe
```

You should see a window with:
- Native macOS chrome (traffic lights, menu bar)
- Dark blue-gray background with white rectangle (Tahoe aesthetic)
- Window title: "Grain Aurora"
- **Note**: Currently displays static content. Interactive features (mouse/keyboard) coming next!

## Your First Zig Project

### Creating a New Project

1. **File → New Project**
   - Choose project name (e.g., `my-zig-app`)
   - Select project template (CLI, library, or GUI)
   - Aurora creates `build.zig`, `src/main.zig`, and project structure

2. **Open Terminal**
   - Press `` ` `` (backtick) to toggle terminal pane
   - Or use **Terminal → New Terminal** from menu

### Writing Your First Function

Type this in `src/main.zig`:

```zig
const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello, Aurora!\n", .{});
}
```

**Notice Aurora's features:**
- **Semantic highlighting**: `const`, `fn`, `!void` are color-coded
- **Inline errors**: Hover over `std` to see available functions
- **Completion**: Type `std.` and press `Ctrl+Space` for autocomplete
- **Go to definition**: `Cmd+Click` on `std` to jump to Zig stdlib

### Building Your Project

1. **Terminal → Run Build**
   - Or press `Cmd+B`
   - Aurora runs `zig build` in the background
   - Errors appear inline with red squiggles

2. **Run Your Program**
   - Press `Cmd+R` or **Run → Run**
   - Output appears in terminal pane

## Agentic Coding with Cursor CLI

Aurora integrates with Cursor CLI for AI-assisted coding, similar to Cursor's Composer mode.

### Starting an Agent Session

1. **AI → New Agent Session**
   - Or press `Cmd+K` (like Cursor)
   - Aurora opens agent chat pane

2. **Ask for Help**
   ```
   Write a function that calculates fibonacci numbers
   ```
   - Aurora uses Cursor CLI to generate Zig code
   - Code appears in a diff view (like Cursor)
   - Accept (`Cmd+Enter`) or reject (`Esc`)

### Differences from Cursor

- **Zig-specific prompts**: Aurora understands Zig idioms
  - "Make this function comptime" → generates comptime-aware code
  - "Add error handling" → uses Zig's error unions
- **TigerStyle compliance**: Generated code follows TigerStyle guidelines
  - 100-column limit
  - Single-level pointers only
  - Explicit assertions

## LSP Features (Matklad-Inspired)

Aurora's LSP uses Matklad's snapshot-based model for fast, cancellation-aware analysis.

### Code Completion

Type `std.mem.` and Aurora shows:
- All available functions
- Function signatures
- Documentation (from Zig source)
- **No delay**: Completion is instant, even in large codebases

### Go to Definition

- `Cmd+Click` on any symbol
- Or `F12` (like VS Code)
- Aurora jumps to definition instantly

### Find All References

- `Shift+F12` (like VS Code)
- Aurora shows all usages in sidebar
- **Incremental**: Results update as you type

### Rename Symbol

- `F2` (like VS Code)
- Aurora renames symbol everywhere
- **Safe**: Only renames in valid scopes

### Inlay Hints

Aurora shows:
- Parameter names at call sites
- Type information for complex expressions
- Comptime values (when known)

## Terminal Integration (Vibe Coding)

Aurora's terminal is inspired by Matklad's "Vibe Coding" philosophy: blur the line between editor and terminal.

### Terminal Features

- **Split panes**: Like tmux, but integrated
- **Command history**: `Cmd+Up` to scroll through history
- **Zig REPL**: Type `zig` to enter Zig REPL mode
- **Build output**: Errors link back to source (click to jump)

### Moonglow Keybindings

Aurora supports Moonglow-style keybindings for power users:

- `Mod+Shift+Enter`: New terminal pane
- `Mod+Shift+Q`: Close pane
- `Mod+Shift+H/J/K/L`: Navigate panes
- `Mod+Shift+Space`: Toggle pane focus

## River Compositor Integration

Aurora includes a River-inspired compositor for window management.

### Window Tiling

- **Split horizontally**: `Mod+H`
- **Split vertically**: `Mod+V`
- **Focus next**: `Mod+J/K` (like River)
- **Move window**: `Mod+Shift+J/K`

### Workspaces

- **Switch workspace**: `Mod+1/2/3/...`
- **Move window to workspace**: `Mod+Shift+1/2/3/...`

## Configuration

### Settings

**Aurora → Preferences** (or `Cmd+,`)

Key settings:
- **Zig path**: Path to Zig executable
- **LSP server**: Use built-in or external ZLS
- **Theme**: Dark/Light/One Dark Pro
- **Font**: Monospace font for code
- **Keybindings**: Customize shortcuts

### Keybindings File

Edit `~/.config/aurora/keybindings.json`:

```json
{
  "editor.completion": "Ctrl+Space",
  "editor.gotoDefinition": "Cmd+Click",
  "terminal.toggle": "`",
  "agent.newSession": "Cmd+K"
}
```

## Troubleshooting

### LSP Not Working

1. Check Zig installation: `zig version`
2. Restart LSP: **Aurora → Restart Language Server**
3. Check logs: **Aurora → View Logs**

### Agent Not Responding

1. Check Cursor CLI: `cursor --version`
2. Check API key: **Aurora → Settings → Cursor API**
3. Check network: Aurora needs internet for agent features

### Window Not Showing

1. Check macOS permissions: **System Settings → Privacy → Screen Recording**
2. Restart Aurora: Quit and reopen
3. Check logs: **Aurora → View Logs**

## Next Steps

- **Read the docs**: `docs/ray.md` for architecture details
- **Join the community**: GitHub Discussions for questions
- **Contribute**: See `CONTRIBUTING.md` for development guide

## Keyboard Shortcuts Reference

### Editor
- `Cmd+B`: Build
- `Cmd+R`: Run
- `Cmd+K`: New agent session
- `Cmd+Click`: Go to definition
- `F12`: Go to definition
- `Shift+F12`: Find all references
- `F2`: Rename symbol
- `Ctrl+Space`: Code completion

### Terminal
- `` ` ``: Toggle terminal
- `Cmd+Shift+Enter`: New terminal pane
- `Cmd+Up`: Command history

### Window Management
- `Mod+H/V`: Split horizontally/vertically
- `Mod+J/K`: Focus next/previous pane
- `Mod+1/2/3`: Switch workspace

## Philosophy: Why Aurora?

Aurora is built on Matklad's insights about language servers:

1. **Start with data model**: Aurora's LSP uses snapshot-based state management
2. **Cancellation-aware**: Long-running analysis can be cancelled when you type
3. **Incremental**: Only re-analyzes what changed
4. **Zig-first**: Leverages Zig's compile-time guarantees for better IDE features

Unlike traditional IDEs, Aurora treats the editor as a **presentation layer** over a **semantic database**. Your code is parsed once, analyzed incrementally, and presented in multiple ways (completion, go-to-def, find-refs).

## Getting Help

- **Documentation**: `docs/` directory
- **GitHub Issues**: Report bugs or request features
- **Discussions**: Ask questions and share ideas

Welcome to Grain Aurora. Happy coding! 🚀

