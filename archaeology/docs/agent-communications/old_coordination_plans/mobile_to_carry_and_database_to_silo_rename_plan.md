# Mobile → Carry & Database → Silo: Unified Rename Plan

**Date**: 2025-12-05-153506-pst  
**Status**: Planning Document  
**Priority**: HIGH — Agent name standardization

---

## Executive Summary

We are performing two coordinated renames:

1. **"Grain Mobile Agent"** → **"Grain Carry Agent"**
   - Better represents cross-platform portability (not just mobile)
   - Emphasizes "carrying" shared logic across platforms

2. **"Grain Database Agent"** → **"Grain Silo Agent"**
   - Aligns with existing "Grain Silo" module name
   - Clarifies that Database Agent builds on Grain Silo foundation

**Rationale**:
- **Grain Carry**: Emphasizes cross-platform portability and shared code "carrying" across iOS/Android
- **Grain Silo**: Database Agent already uses Grain Silo as foundation, so naming should align

---

## What's Changing

### Grain Mobile → Grain Carry

**Agent Name**:
- **Old**: "Grain Mobile Agent" or "Mobile Agent"
- **New**: "Grain Carry Agent" or "Carry Agent"

**File Names**:
- **Old**: `docs/plans/plan_mobile.md`
- **New**: `docs/plans/plan_carry.md`

- **Old**: `docs/tasks/tasks_mobile.md`
- **New**: `docs/tasks/tasks_carry.md`

**Code/Module References**:
- **Module**: `src/grain_mobile_core/` → `src/grain_carry_core/`
- **Agent-specific references**: `mobile_agent` → `carry_agent`, `Mobile Agent` → `Carry Agent`

**Documentation References**:
- **"Mobile Agent"** → **"Carry Agent"**
- **"Grain Mobile Agent"** → **"Grain Carry Agent"**
- **"Grain Mobile Core"** → **"Grain Carry Core"**

### Grain Database → Grain Silo

**Agent Name**:
- **Old**: "Grain Database Agent" or "Database Agent"
- **New**: "Grain Silo Agent" or "Silo Agent"

**File Names**:
- **Old**: `docs/plans/plan_database.md`
- **New**: `docs/plans/plan_silo.md`

- **Old**: `docs/tasks/tasks_database.md`
- **New**: `docs/tasks/tasks_silo.md`

**Code/Module References**:
- **Module**: `src/grain_database/` → `src/grain_silo/` (NOTE: This conflicts with existing `grain_silo` storage module!)
- **Wait**: Need to clarify - there's already `src/grain_silo/` for object storage
- **Solution**: Keep module as `grain_database/` but rename agent to "Silo Agent"
- **Agent-specific references**: `database_agent` → `silo_agent`, `Database Agent` → `Silo Agent`

**Documentation References**:
- **"Database Agent"** → **"Silo Agent"**
- **"Grain Database Agent"** → **"Grain Silo Agent"**
- **Keep**: "Grain Database" module name (to avoid conflict with `grain_silo` storage)

---

## Important Note: Module Name Conflict

**Issue**: There's already a `src/grain_silo/` module for object storage (Skate Agent).

**Solution**:
- **Agent name**: "Grain Silo Agent" (renamed)
- **Module name**: Keep as `src/grain_database/` (to avoid conflict)
- **Documentation**: Use "Silo Agent" but clarify it builds "Grain Database" on top of "Grain Silo" storage

**Clarification**:
- **Grain Silo** (storage module): Object storage, S3-compatible (Skate Agent)
- **Grain Database** (database module): General-purpose database built on Grain Silo (Silo Agent)
- **Silo Agent**: The agent that builds Grain Database (uses Grain Silo as foundation)

---

## Rename Procedure

### Phase 1: Documentation Files (Both Agents)

**Grain Mobile → Grain Carry**:
1. Rename `docs/plans/plan_mobile.md` → `docs/plans/plan_carry.md`
2. Rename `docs/tasks/tasks_mobile.md` → `docs/tasks/tasks_carry.md`
3. Update content in renamed files (agent name references)

**Grain Database → Grain Silo**:
1. Rename `docs/plans/plan_database.md` → `docs/plans/plan_silo.md`
2. Rename `docs/tasks/tasks_database.md` → `docs/tasks/tasks_silo.md`
3. Update content in renamed files (agent name references)

### Phase 2: Master Documentation

**Files to Update**:
1. `docs/plan.md` — Update both agent names and file references
2. `docs/tasks.md` — Update both agent names and file references

### Phase 3: All Agent Documentation

**Files to Update**:
- All agent plan files (`docs/plans/plan_*.md`) — Update references
- All agent task files (`docs/tasks/tasks_*.md`) — Update references
- Agent prompt files (`docs/*_agent_*_prompt.md`) — Update references
- Coordination documents (`docs/agent-communications/*.md`) — Update references

### Phase 4: Code References (Grain Mobile → Grain Carry Only)

**Module Rename** (Grain Mobile → Grain Carry):
- `src/grain_mobile_core/` → `src/grain_carry_core/`
- Update all imports: `@import("grain_mobile_core")` → `@import("grain_carry_core")`
- Update build system references
- Update test file references

**Note**: Grain Database module stays as `grain_database/` to avoid conflict with `grain_silo/` storage.

### Phase 5: Build System

**Files to Update**:
- `build.zig` — Agent references and module paths
- `build/modules.zig` — Module references
- `build/agents.zig` — Agent configuration

---

## Detailed File Lists

### Files to Rename

**Grain Mobile → Grain Carry**:
1. `docs/plans/plan_mobile.md` → `docs/plans/plan_carry.md`
2. `docs/tasks/tasks_mobile.md` → `docs/tasks/tasks_carry.md`
3. `src/grain_mobile_core/` → `src/grain_carry_core/` (entire directory)

**Grain Database → Grain Silo**:
1. `docs/plans/plan_database.md` → `docs/plans/plan_silo.md`
2. `docs/tasks/tasks_database.md` → `docs/tasks/tasks_silo.md`
3. **Keep**: `src/grain_database/` (module name unchanged to avoid conflict)

### Files to Update (Content Search & Replace)

**Master Documentation**:
- `docs/plan.md`
- `docs/tasks.md`

**Agent Plans** (update references):
- `docs/plans/plan_core.md`
- `docs/plans/plan_aurora.md`
- `docs/plans/plan_skate.md`
- `docs/plans/plan_vantage.md`
- `docs/plans/plan_workspace.md`
- `docs/plans/plan_bubble.md` (if exists)

**Agent Tasks** (update references):
- `docs/tasks/tasks_core.md`
- `docs/tasks/tasks_aurora.md`
- `docs/tasks/tasks_skate.md`
- `docs/tasks/tasks_vantage.md`
- `docs/tasks/tasks_workspace.md`
- `docs/tasks/tasks_bubble.md` (if exists)

**Build System**:
- `build.zig` — Agent references, module paths
- `build/modules.zig` — Module references
- `build/agents.zig` — Agent configuration

**Code Files** (Grain Mobile → Grain Carry only):
- All files importing `grain_mobile_core`
- Test files referencing `grain_mobile_core`
- Build configurations

**Coordination Documents**:
- `docs/agent-communications/*.md`
- `docs/*_mobile_*.md` → Consider renaming to `*_carry_*.md`
- `docs/*_database_*.md` → Consider renaming to `*_silo_*.md`

---

## Search & Replace Patterns

### Pattern 1: Grain Mobile → Grain Carry

**Find**:
- `Grain Mobile Agent`
- `Mobile Agent`
- `mobile agent` (lowercase)
- `Grain Mobile Core`
- `grain_mobile_core`
- `plan_mobile.md`
- `tasks_mobile.md`

**Replace**:
- `Grain Carry Agent`
- `Carry Agent`
- `carry agent` (lowercase)
- `Grain Carry Core`
- `grain_carry_core`
- `plan_carry.md`
- `tasks_carry.md`

### Pattern 2: Grain Database → Grain Silo

**Find**:
- `Grain Database Agent`
- `Database Agent`
- `database agent` (lowercase)
- `plan_database.md`
- `tasks_database.md`

**Replace**:
- `Grain Silo Agent`
- `Silo Agent`
- `silo agent` (lowercase)
- `plan_silo.md`
- `tasks_silo.md`

**Note**: Keep `grain_database` module name unchanged (to avoid conflict with `grain_silo` storage).

### Pattern 3: Documentation Section Headers

**Find**:
- `### 6. Grain Mobile Agent`
- `### 7. Grain Database Agent`
- `**Agent**: Grain Mobile Agent`
- `**Agent**: Grain Database Agent`

**Replace**:
- `### 6. Grain Carry Agent`
- `### 7. Grain Silo Agent`
- `**Agent**: Grain Carry Agent`
- `**Agent**: Grain Silo Agent`

---

## Execution Order

### Step 1: Rename Documentation Files
1. Rename `docs/plans/plan_mobile.md` → `docs/plans/plan_carry.md`
2. Rename `docs/tasks/tasks_mobile.md` → `docs/tasks/tasks_carry.md`
3. Rename `docs/plans/plan_database.md` → `docs/plans/plan_silo.md`
4. Rename `docs/tasks/tasks_database.md` → `docs/tasks/tasks_silo.md`
5. Update content in renamed files (agent name references)

### Step 2: Rename Code Module (Grain Mobile → Grain Carry Only)
1. Rename `src/grain_mobile_core/` → `src/grain_carry_core/`
2. Update module root file (`root.zig`) if needed
3. Update all internal references within the module

### Step 3: Update Master Documentation
1. Update `docs/plan.md` — Search and replace both agent names
2. Update `docs/tasks.md` — Search and replace both agent names

### Step 4: Update All Agent Documentation
1. Update all `docs/plans/plan_*.md` files (except the renamed ones)
2. Update all `docs/tasks/tasks_*.md` files (except the renamed ones)

### Step 5: Update Build System
1. Update `build.zig` — Agent references, module paths (`grain_mobile_core` → `grain_carry_core`)
2. Update `build/modules.zig` — Module references
3. Update `build/agents.zig` — Agent configuration

### Step 6: Update Code Files (Grain Mobile → Grain Carry Only)
1. Search all files for `@import("grain_mobile_core")` → `@import("grain_carry_core")`
2. Update test files referencing `grain_mobile_core`
3. Update any other code references

### Step 7: Update Coordination Documents
1. Update `docs/agent-communications/*.md`
2. Consider renaming `docs/*_mobile_*.md` → `docs/*_carry_*.md`
3. Consider renaming `docs/*_database_*.md` → `docs/*_silo_*.md`

### Step 8: Verify
1. Run `grep -r "Mobile Agent" docs/` to find any remaining references
2. Run `grep -r "Database Agent" docs/` to find any remaining references
3. Run `grep -r "plan_mobile\|tasks_mobile" docs/` to find any remaining file references
4. Run `grep -r "plan_database\|tasks_database" docs/` to find any remaining file references
5. Run `grep -r "grain_mobile_core" src/` to find any remaining code references
6. Verify tests still pass
7. Verify build still works

---

## Verification Checklist

After completing the rename:

**Grain Mobile → Grain Carry**:
- [ ] `docs/plans/plan_carry.md` exists (renamed from `plan_mobile.md`)
- [ ] `docs/tasks/tasks_carry.md` exists (renamed from `tasks_mobile.md`)
- [ ] `src/grain_carry_core/` exists (renamed from `grain_mobile_core/`)
- [ ] No references to `plan_mobile.md` in documentation
- [ ] No references to `tasks_mobile.md` in documentation
- [ ] No references to `grain_mobile_core` in code
- [ ] All "Mobile Agent" references updated to "Carry Agent"
- [ ] All "Grain Mobile Agent" references updated to "Grain Carry Agent"
- [ ] Build system updated
- [ ] Tests pass
- [ ] Build works

**Grain Database → Grain Silo**:
- [ ] `docs/plans/plan_silo.md` exists (renamed from `plan_database.md`)
- [ ] `docs/tasks/tasks_silo.md` exists (renamed from `tasks_database.md`)
- [ ] `src/grain_database/` module remains unchanged (to avoid conflict)
- [ ] No references to `plan_database.md` in documentation
- [ ] No references to `tasks_database.md` in documentation
- [ ] All "Database Agent" references updated to "Silo Agent"
- [ ] All "Grain Database Agent" references updated to "Grain Silo Agent"
- [ ] Documentation clarifies: Silo Agent builds Grain Database on Grain Silo foundation
- [ ] Tests pass
- [ ] Build works

---

## Notes

1. **Git History**: We're not preserving file history in the active repo. Git history will preserve the renames.

2. **Module Name Conflict**: Grain Database module stays as `grain_database/` to avoid conflict with existing `grain_silo/` storage module. Only the agent name changes to "Silo Agent".

3. **Clarification Needed**: Documentation should clarify:
   - **Grain Silo** (storage): Object storage module (Skate Agent)
   - **Grain Database** (database): Database module built on Grain Silo (Silo Agent)
   - **Silo Agent**: The agent that builds Grain Database

4. **Test Files**: Test files will need updates for module path changes (Grain Mobile → Grain Carry).

---

## Coordination Message Template

After completion, send this to all agents:

```
We have completed two coordinated renames:

1. "Grain Mobile Agent" → "Grain Carry Agent"
   - Better represents cross-platform portability
   - Module: grain_mobile_core → grain_carry_core
   - Documentation files: plan_mobile.md → plan_carry.md, tasks_mobile.md → tasks_carry.md

2. "Grain Database Agent" → "Grain Silo Agent"
   - Aligns with Grain Silo foundation
   - Module: grain_database/ (unchanged, to avoid conflict with grain_silo/ storage)
   - Documentation files: plan_database.md → plan_silo.md, tasks_database.md → tasks_silo.md

Note: General "mobile" and "database" references remain unchanged (e.g., "mobile app", "database query"). Only agent-specific references were updated.

Please update any references in your documentation if you mention these agents.
```

---

**End of Plan**

**Ready for Execution**: Yes  
**Estimated Time**: 2-3 hours  
**Risk Level**: Medium (includes code module rename for Grain Mobile → Grain Carry)

