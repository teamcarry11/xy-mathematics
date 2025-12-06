# Documentation Structure Recommendation

**Date**: 2025-12-03-163301-pst  
**Context**: 7 agents working in parallel, `plan.md` (2776 lines) and `tasks.md` (2427 lines) getting large  
**Question**: Should we split into agent-specific files?

---

## Current State Analysis

### File Sizes
- `docs/plan.md`: **2,776 lines**, 129 sections
- `docs/tasks.md`: **2,427 lines**, 105 sections
- **Total**: 5,203 lines

### Agent Count
- 7 agents working in parallel:
  1. Grain Vantage VM Basin Kernel Agent
  2. Grain Aurora IDE Dream Browser Agent
  3. Grain Skate Silo Field Agent
  4. Grain Core Agent
  5. Grain Workspace Agent
  6. Grain Mobile Agent
  7. Grain Database Agent

### Current Coordination Pattern
- Agents use coordination documents (`docs/zyx*.md`)
- Cross-references in plan.md and tasks.md
- Agent-specific prompts (`docs/grain_*_agent_prompt.md`)
- Some agent-specific summaries

---

## Arguments FOR Splitting

### 1. Performance Benefits
- **Faster reads**: Smaller files = faster file operations
- **Faster edits**: Less content to parse when editing
- **Reduced memory**: Smaller files in memory
- **Better tooling**: IDEs handle smaller files better

### 2. Clarity Benefits
- **Focused view**: Each agent sees only their work
- **Easier navigation**: Find relevant sections faster
- **Reduced cognitive load**: Less to read/understand

### 3. Reduced Conflicts
- **Less merge conflicts**: Agents edit different files
- **Parallel editing**: Multiple agents can edit simultaneously
- **Isolated changes**: Changes don't affect other agents' sections

### 4. Scalability
- **Linear growth**: Files grow with agent count, not total work
- **Maintainable**: Easier to maintain smaller files
- **Future-proof**: Can add more agents without file bloat

---

## Arguments AGAINST Splitting

### 1. Coordination Risk ⚠️ **CRITICAL CONCERN**
- **Lost dependencies**: Agents might miss cross-agent dependencies
- **Isolated work**: Agents might work in silos
- **Missed integration points**: Harder to see where agents connect
- **Example**: Database Agent needs API Server (Grain Core Agent) but might not see it

### 2. Search Difficulty
- **Cross-file search**: Harder to search across all agents
- **Context loss**: Search results lack full context
- **Dependency discovery**: Harder to find what depends on what

### 3. Duplication Risk
- **Repeated information**: Same info in multiple files
- **Sync issues**: Updates need to happen in multiple places
- **Inconsistency**: Files might drift out of sync

### 4. Maintenance Overhead
- **Multiple files**: More files to maintain
- **Sync burden**: Need to keep files in sync
- **Update complexity**: Changes might need updates in multiple files

### 5. Context Loss
- **Big picture**: Harder to see overall project status
- **Dependencies**: Harder to see cross-agent dependencies
- **Integration points**: Harder to see where agents integrate

---

## Recommended Solution: Hybrid Approach ✅

### Structure

```
docs/
├── plan.md                    # Master overview (high-level status)
├── tasks.md                   # Master task list (high-level tasks)
├── plans/
│   ├── plan_kernel.md         # Kernel Agent detailed plan
│   ├── plan_aurora.md         # Aurora Agent detailed plan
│   ├── plan_skate.md          # Skate Agent detailed plan
│   ├── plan_core.md             # OS Agent detailed plan
│   ├── plan_workspace.md      # Workspace Agent detailed plan
│   ├── plan_mobile.md         # Mobile Agent detailed plan
│   └── plan_database.md       # Database Agent detailed plan
└── tasks/
    ├── tasks_kernel.md        # Kernel Agent detailed tasks
    ├── tasks_aurora.md         # Aurora Agent detailed tasks
    ├── tasks_skate.md          # Skate Agent detailed tasks
    ├── tasks_core.md             # OS Agent detailed tasks
    ├── tasks_workspace.md      # Workspace Agent detailed tasks
    ├── tasks_mobile.md         # Mobile Agent detailed tasks
    └── tasks_database.md      # Database Agent detailed tasks
```

### Master Files (`plan.md`, `tasks.md`)

**Purpose**: High-level overview, coordination, cross-references

**Content**:
- Overall project status
- Agent status summary (1-2 paragraphs per agent)
- Cross-agent dependencies
- Integration points
- Coordination notes
- Links to detailed agent files

**Size**: ~200-300 lines (manageable)

**Example Structure**:
```markdown
# Grain OS Development Plan

## Overall Status
- Phase X complete
- 7 agents active
- Next milestone: Y

## Agent Status

### Grain Core Agent
**Status**: Phase 58 complete, starting Phase 59  
**Current Work**: HTTP/REST API Server  
**Dependencies**: None  
**Provides**: API Server, Auth Service (for Database/Mobile Agents)  
**Details**: See `plans/plan_core.md`

### Grain Database Agent
**Status**: Starting Phase 1  
**Current Work**: Database Foundation  
**Dependencies**: API Server (Grain Core Agent), File Storage (Kernel Agent)  
**Provides**: Database backend (for Mobile Agent)  
**Details**: See `plans/plan_database.md`

[... other agents ...]

## Cross-Agent Dependencies
- Database Agent → OS Agent (API Server)
- Mobile Agent → Database Agent (Backend)
- Mobile Agent → OS Agent (Auth Service)
[...]

## Integration Points
- API Server (OS) → Database (Database) → Mobile App (Mobile)
[...]
```

### Agent-Specific Files (`plans/plan_{agent}.md`, `tasks/tasks_{agent}.md`)

**Purpose**: Detailed work for each agent

**Content**:
- Detailed phase descriptions
- Specific tasks
- Implementation details
- Test requirements
- Coordination notes (with other agents)

**Size**: ~300-500 lines per agent (manageable)

**Benefits**:
- Agents focus on their work
- Faster reads/writes
- Reduced conflicts
- Detailed tracking

---

## Implementation Strategy

### Phase 1: Create Structure (Week 1)

1. **Create directories**:
   ```bash
   mkdir -p docs/plans docs/tasks
   ```

2. **Extract agent sections** from `plan.md` and `tasks.md`:
   - Identify agent-specific sections
   - Move to `plans/plan_{agent}.md` and `tasks/tasks_{agent}.md`
   - Keep cross-agent sections in master files

3. **Create master files**:
   - High-level status
   - Agent summaries
   - Cross-references
   - Dependencies

### Phase 2: Update References (Week 1)

1. **Update agent prompts**:
   - Reference new file locations
   - Update coordination instructions

2. **Update coordination documents**:
   - Reference new file locations
   - Update cross-references

3. **Update build/docs**:
   - Ensure new structure is documented

### Phase 3: Migration (Week 1-2)

1. **Archive old files**:
   - Move `plan.md` → `archaeology/docs/plan_2025-12-03.md`
   - Move `tasks.md` → `archaeology/docs/tasks_2025-12-03.md`

2. **Create new master files**:
   - `plan.md` (new, high-level)
   - `tasks.md` (new, high-level)

3. **Create agent files**:
   - Extract and organize agent-specific content

### Phase 4: Coordination System (Week 2)

1. **Cross-reference format**:
   - Use `[Agent Name](plans/plan_{agent}.md)` links
   - Use `[Task Name](tasks/tasks_{agent}.md)` links

2. **Dependency tracking**:
   - List dependencies in master files
   - Link to dependent agent files

3. **Integration points**:
   - Document in master files
   - Link to relevant agent files

---

## Coordination Mechanisms

### 1. Master File Updates

**When**: After each phase completion

**What**:
- Update agent status
- Update dependencies
- Update integration points

**Who**: Agent completing phase

### 2. Cross-References

**Format**: `[Agent Name](plans/plan_{agent}.md#section)`

**Purpose**: Link to detailed work

**Example**:
```markdown
Database Agent needs API Server from [Grain Core Agent](plans/plan_core.md#phase-59-api-server).
```

### 3. Dependency Tracking

**Location**: Master files, agent files

**Format**:
```markdown
## Dependencies
- **Needs**: API Server from [Grain Core Agent](plans/plan_core.md#phase-59)
- **Provides**: Database backend to [Grain Mobile Agent](plans/plan_mobile.md#backend)
```

### 4. Regular Sync

**Frequency**: Weekly or after major phases

**Process**:
- Review master files
- Update agent statuses
- Check dependencies
- Verify integration points

---

## Counterarguments Addressed

### "Agents will lose sight of other agents"

**Mitigation**:
- Master files show all agent status
- Cross-references link to other agents
- Dependency tracking shows connections
- Regular sync ensures awareness

### "Search will be harder"

**Mitigation**:
- Master files provide search entry point
- Cross-references link to details
- Use `grep -r` for cross-file search
- IDEs can search across directories

### "Files will drift out of sync"

**Mitigation**:
- Master files are single source of truth for status
- Agent files are detailed work logs
- Regular sync process
- Clear ownership (each agent owns their files)

### "More files to maintain"

**Mitigation**:
- Each agent maintains their own files
- Master files are lightweight
- Clear structure reduces confusion
- Benefits outweigh costs

---

## Benefits of Hybrid Approach

### 1. Best of Both Worlds
- **Coordination**: Master files keep agents aware
- **Performance**: Smaller files = faster operations
- **Clarity**: Agents focus on their work
- **Scalability**: Structure scales with agent count

### 2. Reduced Risk
- **Dependencies**: Tracked in master files
- **Integration**: Documented in master files
- **Context**: Preserved through cross-references
- **Sync**: Regular process ensures consistency

### 3. Improved Workflow
- **Faster edits**: Agents edit smaller files
- **Less conflicts**: Agents edit different files
- **Better focus**: Agents see only their work
- **Easier navigation**: Clear structure

---

## Recommendation: ✅ **Implement Hybrid Approach**

### Why This Is Best

1. **Addresses your concern**: Master files maintain coordination
2. **Improves performance**: Smaller files = faster operations
3. **Reduces conflicts**: Agents edit different files
4. **Scales well**: Structure grows with agent count
5. **Maintains context**: Cross-references preserve dependencies

### Implementation Priority

1. **High**: Create structure and migrate (Week 1-2)
2. **Medium**: Update references and coordination (Week 2)
3. **Low**: Refine and optimize (Ongoing)

### Success Criteria

- Master files < 500 lines each
- Agent files < 500 lines each
- All dependencies tracked
- All integration points documented
- Agents can find their work quickly
- Agents can see other agents' status

---

## Alternative: Keep Current Structure

### If You Prefer Current Approach

**Benefits**:
- Single source of truth
- Easy to search
- No sync issues
- Simple structure

**Costs**:
- Large files (5,203 lines)
- Slower operations
- More conflicts
- Harder navigation

**Recommendation**: Only if file size doesn't impact performance significantly.

---

## Final Recommendation

**✅ Implement Hybrid Approach**

**Rationale**:
- Addresses coordination concerns (master files)
- Improves performance (smaller files)
- Reduces conflicts (separate files)
- Scales well (structure grows with agents)
- Maintains context (cross-references)

**Next Steps**:
1. Review this recommendation
2. Approve structure
3. Begin Phase 1 (create structure)
4. Migrate content
5. Update references

**Timeline**: 1-2 weeks for full migration

---

**Your concern about coordination is valid and important. The hybrid approach addresses this by keeping master files that show all agent status and dependencies, while still providing the performance benefits of smaller, focused files.**

