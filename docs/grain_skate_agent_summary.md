# Grain Skate Agent: Initial Summary and Handoff

**Date**: 2025-01-21  
**From**: Aurora IDE / Dream Browser Agent  
**To**: Grain Skate / Grain Terminal / Grainscript Agent

---

## Summary

This document provides a **summary message** for the new third agent working on **Grain Skate**, **Grain Terminal**, and **Grainscript**. It includes context about the Aurora IDE and Dream Browser work, API contracts, and development guidelines.

---

## Your Mission

You are the **third agent** responsible for:

1. **Grain Terminal**: A Wezterm-level terminal application for Grain OS (RISC-V target)
2. **Grainscript**: A Zig-implemented unified scripting/configuration language to replace Bash/Zsh/Fish and all config/data file formats (`.gr` files)
3. **Grain Skate**: A native macOS knowledge graph application with social threading

**Grainscript Vision**: Unify all configuration and data file formats (JSON, YAML, EDN, Dockerfiles, Terraform, Kubernetes, dotfiles, SSH configs, Git configs, GPG configs, Makefiles, boot scripts, etc.) into a single statically-typed, explicitly-allocated, GrainStyle/TigerStyle-compliant DSL.

**Your work is separate** from the Aurora IDE and Dream Browser, but you may reference and integrate with existing components.

---

## What Has Been Built (Aurora IDE / Dream Browser)

### Completed Components

- **Aurora IDE**: LSP client, Tree-sitter, GLM-4.6, VCS integration, multi-pane layout
- **Dream Browser**: HTML/CSS parser, rendering engine, WebSocket transport, viewport, performance monitoring
- **DAG Core**: Unified DAG foundation for event ordering and consensus
- **GrainBank**: Micropayments and deterministic contracts

### Key Files to Reference

- `src/aurora_*.zig` - Aurora IDE components
- `src/dream_browser_*.zig` - Dream Browser components
- `src/dag_core.zig` - DAG foundation (may be useful for Grain Skate)
- `src/grain_aurora.zig` - UI rendering (may be useful for Grain Terminal)
- `src/aurora_unified_ide.zig` - Unified IDE (reference for integration patterns)

### API Contracts

See `docs/grain_skate_agent_prompt.md` for detailed API contracts. Key points:

- **DAG Core**: `DagCore` struct with `add_node`, `add_edge`, `get_node` methods
- **Grain Aurora**: `GrainAurora` struct for UI rendering
- **Unified IDE**: `UnifiedIde` struct for tab management

**Important**: Do not modify these APIs without coordination. If you need integration, propose extensions.

---

## Development Philosophy

### Non-Negotiable Conditions

1. **GrainStyle/TigerStyle Compliance**:
   - Reference: https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md
   - `grain_case` function names (snake_case)
   - Explicit types (`u32`, `u64`, `i64` instead of `usize`)
   - No recursion (iterative algorithms only)
   - Bounded allocations (all `MAX_` constants)
   - Assertions everywhere
   - All compiler warnings on

2. **Zig 0.15.2**:
   - **MUST use Zig 0.15.2** everywhere
   - Download: https://ziglang.org/download/0.15.2/zig-aarch64-macos-0.15.2.tar.xz
   - Update any older API usage

3. **Iterative Development**:
   - Continue implementing, passing any new tests you write and existing ones
   - Remember to follow grain/tiger style with `grain_case` function names and all the strict rules with all compiler warnings turned on
   - Continue the next phase of implementation and when you're done update the `docs/plan.md` and `docs/tasks.md`
   - Let me know when you need me to check in with the other agents to prevent conflicts

---

## Coordination

### Other Agents

1. **Aurora IDE / Dream Browser Agent** (me):
   - Working on Phase 5.2 (mostly complete)
   - Check in before modifying shared modules

2. **VM/Kernel Agent**:
   - Working on Grain Basin Kernel, RISC-V VM
   - Check in before making kernel-level changes

### When to Check In

- Before modifying shared modules
- Before adding new kernel syscalls
- Before changing API contracts
- When you need information about existing implementations

---

## Next Steps

1. Read `docs/grain_skate_agent_prompt.md` for full details
2. Review existing code in `src/aurora_*.zig` and `src/dream_browser_*.zig`
3. Start with Phase 1 of your chosen project
4. Follow GrainStyle strictly
5. Write tests for every feature
6. Update documentation as you progress

---

## Questions?

- Existing implementations: Review `src/aurora_*.zig` and `src/dream_browser_*.zig`
- API contracts: Check the API documentation in those files
- Coordination: Ask before modifying shared modules
- GrainStyle: Reference TigerStyle guide and existing code

---

**Welcome to the team! Build something amazing.** 🪵⛸️

