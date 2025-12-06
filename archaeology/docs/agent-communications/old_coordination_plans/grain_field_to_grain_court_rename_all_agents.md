# Grain Field → Grain Court Rename: All Agents Coordination

**Date**: 2025-12-05-144942-pst  
**To**: Grain Skate Agent, Grain Mobile Agent, Grain Aurora Agent, Grain Bubble Agent  
**From**: Project Coordination  
**Priority**: HIGH — Architecture clarification and rename

---

## Executive Summary

We are renaming **Grain Field** to **Grain Court** to better represent the WSE-wafer-scale SRAM spatial computing abstraction for self-hostable LLM backend. This rename reflects the vision of Grain Court as scalable fast agentic compute with Cerebras GLM4.6 API as the starting target for WSE hardware.

**New Architecture**:
- **Grain Silo**: Scalable cheap storage (object storage, general-purpose database foundation)
- **Grain Court** (formerly Grain Field): Scalable fast agentic compute (WSE spatial computing, LLM backend)

---

## What's Changing

**Old Name**: Grain Field (`grain_field`)  
**New Name**: Grain Court (`grain_court`)  
**Inspiration**: Basketball courts (spatial, organized, fast-paced)

**Rationale**:
- Better represents spatial computing nature (organized space like a basketball court)
- More intuitive for WSE-wafer-scale SRAM abstraction
- Aligns with vision of fast agentic compute (fast-paced action)
- Target: Cerebras GLM4.6 API for WSE hardware

---

## Architecture Clarification

### Grain Silo (Skate Agent)
- **Purpose**: Scalable cheap storage
- **Function**: Object storage, general-purpose database foundation
- **Use Cases**: 
  - Object storage (S3-compatible)
  - Database foundation (for Database Agent to extend)
  - Cold data storage with hot cache integration
- **Note**: Grain Silo serves as the storage foundation. The Database Agent builds a general-purpose database on top of Grain Silo's object storage capabilities.

### Grain Court (formerly Grain Field) (Skate Agent)
- **Purpose**: Scalable fast agentic compute
- **Function**: WSE-wafer-scale SRAM spatial computing for self-hostable LLM backend
- **Target**: Cerebras GLM4.6 API for WSE hardware
- **Use Cases**:
  - LLM inference (self-hostable)
  - Vector search and embeddings
  - Spatial computing operations
  - Hot cache for active data (SRAM)
- **Vision**: Fast agentic compute layer, like a basketball court's organized, fast-paced action.

### Grain Database Agent
- **Purpose**: General-purpose database
- **Function**: Hybrid database (key-value + relational + graph + full-text search)
- **Foundation**: Extends Grain Silo's object storage
- **Use Cases**:
  - Mobile backend database (for Mobile Agent)
  - Structured data storage
  - Graph relationships
  - Full-text search
- **Note**: Database Agent builds on Grain Silo but provides higher-level database features (relational, graph, queries).

### Grain Mobile Agent
- **Purpose**: Mobile app backend
- **Function**: REST API endpoints, authentication, user management
- **Database**: Uses Grain Database Agent (decoupled via REST API)
- **Use Cases**:
  - Mobile app backend API
  - Authentication and user management
  - Integration with Database Agent via REST API
- **Note**: Mobile Agent should use Database Agent's REST API, not directly access Grain Silo. This keeps them decoupled.

---

## Tasks for Each Agent

### Grain Skate Agent (Primary Owner) — HIGHEST PRIORITY

**You own**: `src/grain_field/` → `src/grain_court/`

**Tasks**:
1. ✅ Rename directory: `src/grain_field/` → `src/grain_court/`
2. ✅ Update module exports in `src/grain_court/root.zig`
3. ✅ Update all internal references in `src/grain_court/compute.zig`
4. ✅ Update `src/grain_skate/storage_integration.zig` (uses `grain_field`)
5. ✅ Update `src/grain_silo/storage.zig` comments (remove Grain Field references, add Grain Court)
6. ✅ Update `build.zig` module references from `grain_field` to `grain_court`
7. ✅ Update test files if they reference `grain_field`
8. ✅ Update `docs/plans/plan_skate.md` (mentions Grain Field in 2 places)
9. ✅ Update `docs/tasks/tasks_skate.md` if it references Grain Field
10. ✅ Update all documentation references to "Grain Field" → "Grain Court"
11. ✅ Update descriptions to emphasize LLM backend and Cerebras GLM4.6 API target

**Files to Check**:
- `src/grain_skate/storage_integration.zig` (uses `grain_field`)
- `src/grain_silo/storage.zig` (mentions Grain Field in comments)
- `docs/plans/plan_skate.md` (2 references)
- All documentation files

**Code Changes**:
- `@import("grain_field")` → `@import("grain_court")`
- `grain_field.Compute` → `grain_court.Compute`
- `FieldCompute` → `CourtCompute` (or keep as-is if contextually appropriate)
- Update comments: "Grain Field" → "Grain Court"
- Update descriptions to mention Cerebras GLM4.6 API target

### Grain Mobile Agent — MEDIUM PRIORITY

**Tasks**:
1. ✅ Search codebase for "Grain Field" or `grain_field` references
2. ✅ Update any documentation that mentions Grain Field
3. ✅ Update `docs/plans/plan_mobile.md` if it references Grain Field (none found, but verify)
4. ✅ Update `docs/tasks/tasks_mobile.md` if it references Grain Field

**Note**: Mobile Agent primarily uses Database Agent, so may have minimal references. Mobile Agent should use Database Agent's REST API, not directly access Grain Silo or Grain Court.

### Grain Aurora Agent — MEDIUM PRIORITY

**Tasks**:
1. ✅ Search codebase for "Grain Field" or `grain_field` references
2. ✅ Update any documentation that mentions Grain Field
3. ✅ Update `docs/plans/plan_aurora.md` if it references Grain Field (none found, but verify)
4. ✅ Update `docs/tasks/tasks_aurora.md` if it references Grain Field

**Note**: Aurora Agent may reference Grain Field for vector search or LLM integration.

### Grain Bubble Agent — MEDIUM PRIORITY

**Tasks**:
1. ✅ Search codebase for "Grain Field" or `grain_field` references
2. ✅ Update `docs/plans/plan_bubble.md` (4 references found: lines 125, 133, 238, 351)
3. ✅ Update `docs/tasks/tasks_bubble.md` if it references Grain Field
4. ✅ Update `docs/proposals/grain_bubble_proposal.md` (mentions Grain Field at line 101)

**Specific Updates Needed**:
- `docs/plans/plan_bubble.md` line 125: "Vector search for component matching (Grain Field)" → "Grain Court"
- `docs/plans/plan_bubble.md` line 133: "Grain Field (`grain_field/compute.zig`)" → "Grain Court (`grain_court/compute.zig`)"
- `docs/plans/plan_bubble.md` line 238: "Grain Field (`grain_field/compute.zig`)" → "Grain Court (`grain_court/compute.zig`)"
- `docs/plans/plan_bubble.md` line 351: "Silo/Field" → "Silo/Court"
- `docs/proposals/grain_bubble_proposal.md` line 101: "Grain Field" → "Grain Court"

**Note**: Bubble Agent proposal mentions Grain Field for vector search and LLM integration.

---

## Code Changes Required

### Module Imports
```zig
// Old
const grain_field = @import("grain_field");
const FieldCompute = grain_field.Compute.FieldCompute;

// New
const grain_court = @import("grain_court");
const CourtCompute = grain_court.Compute.CourtCompute;
```

### Comments and Documentation
- "Grain Field" → "Grain Court"
- "WSE RAM-only spatial computing" → "WSE-wafer-scale SRAM spatial computing for self-hostable LLM backend"
- Update descriptions to mention Cerebras GLM4.6 API target

### Build System
- Update `build.zig` module references from `grain_field` to `grain_court`

---

## Testing Requirements

1. ✅ All existing tests must pass after rename
2. ✅ Update test file names if they reference `grain_field`
3. ✅ Update test imports to use `grain_court`
4. ✅ Verify no compilation errors
5. ✅ Run `zig build test --summary all` to ensure all tests pass

---

## Documentation Updates

Update the following documentation files:

1. ✅ `docs/plan.md` — Master plan (if references exist)
2. ✅ `docs/tasks.md` — Master tasks (if references exist)
3. ✅ `docs/plans/plan_skate.md` — Skate agent plan (2 references)
4. ✅ `docs/tasks/tasks_skate.md` — Skate agent tasks (if references exist)
5. ✅ `docs/plans/plan_mobile.md` — Mobile agent plan (verify, none found)
6. ✅ `docs/plans/plan_aurora.md` — Aurora agent plan (verify, none found)
7. ✅ `docs/plans/plan_bubble.md` — Bubble agent plan (4 references)
8. ✅ `docs/proposals/grain_bubble_proposal.md` — Bubble proposal (1 reference)
9. ✅ Any coordination documents mentioning Grain Field

---

## Grain Style Compliance

All changes must maintain Grain Style compliance:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled

---

## Success Criteria

- ✅ All code compiles without errors
- ✅ All tests pass
- ✅ All references to "Grain Field" updated to "Grain Court"
- ✅ All module imports updated
- ✅ Documentation updated
- ✅ Build system updated
- ✅ No broken references

---

## Coordination Notes

**Execution Order**:
1. **Skate Agent goes first** — Owns the module, must rename directory and update core code
2. **Other agents can work in parallel** — Once Skate Agent completes, other agents can update their references independently

**No Conflicts Expected**:
- This is a rename operation, not new functionality
- Each agent updates their own files
- Skate Agent owns the module, others just reference it

---

## Questions or Issues

If you encounter any issues during the rename:
1. Check for any dependencies on `grain_field` module
2. Verify build system configuration
3. Update test files if needed
4. Coordinate with Skate Agent if shared code is affected

---

**Status**: Ready for implementation  
**Target Completion**: As soon as possible  
**Coordination**: Skate Agent should complete first, then other agents can update their references.

---

## Copy-Paste Message for All Agents

```
continue as you best recommend, remember to follow Grain Style (~/xy-mathematics/docs/grain_style.md ) with grain_case function names and all the strict rules with all compiler warnings turned on

We are renaming Grain Field to Grain Court. Please see docs/agent-communications/grain_field_to_grain_court_rename_all_agents.md for full details.

Key tasks:
- Search for "Grain Field" or "grain_field" references in your codebase
- Update module imports: @import("grain_field") → @import("grain_court")
- Update documentation references
- Update your agent's plan and tasks files if they mention Grain Field
- Ensure all tests pass after changes

Grain Court (formerly Grain Field) is the WSE-wafer-scale SRAM spatial computing abstraction for self-hostable LLM backend, targeting Cerebras GLM4.6 API for WSE hardware.

When you're done update the docs/plan_{agent}.md and docs/tasks/tasks_{agent}.md keeping the general summary docs/plan.md and docs/tasks.md in thinking. let me know when you need me to check in with the other agent to prevent conflicts. also make sure all existing and new tests pass that implement their API contracts, enforcing grainwrap-100 and grain validate-70 

have a new terminal date now yyyy-mm-dd-hhmmss-pst- timestamp in your printout summary header

your agent name is: [Grain Skate Agent / Grain Mobile Agent / Grain Aurora Agent / Grain Bubble Agent]
```

