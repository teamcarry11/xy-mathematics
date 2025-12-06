# Unified Rename Prompt: Mobile → Carry & Database → Silo

**Date**: 2025-12-05-153506-pst  
**To**: Grain Mobile Agent (→ Grain Carry Agent) & Grain Database Agent (→ Grain Silo Agent)  
**From**: Project Coordination  
**Priority**: HIGH — Agent name standardization

---

## Instructions

Please see `docs/agent-communications/mobile_to_carry_and_database_to_silo_rename_plan.md` for the complete rename plan.

**Your tasks**:

### For Grain Mobile Agent (→ Grain Carry Agent):

1. **Rename Documentation Files**:
   - `docs/plans/plan_mobile.md` → `docs/plans/plan_carry.md`
   - `docs/tasks/tasks_mobile.md` → `docs/tasks/tasks_carry.md`

2. **Rename Code Module**:
   - `src/grain_mobile_core/` → `src/grain_carry_core/` (entire directory)

3. **Update All References**:
   - Agent name: "Grain Mobile Agent" → "Grain Carry Agent"
   - Module imports: `@import("grain_mobile_core")` → `@import("grain_carry_core")`
   - Documentation references
   - Build system references
   - Test file references

4. **Update Your Documentation**:
   - Update `docs/plans/plan_carry.md` (renamed file)
   - Update `docs/tasks/tasks_carry.md` (renamed file)
   - Update all agent name references

### For Grain Database Agent (→ Grain Silo Agent):

1. **Rename Documentation Files**:
   - `docs/plans/plan_database.md` → `docs/plans/plan_silo.md`
   - `docs/tasks/tasks_database.md` → `docs/tasks/tasks_silo.md`

2. **Keep Module Name Unchanged**:
   - **Keep**: `src/grain_database/` (to avoid conflict with `grain_silo/` storage module)
   - Only agent name changes, not module name

3. **Update All References**:
   - Agent name: "Grain Database Agent" → "Grain Silo Agent"
   - Documentation references
   - Build system references (agent name only)

4. **Update Your Documentation**:
   - Update `docs/plans/plan_silo.md` (renamed file)
   - Update `docs/tasks/tasks_silo.md` (renamed file)
   - Update all agent name references
   - Clarify: Silo Agent builds Grain Database on Grain Silo foundation

---

## Copy-Paste Message for Both Agents

```
continue as you best recommend, remember to follow Grain Style (~/xy-mathematics/docs/grain_style.md ) with grain_case function names and all the strict rules with all compiler warnings turned on

We are performing coordinated renames:
1. Grain Mobile Agent → Grain Carry Agent (module: grain_mobile_core → grain_carry_core)
2. Grain Database Agent → Grain Silo Agent (module: grain_database/ stays unchanged)

Please see docs/agent-communications/mobile_to_carry_and_database_to_silo_rename_plan.md for full details.

Key tasks:

FOR MOBILE → CARRY AGENT:
- Rename docs/plans/plan_mobile.md → docs/plans/plan_carry.md
- Rename docs/tasks/tasks_mobile.md → docs/tasks/tasks_carry.md
- Rename src/grain_mobile_core/ → src/grain_carry_core/
- Update all @import("grain_mobile_core") → @import("grain_carry_core")
- Update agent name: "Grain Mobile Agent" → "Grain Carry Agent"
- Update all documentation references
- Update build system references

FOR DATABASE → SILO AGENT:
- Rename docs/plans/plan_database.md → docs/plans/plan_silo.md
- Rename docs/tasks/tasks_database.md → docs/tasks/tasks_silo.md
- Keep src/grain_database/ module name unchanged (to avoid conflict with grain_silo/ storage)
- Update agent name: "Grain Database Agent" → "Grain Silo Agent"
- Update all documentation references
- Clarify: Silo Agent builds Grain Database on Grain Silo foundation

When you're done update the docs/plans/plan_{agent}.md and docs/tasks/tasks_{agent}.md keeping the general summary docs/plan.md and docs/tasks.md in thinking. let me know when you need me to check in with the other agent to prevent conflicts. also make sure all existing and new tests pass that implement their API contracts, enforcing grainwrap-100 and grain validate-70 

have a new terminal date now yyyy-mm-dd-hhmmss-pst- timestamp in your printout summary header

your agent name is: [Grain Mobile Agent → Grain Carry Agent / Grain Database Agent → Grain Silo Agent]
```

---

## Important Notes

1. **Module Name Conflict**: Grain Database module stays as `grain_database/` to avoid conflict with existing `grain_silo/` storage module. Only the agent name changes.

2. **Clarification**: 
   - **Grain Silo** (storage): Object storage module (Skate Agent)
   - **Grain Database** (database): Database module built on Grain Silo (Silo Agent)
   - **Silo Agent**: The agent that builds Grain Database

3. **Execution Order**: Both agents can work in parallel, but coordinate if there are shared references.

4. **Verification**: After completion, verify:
   - No remaining references to old names
   - All tests pass
   - Build works
   - Documentation is consistent

---

**Status**: Ready for execution by both agents

