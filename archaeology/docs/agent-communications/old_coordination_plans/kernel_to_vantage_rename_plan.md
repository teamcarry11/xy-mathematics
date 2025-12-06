# Kernel → Vantage Agent Rename Plan

**Date**: 2025-12-05-150909-pst  
**Status**: Planning Document  
**Priority**: HIGH — Agent name standardization

---

## Executive Summary

We are renaming the **"Grain Vantage VM Basin Kernel Agent"** to simply **"Grain Vantage Agent"** to better reflect that the agent is responsible for both the Basin Kernel and the Vantage VM, with Vantage VM being the critical final link that makes everything work on macOS 26.1 Tahoe.

**Rationale**:
- Vantage VM is as important or more important than the kernel itself
- Vantage VM is the final link in the chain that makes everything work
- Targeting macOS 26.1 Tahoe makes Vantage VM critical
- Simplifies agent name while maintaining clarity

**Key Principle**: 
- Keep "kernel" as a general noun (e.g., "kernel syscalls", "kernel code")
- Rename agent-specific references (e.g., "Kernel Agent" → "Vantage Agent")
- Rename file/module names with `_kernel` to `_vantage` when agent-specific

---

## What's Changing

### Agent Name
- **Old**: "Grain Vantage VM Basin Kernel Agent" or "Kernel Agent"
- **New**: "Grain Vantage Agent" or "Vantage Agent"

### File Names
- **Old**: `docs/plans/plan_kernel.md`
- **New**: `docs/plans/plan_vantage.md`

- **Old**: `docs/tasks/tasks_kernel.md`
- **New**: `docs/tasks/tasks_vantage.md`

### Code/Module References
- **Agent-specific module names**: `_kernel` → `_vantage` (when referring to agent)
- **General kernel code**: Keep as-is (e.g., `src/kernel/basin_kernel.zig` stays)

### Documentation References
- **"Kernel Agent"** → **"Vantage Agent"**
- **"Grain Vantage VM Basin Kernel Agent"** → **"Grain Vantage Agent"**
- **Agent-specific mentions** → Update to "Vantage Agent"

---

## What's NOT Changing

### Keep As-Is (General Nouns)
- `src/kernel/` directory (kernel code, not agent-specific)
- `basin_kernel.zig` (kernel implementation file)
- "kernel syscalls" (general term)
- "kernel code" (general term)
- "kernel module" (when referring to actual kernel code)
- Test files like `*_kernel_*.zig` (when testing kernel functionality)

### Build System
- `build/kernel.zig` (build configuration for kernel, not agent-specific)
- Kernel build targets (keep as-is)

---

## Rename Procedure

### Phase 1: Documentation Files (Agent-Specific)

**Files to Rename**:
1. `docs/plans/plan_kernel.md` → `docs/plans/plan_vantage.md`
2. `docs/tasks/tasks_kernel.md` → `docs/tasks/tasks_vantage.md`

**Files to Update (Content)**:
1. `docs/plan.md` — Update agent name references
2. `docs/tasks.md` — Update agent name references
3. All agent plan files (`docs/plans/plan_*.md`) — Update references to "Kernel Agent"
4. All agent task files (`docs/tasks/tasks_*.md`) — Update references to "Kernel Agent"
5. Agent prompt files (`docs/*_agent_*_prompt.md`) — Update references
6. Coordination documents (`docs/agent-communications/*.md`) — Update references

### Phase 2: Code References (Agent-Specific Only)

**Search Pattern**: Look for agent-specific references, not general "kernel" usage

**Files to Check**:
- `build.zig` — Agent references
- `build/modules.zig` — Agent module references
- `build/agents.zig` — Agent configuration
- `src/grain_core/*.zig` — Agent coordination references
- Test files — Agent-specific test names

**What to Change**:
- Function names like `kernel_agent_*` → `vantage_agent_*` (if they exist)
- Variable names like `kernel_agent` → `vantage_agent` (if they exist)
- Comments mentioning "Kernel Agent" → "Vantage Agent"

**What NOT to Change**:
- `src/kernel/` directory structure
- `basin_kernel.zig` and other kernel implementation files
- Kernel syscall names
- Kernel test file names (unless they're agent-specific)

### Phase 3: Master Documentation

**Files to Update**:
1. `docs/plan.md` — Update agent name and references
2. `docs/tasks.md` — Update agent name and references
3. `docs/README.md` (if exists) — Update agent list

### Phase 4: Coordination Documents

**Files to Update**:
- All files in `docs/agent-communications/` that mention "Kernel Agent"
- Agent prompt files that reference the kernel agent

---

## Detailed File List

### Files to Rename

1. `docs/plans/plan_kernel.md` → `docs/plans/plan_vantage.md`
2. `docs/tasks/tasks_kernel.md` → `docs/tasks/tasks_vantage.md`

### Files to Update (Content Search & Replace)

**Master Documentation**:
- `docs/plan.md`
- `docs/tasks.md`

**Agent Plans** (update references):
- `docs/plans/plan_core.md`
- `docs/plans/plan_aurora.md`
- `docs/plans/plan_skate.md`
- `docs/plans/plan_mobile.md`
- `docs/plans/plan_database.md`
- `docs/plans/plan_workspace.md`
- `docs/plans/plan_bubble.md` (if exists)

**Agent Tasks** (update references):
- `docs/tasks/tasks_core.md`
- `docs/tasks/tasks_aurora.md`
- `docs/tasks/tasks_skate.md`
- `docs/tasks/tasks_mobile.md`
- `docs/tasks/tasks_database.md`
- `docs/tasks/tasks_workspace.md`
- `docs/tasks/tasks_bubble.md` (if exists)

**Build System**:
- `build.zig` — Agent references
- `build/modules.zig` — Agent module references
- `build/agents.zig` — Agent configuration
- `build/kernel.zig` — Only if it has agent-specific references

**Code Files** (agent-specific references only):
- `src/grain_core/compositor.zig` — Agent coordination
- `src/grain_core/*.zig` — Any agent references

**Coordination Documents**:
- `docs/agent-communications/*.md`
- `docs/*_agent_*_prompt.md`
- `docs/kernel_agent_*.md` → Consider renaming to `vantage_agent_*.md`

### Files to Keep As-Is (General Kernel Code)

- `src/kernel/` directory (entire directory)
- `src/kernel/basin_kernel.zig`
- `src/kernel/*.zig` (all kernel implementation files)
- `src/kernel_vm/` directory (VM code)
- `build/kernel.zig` (build config, unless it has agent-specific names)
- Test files testing kernel functionality (e.g., `*_kernel_*.zig`)

---

## Search & Replace Patterns

### Pattern 1: Agent Name in Documentation

**Find**:
- `Grain Vantage VM Basin Kernel Agent`
- `Kernel Agent`
- `kernel agent` (lowercase)
- `Grain Vantage VM Basin Kernel` (when referring to agent)

**Replace**:
- `Grain Vantage Agent`
- `Vantage Agent`
- `vantage agent` (lowercase)
- `Grain Vantage Agent` (when referring to agent)

### Pattern 2: File References

**Find**:
- `plan_kernel.md`
- `tasks_kernel.md`
- `docs/plans/plan_kernel.md`
- `docs/tasks/tasks_kernel.md`

**Replace**:
- `plan_vantage.md`
- `tasks_vantage.md`
- `docs/plans/plan_vantage.md`
- `docs/tasks/tasks_vantage.md`

### Pattern 3: Agent-Specific Code References

**Find** (only if agent-specific):
- `kernel_agent` (variable/function names)
- `KernelAgent` (type names)
- `kernelAgent` (camelCase)

**Replace**:
- `vantage_agent`
- `VantageAgent`
- `vantageAgent`

### Pattern 4: Documentation Section Headers

**Find**:
- `### 1. Grain Vantage VM Basin Kernel Agent`
- `## Grain Vantage VM Basin Kernel Agent`
- `**Agent**: Grain Vantage VM Basin Kernel Agent`

**Replace**:
- `### 1. Grain Vantage Agent`
- `## Grain Vantage Agent`
- `**Agent**: Grain Vantage Agent`

---

## Execution Order

### Step 1: Rename Documentation Files
1. Rename `docs/plans/plan_kernel.md` → `docs/plans/plan_vantage.md`
2. Rename `docs/tasks/tasks_kernel.md` → `docs/tasks/tasks_vantage.md`
3. Update content in renamed files (agent name references)

### Step 2: Update Master Documentation
1. Update `docs/plan.md` — Search and replace agent name
2. Update `docs/tasks.md` — Search and replace agent name

### Step 3: Update All Agent Documentation
1. Update all `docs/plans/plan_*.md` files (except the renamed one)
2. Update all `docs/tasks/tasks_*.md` files (except the renamed one)

### Step 4: Update Build System
1. Update `build.zig` — Agent references
2. Update `build/modules.zig` — Agent module references
3. Update `build/agents.zig` — Agent configuration

### Step 5: Update Code Files (Agent-Specific Only)
1. Search `src/grain_core/` for agent-specific references
2. Update any agent coordination code

### Step 6: Update Coordination Documents
1. Update `docs/agent-communications/*.md`
2. Consider renaming `docs/kernel_agent_*.md` → `docs/vantage_agent_*.md`

### Step 7: Verify
1. Run `grep -r "Kernel Agent" docs/` to find any remaining references
2. Run `grep -r "plan_kernel" docs/` to find any remaining file references
3. Run `grep -r "tasks_kernel" docs/` to find any remaining file references
4. Verify tests still pass
5. Verify build still works

---

## Verification Checklist

After completing the rename:

- [ ] `docs/plans/plan_vantage.md` exists (renamed from `plan_kernel.md`)
- [ ] `docs/tasks/tasks_vantage.md` exists (renamed from `tasks_kernel.md`)
- [ ] No references to `plan_kernel.md` in documentation
- [ ] No references to `tasks_kernel.md` in documentation
- [ ] All "Kernel Agent" references updated to "Vantage Agent"
- [ ] All "Grain Vantage VM Basin Kernel Agent" references updated to "Grain Vantage Agent"
- [ ] `docs/plan.md` updated
- [ ] `docs/tasks.md` updated
- [ ] All agent plan files updated
- [ ] All agent task files updated
- [ ] Build system updated (if needed)
- [ ] Code files updated (agent-specific only)
- [ ] Coordination documents updated
- [ ] Tests pass
- [ ] Build works

---

## Notes

1. **Git History**: We're not preserving file history in the active repo. Git history will preserve the rename.

2. **General "kernel" Usage**: Keep all general references to "kernel" as-is. Only change agent-specific references.

3. **Kernel Code**: The actual kernel code (`src/kernel/`) remains unchanged. This rename is only about the agent name and documentation.

4. **VM Code**: The VM code (`src/kernel_vm/`) remains unchanged. This is about the agent, not the code.

5. **Test Files**: Test files that test kernel functionality keep their names. Only agent-specific test names change.

---

## Coordination Message Template

After completion, send this to all agents:

```
We have completed the rename of "Kernel Agent" to "Vantage Agent". 

Key changes:
- Agent name: "Grain Vantage VM Basin Kernel Agent" → "Grain Vantage Agent"
- Documentation files: plan_kernel.md → plan_vantage.md, tasks_kernel.md → tasks_vantage.md
- All documentation references updated

Note: General "kernel" references remain unchanged (e.g., "kernel syscalls", "kernel code"). Only agent-specific references were updated.

Please update any references in your documentation if you mention the "Kernel Agent" or "Grain Vantage VM Basin Kernel Agent".
```

---

**End of Plan**

**Ready for Execution**: Yes  
**Estimated Time**: 1-2 hours  
**Risk Level**: Low (documentation-only changes, no code logic changes)

