# Aurora IDE Dream Browser Agent: Documentation Refactor Prompt

**Date**: 2025-12-03-165133-pst  
**Agent**: Grain Aurora IDE Dream Browser Agent  
**Purpose**: Refactor plan and tasks into new hybrid documentation structure

---

## Context

The Grain OS project has migrated to a **hybrid documentation structure** to improve performance and maintain coordination across 7 agents working in parallel.

### New Structure

```
docs/
├── plan.md                    # Master overview (high-level, all agents)
├── tasks.md                   # Master task list (high-level, all agents)
├── plans/
│   ├── plan_core.md            # Grain Core Agent detailed plan
│   └── plan_aurora.md        # YOUR FILE (to be created)
└── tasks/
    ├── tasks_core.md           # Grain Core Agent detailed tasks
    └── tasks_aurora.md       # YOUR FILE (to be created)
```

### Why This Structure?

- **Performance**: Master files reduced from 5,252 lines to 431 lines (92% reduction)
- **Coordination**: Master files maintain cross-agent awareness
- **Clarity**: Agent-specific files focus on your work
- **Scalability**: Structure grows with agent count, not total work

**Reference**: See [`docs/documentation_structure_recommendation.md`](documentation_structure_recommendation.md) for full rationale.

---

## Your Task

Create two files following the Grain Core Agent's example:

1. **`docs/plans/plan_aurora.md`** — Detailed development plan
2. **`docs/tasks/tasks_aurora.md`** — Detailed task list

### Reference Files

- **Example Plan**: [`docs/plans/plan_core.md`](plans/plan_core.md) — Grain Core Agent plan (448 lines)
- **Example Tasks**: [`docs/tasks/tasks_core.md`](tasks/tasks_core.md) — Grain Core Agent tasks (188 lines)
- **Master Plan**: [`docs/plan.md`](plan.md) — Master overview (236 lines)
- **Master Tasks**: [`docs/tasks.md`](tasks.md) — Master task list (195 lines)

---

## Content to Include

### 1. Plan File (`docs/plans/plan_aurora.md`)

**Structure**:
```markdown
# Aurora IDE Dream Browser Agent: Development Plan

**Agent**: Grain Aurora IDE Dream Browser Agent (2nd Agent)
**Status**: [Current status]
**Last Updated**: 2025-12-03-165133-pst

---

## Overview

[Brief description of Aurora IDE and Dream Browser]

**Key Goals**:
- [Goal 1]
- [Goal 2]
- [Goal 3]

---

## Completed Phases

### Phase X: [Phase Name] ✅ **COMPLETE**
- [Description]
- [Key achievements]
- [Files created/modified]
- [Tests]

[... more completed phases ...]

---

## Current Work: Phase [X] - [Phase Name]

**Priority**: [Priority level]
**Status**: [Status]
**Estimated Time**: [Time estimate]

### Why This Phase
[Rationale]

### Features
[Feature list]

### Deliverables
[Deliverables list]

### Dependencies
- **Needs**: [What you need from other agents]
- **Provides**: [What you provide to other agents]
- **Coordinates with**: [Other agents]

---

## Planned Phases

### Phase [X+1]: [Phase Name]
[Description]

---

## Coordination Points

### With Grain Core Agent

**Shared Components**:
- [Shared components]

**Integration Points**:
- [Integration points]

**Coordination Tasks**:
- [Coordination tasks]

### With Grain Skate Agent

[Similar structure]

### With Other Agents

[As needed]

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md)
- **Master Plan**: [`docs/plan.md`](../plan.md)
- [Other references]
```

### 2. Tasks File (`docs/tasks/tasks_aurora.md`)

**Structure**:
```markdown
# Aurora IDE Dream Browser Agent: Task List

**Agent**: Grain Aurora IDE Dream Browser Agent (2nd Agent)
**Status**: [Current status]
**Last Updated**: 2025-12-03-165133-pst

---

## Current Work: Phase [X] - [Phase Name]

**Priority**: [Priority]
**Status**: [Status]
**Estimated Time**: [Time]

### Tasks

- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

### Grain Style Requirements
[Requirements]

### Dependencies
[Dependencies]

---

## Planned: Phase [X+1] - [Phase Name]

[Similar structure]

---

## Completed Phases (Summary)

[Summary of completed work]

---

## Coordination Tasks

[Coordination tasks with other agents]

---

## References

[References]
```

---

## Your Recent Work to Include

### Completed: Aurora Font Renderer Migration (Phase 1.2) ✅

**Date**: 2025-12-03-162659-PST

**Completed Work**:
1. **Aurora font renderer migration** (`src/aurora_text_renderer.zig`):
   - Migrated to use shared font renderer (`shared.FontRenderer`)
   - Removed duplicate `getCharPattern()` function (195 lines of font patterns)
   - Added `init()` method for initialization
   - Updated `TextRenderer` struct to include `font_renderer: shared.FontRenderer`
   - Updated `draw_char()` to use `render_char_to_pixels()` from shared module
   - Changed `char_idx` from `usize` to `u32` (Grain Style compliance)
   - All functions comply with max 70 lines per function
   - All lines comply with max 73 characters per line

2. **Build system integration** (`build.zig`):
   - Added shared module import to `text_renderer_tests` configuration

3. **Code reduction**:
   - File reduced from 205 lines to 150 lines (55 lines removed)
   - Removed 195 lines of duplicate font pattern code

4. **Grain Style compliance**: Full compliance achieved

**Benefits**:
- Code deduplication: removed 195 lines of duplicate font patterns
- Shared maintenance: font rendering bugs fixed once benefit all applications
- Consistency: Aurora now uses the same font renderer as Grain Skate and Grain OS
- Flexibility: can switch font sizes/character sets via shared API

**Coordination**:
- Completed Phase 1.2 of shared module refactoring plan
- Ready for Grain Core Agent to migrate `src/grain_core/font_renderer.zig` (Phase 1.3)
- Ready for Grain Skate Agent to migrate `src/grain_skate/editor_renderer.zig` (Phase 1.4)

---

## Coordination with Grain Core Agent

### Shared Module Refactoring

**Status**: Phase 1.2 Complete (Aurora) ✅

**Next Steps**:
1. **Grain Core Agent**: Migrate `src/grain_core/font_renderer.zig` to use shared font renderer (Phase 1.3)
2. **Grain Skate Agent**: Migrate `src/grain_skate/editor_renderer.zig` to use shared font renderer (Phase 1.4)

**Coordination Notes**:
- Aurora Agent has completed font renderer migration
- Grain Core Agent is aware and ready to proceed (see `docs/grain_os_font_renderer_coordination.md`)
- No conflicts expected — each agent migrates independently

### Future Coordination

**Phase 2: Text Buffer Unification** (Planned):
- Aurora Agent uses `GrainBuffer` from `src/grain_buffer.zig`
- Grain Skate Agent will migrate to use `GrainBuffer`
- Coordination needed on API compatibility

**Phase 3: DAG Integration** (Planned):
- Aurora Agent uses DAG for event ordering
- Grain Skate Agent will integrate DAG for undo/redo
- Coordination needed on DAG API

**Phase 4: UI Rendering Unification** (Planned):
- Aurora Agent uses `GrainAurora` component-first rendering
- Evaluation needed for Grain Skate use case
- Coordination needed on component API

---

## What to Extract from Old Files

### From `archaeology/docs/plan_tasks_archive/plan_2025-12-03-165133-pst.md`:

Search for sections related to:
- "Aurora", "Dream", "Dream Editor", "Dream Browser"
- "Phase 4", "Phase 0"
- Your agent's work

Extract:
- Completed phases
- Current work
- Planned phases
- Coordination notes

### From `archaeology/docs/plan_tasks_archive/tasks_2025-12-03-165133-pst.md`:

Search for:
- Aurora/Dream tasks
- Phase 4 tasks
- Phase 0 tasks

Extract:
- Task lists for each phase
- Completed tasks
- Pending tasks
- Coordination tasks

---

## Guidelines

### File Size Target

- **Plan file**: ~300-500 lines (detailed but manageable)
- **Tasks file**: ~200-400 lines (detailed but manageable)
- **Master files**: Will be updated by you after creating agent files

### Content Guidelines

1. **Be Detailed**: Include implementation details, file paths, test names
2. **Be Specific**: Include phase numbers, dates, status
3. **Be Coordinated**: Include dependencies and coordination points
4. **Be Current**: Include recent work (font renderer migration)

### Cross-References

- Link to master files: `[Master Plan](../plan.md)`
- Link to other agent files: `[Grain OS Plan](../plans/plan_core.md)`
- Link to shared docs: `[Grain Style](../grain_style.md)`

---

## Steps to Complete

1. **Read Reference Files**:
   - Read `docs/plans/plan_core.md` to understand structure
   - Read `docs/tasks/tasks_core.md` to understand task format
   - Read `docs/documentation_structure_recommendation.md` for rationale

2. **Extract Your Content**:
   - Search old plan file for Aurora/Dream sections
   - Search old tasks file for Aurora/Dream tasks
   - Include recent font renderer migration work

3. **Create Plan File**:
   - Create `docs/plans/plan_aurora.md`
   - Follow structure from `plan_core.md`
   - Include completed phases, current work, planned phases
   - Include coordination points

4. **Create Tasks File**:
   - Create `docs/tasks/tasks_aurora.md`
   - Follow structure from `tasks_core.md`
   - Include task lists for each phase
   - Include coordination tasks

5. **Update Master Files**:
   - Update `docs/plan.md` with Aurora Agent summary (if not already there)
   - Update `docs/tasks.md` with Aurora Agent summary (if not already there)
   - Keep summaries concise (1-2 paragraphs)

6. **Verify**:
   - Check file sizes (plan: ~300-500 lines, tasks: ~200-400 lines)
   - Check cross-references work
   - Check coordination points are documented

---

## Example Master File Entry

After creating your files, the master `docs/plan.md` should have an entry like:

```markdown
### 2. Grain Aurora IDE Dream Browser Agent

**Status**: Active — Editor and browser development  
**Current Work**: Foundation components, shared modules  
**Details**: See [`docs/plans/plan_aurora.md`](plans/plan_aurora.md)

**Recent Progress**:
- Shared foundation components
- Font renderer migration (Phase 1.2) ✅
- DAG integration
- Editor-browser integration

**Provides**: Editor framework, browser engine, AI provider integration
```

---

## Questions to Answer

1. **What phases have you completed?**
   - List all completed phases with dates and achievements

2. **What is your current work?**
   - Current phase, status, priority, estimated time

3. **What phases are planned?**
   - Next phases with descriptions and dependencies

4. **What do you coordinate with other agents?**
   - Shared components, integration points, coordination tasks

5. **What dependencies do you have?**
   - What you need from other agents
   - What you provide to other agents

---

## Success Criteria

✅ Plan file created (`docs/plans/plan_aurora.md`)  
✅ Tasks file created (`docs/tasks/tasks_aurora.md`)  
✅ Files follow structure from reference files  
✅ Recent work (font renderer migration) included  
✅ Coordination points documented  
✅ Master files updated (if needed)  
✅ File sizes reasonable (~300-500 lines for plan, ~200-400 for tasks)  
✅ Cross-references work  
✅ Grain Style compliance mentioned where relevant

---

## References

- **Documentation Structure**: [`docs/documentation_structure_recommendation.md`](documentation_structure_recommendation.md)
- **Grain Core Agent Plan**: [`docs/plans/plan_core.md`](plans/plan_core.md) — Example structure
- **Grain Core Agent Tasks**: [`docs/tasks/tasks_core.md`](tasks/tasks_core.md) — Example structure
- **Master Plan**: [`docs/plan.md`](plan.md) — Master overview
- **Master Tasks**: [`docs/tasks.md`](tasks.md) — Master task list
- **Grain Style**: [`docs/grain_style.md`](grain_style.md) — Coding principles
- **Archived Files**: `archaeology/docs/plan_tasks_archive/` — Previous versions

---

**Your Mission**: Create `docs/plans/plan_aurora.md` and `docs/tasks/tasks_aurora.md` following the hybrid documentation structure, including your recent font renderer migration work and coordination points with Grain Core Agent.

**Remember**: Be detailed, be specific, be coordinated. The goal is to have focused agent files while maintaining coordination through master files.

Good luck! 🚀

