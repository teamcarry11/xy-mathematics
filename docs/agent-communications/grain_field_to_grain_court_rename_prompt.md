# Grain Field → Grain Court Rename: Coordination Prompt

**Date**: 2025-12-05-144942-pst  
**To**: Grain Skate Agent, Grain Mobile Agent, Grain Aurora Agent, Grain Bubble Agent  
**From**: Project Coordination  
**Priority**: HIGH — Architecture clarification and rename

---

## Summary

Renaming **Grain Field** to **Grain Court** to better represent the WSE-wafer-scale SRAM spatial computing abstraction for self-hostable LLM backend. This rename reflects the vision of Grain Court as scalable fast agentic compute with Cerebras GLM4.6 API as the starting target for WSE hardware.

**New Architecture Clarification**:
- **Grain Silo**: Scalable cheap storage (object storage, general-purpose database foundation)
- **Grain Court** (formerly Grain Field): Scalable fast agentic compute (WSE spatial computing, LLM backend)

---

## Rename Details

### What's Changing

**Old Name**: Grain Field  
**New Name**: Grain Court  
**Inspiration**: Basketball courts (spatial, organized, fast-paced)

**Rationale**:
- Better represents the spatial computing nature (like a basketball court's organized space)
- More intuitive for WSE-wafer-scale SRAM abstraction
- Aligns with vision of fast agentic compute (like a basketball court's fast-paced action)
- Target: Cerebras GLM4.6 API for WSE hardware

### Files to Rename

1. **Source Files**:
   - `src/grain_field/` → `src/grain_court/`
   - `src/grain_field/compute.zig` → `src/grain_court/compute.zig`
   - `src/grain_field/root.zig` → `src/grain_court/root.zig`

2. **Test Files**:
   - Any test files referencing `grain_field` → `grain_court`

3. **Build System**:
   - `build.zig`: Update module references from `grain_field` to `grain_court`

4. **Documentation**:
   - All references to "Grain Field" → "Grain Court"
   - All references to `grain_field` → `grain_court`
   - Update descriptions to emphasize LLM backend and Cerebras GLM4.6 API target

### Code References to Update

1. **Module Imports**:
   - `@import("grain_field")` → `@import("grain_court")`
   - `grain_field.Compute` → `grain_court.Compute`

2. **Comments and Documentation**:
   - "Grain Field" → "Grain Court"
   - "WSE RAM-only spatial computing" → "WSE-wafer-scale SRAM spatial computing for self-hostable LLM backend"
   - Update descriptions to mention Cerebras GLM4.6 API target

3. **Variable Names** (if any):
   - `field_compute` → `court_compute` (or keep as-is if contextually appropriate)

---

## Architecture Clarification

### Grain Silo (Skate Agent)

**Purpose**: Scalable cheap storage  
**Function**: Object storage, general-purpose database foundation  
**Use Cases**:
- Object storage (S3-compatible)
- Database foundation (for Database Agent to extend)
- Cold data storage with hot cache integration

**Note**: Grain Silo serves as the storage foundation. The Database Agent builds a general-purpose database on top of Grain Silo's object storage capabilities.

### Grain Court (formerly Grain Field) (Skate Agent)

**Purpose**: Scalable fast agentic compute  
**Function**: WSE-wafer-scale SRAM spatial computing for self-hostable LLM backend  
**Target**: Cerebras GLM4.6 API for WSE hardware  
**Use Cases**:
- LLM inference (self-hostable)
- Vector search and embeddings
- Spatial computing operations
- Hot cache for active data (SRAM)

**Vision**: Fast agentic compute layer, like a basketball court's organized, fast-paced action.

### Grain Database Agent

**Purpose**: General-purpose database  
**Function**: Hybrid database (key-value + relational + graph + full-text search)  
**Foundation**: Extends Grain Silo's object storage  
**Use Cases**:
- Mobile backend database (for Mobile Agent)
- Structured data storage
- Graph relationships
- Full-text search

**Note**: Database Agent builds on Grain Silo but provides higher-level database features (relational, graph, queries).

### Grain Mobile Agent

**Purpose**: Mobile app backend  
**Function**: REST API endpoints, authentication, user management  
**Database**: Uses Grain Database Agent (decoupled)  
**Use Cases**:
- Mobile app backend API
- Authentication and user management
- Integration with Database Agent via REST API

**Note**: Mobile Agent should use Database Agent's REST API, not directly access Grain Silo. This keeps them decoupled.

---

## Tasks for Each Agent

### Grain Skate Agent (Primary Owner)

**Priority**: HIGHEST — You own Grain Field/Court and Grain Silo

**Tasks**:
1. ✅ Rename `src/grain_field/` → `src/grain_court/`
2. ✅ Update all module exports in `src/grain_court/root.zig`
3. ✅ Update all internal references in `src/grain_court/compute.zig`
4. ✅ Update `src/grain_skate/storage_integration.zig` to use `grain_court`
5. ✅ Update `src/grain_silo/storage.zig` comments (remove Grain Field references, add Grain Court)
6. ✅ Update `build.zig` module references
7. ✅ Update test files (if any reference `grain_field`)
8. ✅ Update `docs/plans/plan_skate.md` with rename
9. ✅ Update `docs/tasks/tasks_skate.md` with rename
10. ✅ Update all documentation references to "Grain Field" → "Grain Court"
11. ✅ Update descriptions to emphasize LLM backend and Cerebras GLM4.6 API target

**Files to Check**:
- `src/grain_skate/storage_integration.zig` (uses `grain_field`)
- `src/grain_silo/storage.zig` (mentions Grain Field in comments)
- All documentation files

### Grain Mobile Agent

**Priority**: MEDIUM — Check for any references

**Tasks**:
1. ✅ Search codebase for "Grain Field" or `grain_field` references
2. ✅ Update any documentation that mentions Grain Field
3. ✅ Update `docs/plans/plan_mobile.md` if it references Grain Field
4. ✅ Update `docs/tasks/tasks_mobile.md` if it references Grain Field

**Note**: Mobile Agent primarily uses Database Agent, so may have minimal references.

### Grain Aurora Agent

**Priority**: MEDIUM — Check for any references

**Tasks**:
1. ✅ Search codebase for "Grain Field" or `grain_field` references
2. ✅ Update any documentation that mentions Grain Field
3. ✅ Update `docs/plans/plan_aurora.md` if it references Grain Field
4. ✅ Update `docs/tasks/tasks_aurora.md` if it references Grain Field

**Note**: Aurora Agent may reference Grain Field for vector search or LLM integration.

### Grain Bubble Agent

**Priority**: MEDIUM — Check for any references

**Tasks**:
1. ✅ Search codebase for "Grain Field" or `grain_field` references
2. ✅ Update any documentation that mentions Grain Field
3. ✅ Update `docs/plans/plan_bubble.md` if it references Grain Field (I see it mentions "Grain Field" for vector search)
4. ✅ Update `docs/tasks/tasks_bubble.md` if it references Grain Field
5. ✅ Update `docs/proposals/grain_bubble_proposal.md` (mentions Grain Field)

**Note**: Bubble Agent proposal mentions Grain Field for vector search and LLM integration.

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

## Testing Requirements

1. ✅ All existing tests must pass after rename
2. ✅ Update test file names if they reference `grain_field`
3. ✅ Update test imports to use `grain_court`
4. ✅ Verify no compilation errors
5. ✅ Run `zig build test --summary all` to ensure all tests pass

---

## Documentation Updates

Update the following documentation files:

1. ✅ `docs/plan.md` — Master plan
2. ✅ `docs/tasks.md` — Master tasks
3. ✅ `docs/plans/plan_skate.md` — Skate agent plan
4. ✅ `docs/tasks/tasks_skate.md` — Skate agent tasks
5. ✅ `docs/plans/plan_mobile.md` — Mobile agent plan (if references exist)
6. ✅ `docs/plans/plan_aurora.md` — Aurora agent plan (if references exist)
7. ✅ `docs/plans/plan_bubble.md` — Bubble agent plan (mentions Grain Field)
8. ✅ `docs/proposals/grain_bubble_proposal.md` — Bubble proposal (mentions Grain Field)
9. ✅ Any coordination documents mentioning Grain Field

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

## Questions or Issues

If you encounter any issues during the rename:
1. Check for any dependencies on `grain_field` module
2. Verify build system configuration
3. Update test files if needed
4. Coordinate with other agents if shared code is affected

---

**Status**: Ready for implementation  
**Target Completion**: As soon as possible  
**Coordination**: All agents should complete their tasks independently, but Skate Agent should go first since it owns the module.

