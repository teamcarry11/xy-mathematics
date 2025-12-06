# Grain Database Agent: Documentation Refactor Prompt

**Date**: 2025-12-03-165133-pst  
**Agent**: Grain Database Agent (7th Agent)  
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
│   ├── plan_aurora.md        # Aurora Agent detailed plan
│   ├── plan_skate.md         # Skate Agent detailed plan
│   ├── plan_workspace.md     # Workspace Agent detailed plan
│   ├── plan_kernel.md        # Kernel Agent detailed plan
│   └── plan_database.md     # YOUR FILE (to be created)
└── tasks/
    ├── tasks_core.md           # Grain Core Agent detailed tasks
    ├── tasks_aurora.md       # Aurora Agent detailed tasks
    ├── tasks_skate.md        # Skate Agent detailed tasks
    ├── tasks_workspace.md   # Workspace Agent detailed tasks
    ├── tasks_kernel.md      # Kernel Agent detailed tasks
    └── tasks_database.md    # YOUR FILE (to be created)
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

1. **`docs/plans/plan_database.md`** — Detailed development plan
2. **`docs/tasks/tasks_database.md`** — Detailed task list

### Reference Files

- **Example Plan**: [`docs/plans/plan_core.md`](plans/plan_core.md) — Grain Core Agent plan (448 lines)
- **Example Tasks**: [`docs/tasks/tasks_core.md`](tasks/tasks_core.md) — Grain Core Agent tasks (188 lines)
- **Master Plan**: [`docs/plan.md`](plan.md) — Master overview (236 lines)
- **Master Tasks**: [`docs/tasks.md`](tasks.md) — Master task list (195 lines)

---

## Content to Include

### 1. Plan File (`docs/plans/plan_database.md`)

**Structure**:
```markdown
# Grain Database Agent: Development Plan

**Agent**: Grain Database Agent (7th Agent)
**Status**: [Current status]
**Last Updated**: 2025-12-03-165133-pst

---

## Overview

[Brief description of Grain Database hybrid database system]

**Key Goals**:
- [Goal 1]
- [Goal 2]
- [Goal 3]

---

## Completed Phases

### Phase 1: Database Foundation ✅ **COMPLETE**
- [Description]
- [Key achievements]
- [Files created/modified]
- [Tests]

### Phase 2: Relational Layer ✅ **COMPLETE**
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

**Integration Points**:
- API Server (Phase 59) for REST API integration
- File Storage (Phase 62) for database persistence
- Network Stack (Phase 61) for network capabilities
- Authentication Service (Phase 60) for secure API access

**Coordination Notes**:
- Waiting for Grain Core Agent's API Server (Phase 59) to integrate REST API
- Database persistence depends on File Storage (Phase 62)
- Network capabilities depend on Network Stack (Phase 61)

### With Grain Mobile Agent

**Integration Points**:
- REST API for mobile backend connection
- Database backend for mobile app data storage

**Coordination Notes**:
- Mobile Agent uses Database Agent's REST API
- Database Agent provides backend for mobile applications

### With Vantage VM Basin Kernel Agent

**Integration Points**:
- Kernel file I/O for database persistence
- Network syscalls (when available) for network capabilities

**Coordination Notes**:
- Database uses kernel file I/O for storage
- Network capabilities depend on kernel network syscalls

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md)
- **Master Plan**: [`docs/plan.md`](../plan.md)
- **Grain Database Agent Prompt**: [`docs/grain_database_agent_prompt.md`](../grain_database_agent_prompt.md)
- [Other references]
```

### 2. Tasks File (`docs/tasks/tasks_database.md`)

**Structure**:
```markdown
# Grain Database Agent: Task List

**Agent**: Grain Database Agent (7th Agent)
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

### Completed: Phase 1 - Database Foundation ✅

**Date**: 2025-12-03-163155-pst

**Completed Work**:
1. **Storage Engine** (`src/grain_database/storage_engine.zig`):
   - Key-value storage engine (extends Grain Silo)
   - Index management (B-tree, hash indexes)
   - Write-ahead log (WAL) for durability
   - Transaction management (ACID guarantees)
   - Comprehensive tests (`tests/108_grain_database_storage_engine_test.zig`)

**Features**:
- Key-value storage foundation
- B-tree indexes for foreign keys
- Hash indexes for ID lookups
- Write-ahead log (WAL) for durability
- ACID transaction guarantees

**Files**:
- `src/grain_database/storage_engine.zig` — Storage engine implementation
- `src/grain_database/wal.zig` — Write-ahead log
- `src/grain_database/transaction.zig` — Transaction management
- `src/grain_database/index.zig` — Index management

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (all limits explicit)
- Assertions for preconditions
- Max 70 lines per function
- Max 100 characters per line

---

### Completed: Phase 2 - Relational Layer ✅

**Date**: 2025-12-03-164442-pst

**Completed Work**:
1. **Relational Layer** (`src/grain_database/relational.zig`):
   - Table definitions and schema management
   - Foreign key support
   - Query parser for SQL-like queries
   - Relational query execution
   - Comprehensive tests

**Features**:
- Table definitions (columns, types, constraints)
- Schema management (create, alter, drop tables)
- Foreign key relationships
- SQL-like query parser
- Relational query execution

**Files**:
- `src/grain_database/relational.zig` — Relational layer implementation
- `src/grain_database/query.zig` — Query parser and executor

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations
- Assertions for preconditions
- Max 70 lines per function
- Max 100 characters per line

---

### Completed: Phase 3 - Graph Layer ✅

**Date**: 2025-12-03-165223-pst

**Completed Work**:
1. **Graph Layer** (`src/grain_database/graph.zig`):
   - Graph data structure (nodes, edges, relationships)
   - Relationship indexes for fast traversal
   - BFS/DFS traversal algorithms
   - Reverse lookup optimization
   - Comprehensive tests

**Features**:
- Graph data structure (nodes and edges)
- Relationship indexes (for fast traversal)
- BFS (breadth-first search) traversal
- DFS (depth-first search) traversal
- Reverse lookup (find all nodes connected to a node)
- Graph query interface

**Files**:
- `src/grain_database/graph.zig` — Graph layer implementation

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations
- Assertions for preconditions
- Max 70 lines per function
- Max 100 characters per line
- Iterative algorithms only (no recursion)

---

### Completed: Phase 4 - Full-Text Search ✅

**Date**: 2025-12-03-173339-pst

**Completed Work**:
1. **Full-Text Search** (`src/grain_database/query.zig`):
   - Inverted index for full-text search
   - Tokenization (split text into tokens)
   - Stemming (reduce words to root form)
   - Search interface (query, rank, return results)
   - Comprehensive tests

**Features**:
- Inverted index (word → document IDs)
- Tokenization (split text into searchable tokens)
- Stemming (reduce words to root form for better matching)
- Search interface (query, rank results, return top N)
- Policy topic search (for election app use case)

**Files**:
- `src/grain_database/query.zig` — Full-text search implementation
- `src/grain_database/index.zig` — Inverted index management

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations
- Assertions for preconditions
- Max 70 lines per function
- Max 100 characters per line

---

### Completed: Phase 5 - API and Integration ✅

**Date**: 2025-12-03-175009-pst

**Completed Work**:
1. **REST API Layer** (`src/grain_database/api.zig`):
   - REST API router (route matching, handler dispatch)
   - JSON serialization/deserialization
   - Rate limiting (prevent abuse)
   - CORS support (cross-origin resource sharing)
   - API request/response structures
   - Middleware support (authentication, logging, etc.)
   - Comprehensive tests (`tests/109_grain_database_api_test.zig`)

**Features**:
- REST API router (HTTP method + path matching)
- JSON serialization/deserialization
- Rate limiting (requests per IP per minute)
- CORS support (allow cross-origin requests)
- API request/response structures
- Middleware support (authentication, logging, error handling)
- Integration with Grain Core Agent's API Server (Phase 59)

**Files**:
- `src/grain_database/api.zig` — REST API implementation

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations
- Assertions for preconditions
- Max 70 lines per function
- Max 100 characters per line

**Integration Status**:
- API layer complete, waiting for Grain Core Agent's API Server (Phase 59)
- Ready for integration when API Server is available

---

## Coordination with Other Agents

### With Grain Core Agent

**Integration Points**:
- **API Server (Phase 59)**: Database Agent's REST API integrates with Grain Core Agent's API Server
  - Database Agent provides API handlers
  - Grain Core Agent provides HTTP server infrastructure
  - Coordination on API contracts and middleware
- **File Storage (Phase 62)**: Database persistence depends on Grain Core Agent's file storage
  - Database files (tables, indexes, WAL)
  - Transaction log persistence
  - Backup/restore functionality
- **Network Stack (Phase 61)**: Network capabilities depend on Grain Core Agent's network stack
  - TCP/UDP support for API server
  - WebSocket support (for livestream coordination)
  - TLS support (for secure API endpoints)
- **Authentication Service (Phase 60)**: Secure API access depends on Grain Core Agent's authentication
  - JWT token validation
  - OAuth integration
  - 2FA support

**Coordination Notes**:
- Database Agent's REST API is complete, waiting for Grain Core Agent's API Server (Phase 59)
- Database persistence depends on File Storage (Phase 62)
- Network capabilities depend on Network Stack (Phase 61)
- Secure API access depends on Authentication Service (Phase 60)

**Recent Coordination**:
- Database Agent completed Phase 5 (API and Integration) and is ready for integration
- Waiting for Grain Core Agent to complete Phase 59 (HTTP/REST API Server)

**Future Coordination**:
- **API Integration**: When Grain Core Agent completes Phase 59, integrate Database Agent's REST API
- **File Storage**: When Grain Core Agent completes Phase 62, integrate database persistence
- **Network Stack**: When Grain Core Agent completes Phase 61, integrate network capabilities
- **Authentication**: When Grain Core Agent completes Phase 60, integrate secure API access

### With Grain Mobile Agent

**Integration Points**:
- **REST API**: Mobile Agent uses Database Agent's REST API for backend connection
  - Mobile app connects to Database Agent's REST API
  - Database Agent provides data storage and retrieval
  - Mobile Agent provides mobile app UI and business logic
- **Database Backend**: Database Agent provides backend for mobile applications
  - User profiles, policy stances, candidate information
  - Social graph (relationships, connections)
  - Full-text search (policy topic search, candidate search)

**Coordination Notes**:
- Mobile Agent depends on Database Agent's REST API
- Database Agent provides backend for mobile applications
- Both agents depend on Grain Core Agent's API Server (Phase 59)

**Future Coordination**:
- **API Integration**: When Grain Core Agent completes Phase 59, Mobile Agent can connect to Database Agent's REST API
- **Data Models**: Coordinate on data models for mobile app (user profiles, policy stances, etc.)
- **Authentication**: Coordinate on authentication flow (JWT, OAuth, 2FA)

### With Vantage VM Basin Kernel Agent

**Integration Points**:
- **Kernel File I/O**: Database uses kernel file I/O for persistence
  - Database files (tables, indexes, WAL)
  - Transaction log persistence
  - File operations (open, read, write, close)
- **Network Syscalls**: Network capabilities depend on kernel network syscalls (when available)
  - TCP/UDP syscalls
  - Network connection management
  - DNS resolution

**Coordination Notes**:
- Database uses kernel file I/O for storage
- Network capabilities depend on kernel network syscalls (not yet implemented)
- No direct coordination needed — Grain Core Agent handles kernel integration

---

## What to Extract from Old Files

### From `archaeology/docs/plan_tasks_archive/plan_2025-12-03-165133-pst.md`:

Search for sections related to:
- "Grain Database", "Database Agent", "Phase 1", "Phase 2", "Phase 3", "Phase 4", "Phase 5"
- "storage_engine", "relational", "graph", "full-text", "API"
- Your agent's work

Extract:
- Completed phases
- Current work
- Planned phases
- Coordination notes

### From `archaeology/docs/plan_tasks_archive/tasks_2025-12-03-165133-pst.md`:

Search for:
- Grain Database tasks
- Phase 1-5 tasks
- Database-specific tasks

Extract:
- Task lists for each phase
- Completed tasks
- Pending tasks
- Coordination tasks

---

## Key Phases to Document

### Completed Phases

**Phase 1: Database Foundation** ✅ (2025-12-03-163155-pst)
- Storage engine (key-value foundation)
- Index management (B-tree, hash indexes)
- Write-ahead log (WAL) for durability
- Transaction management (ACID guarantees)
- Files: `src/grain_database/storage_engine.zig`, `src/grain_database/wal.zig`, `src/grain_database/transaction.zig`, `src/grain_database/index.zig`

**Phase 2: Relational Layer** ✅ (2025-12-03-164442-pst)
- Table definitions and schema management
- Foreign key support
- SQL-like query parser
- Relational query execution
- Files: `src/grain_database/relational.zig`, `src/grain_database/query.zig`

**Phase 3: Graph Layer** ✅ (2025-12-03-165223-pst)
- Graph data structure (nodes, edges, relationships)
- Relationship indexes for fast traversal
- BFS/DFS traversal algorithms
- Reverse lookup optimization
- Files: `src/grain_database/graph.zig`

**Phase 4: Full-Text Search** ✅ (2025-12-03-173339-pst)
- Inverted index for full-text search
- Tokenization and stemming
- Search interface (query, rank, return results)
- Policy topic search support
- Files: `src/grain_database/query.zig`, `src/grain_database/index.zig`

**Phase 5: API and Integration** ✅ (2025-12-03-175009-pst)
- REST API router (route matching, handler dispatch)
- JSON serialization/deserialization
- Rate limiting and CORS support
- API request/response structures
- Middleware support
- Files: `src/grain_database/api.zig`, `tests/109_grain_database_api_test.zig`

### Planned Phases

**Phase 6: Integration with Grain Core Agent API Server** (PLANNED)
- Integrate Database Agent's REST API with Grain Core Agent's API Server (Phase 59)
- API endpoint registration
- Middleware integration (authentication, logging)
- API testing and validation

**Phase 7: Database Persistence** (PLANNED)
- Integrate with Grain Core Agent's File Storage (Phase 62)
- Database file persistence
- Transaction log persistence
- Backup/restore functionality

**Phase 8: Network Integration** (PLANNED)
- Integrate with Grain Core Agent's Network Stack (Phase 61)
- TCP/UDP support for API server
- WebSocket support (for livestream coordination)
- TLS support (for secure API endpoints)

**Phase 9: Authentication Integration** (PLANNED)
- Integrate with Grain Core Agent's Authentication Service (Phase 60)
- JWT token validation
- OAuth integration
- 2FA support

**Phase 10: AArch64 Cloud Deployment** (PLANNED)
- AArch64 target support (for cloud hardware)
- Containerized deployment
- Horizontal scaling capability
- Integration with Vantage VM Basin Kernel

---

## Guidelines

### File Size Target

- **Plan file**: ~400-600 lines (detailed but manageable, many phases)
- **Tasks file**: ~300-500 lines (detailed but manageable, many tasks)
- **Master files**: Will be updated by you after creating agent files

### Content Guidelines

1. **Be Detailed**: Include implementation details, file paths, test names
2. **Be Specific**: Include phase numbers, dates, status
3. **Be Coordinated**: Include dependencies and coordination points
4. **Be Current**: Include recent work (all 5 completed phases)

### Cross-References

- Link to master files: `[Master Plan](../plan.md)`
- Link to other agent files: `[Grain OS Plan](../plans/plan_core.md)`
- Link to shared docs: `[Grain Style](../grain_style.md)`
- Link to agent prompt: `[Grain Database Agent Prompt](../grain_database_agent_prompt.md)`

---

## Steps to Complete

1. **Read Reference Files**:
   - Read `docs/plans/plan_core.md` to understand structure
   - Read `docs/tasks/tasks_core.md` to understand task format
   - Read `docs/documentation_structure_recommendation.md` for rationale
   - Read `docs/grain_database_agent_prompt.md` for database details

2. **Extract Your Content**:
   - Search old plan file for Grain Database sections
   - Search old tasks file for Grain Database tasks
   - Include recent work (all 5 completed phases)

3. **Create Plan File**:
   - Create `docs/plans/plan_database.md`
   - Follow structure from `plan_core.md`
   - Include completed phases (1-5), current work, planned phases (6-10)
   - Include coordination points (especially with Grain Core Agent and Mobile Agent)

4. **Create Tasks File**:
   - Create `docs/tasks/tasks_database.md`
   - Follow structure from `tasks_core.md`
   - Include task lists for each phase
   - Include coordination tasks

5. **Update Master Files**:
   - Update `docs/plan.md` with Database Agent summary (if not already there)
   - Update `docs/tasks.md` with Database Agent summary (if not already there)
   - Keep summaries concise (1-2 paragraphs)

6. **Verify**:
   - Check file sizes (plan: ~400-600 lines, tasks: ~300-500 lines)
   - Check cross-references work
   - Check coordination points are documented

---

## Example Master File Entry

After creating your files, the master `docs/plan.md` should have an entry like:

```markdown
### 7. Grain Database Agent

**Status**: Active — Database system  
**Current Work**: Integration with Grain Core Agent API Server (Phase 59)  
**Details**: See [`docs/plans/plan_database.md`](plans/plan_database.md)

**Recent Progress**:
- Phase 1: Database Foundation ✅ (2025-12-03-163155-pst)
- Phase 2: Relational Layer ✅ (2025-12-03-164442-pst)
- Phase 3: Graph Layer ✅ (2025-12-03-165223-pst)
- Phase 4: Full-Text Search ✅ (2025-12-03-173339-pst)
- Phase 5: API and Integration ✅ (2025-12-03-175009-pst)

**Provides**: Database backend (for Mobile Agent), REST API (via Grain Core Agent)
```

---

## Questions to Answer

1. **What phases have you completed?**
   - Phase 1: Database Foundation ✅ (2025-12-03-163155-pst)
   - Phase 2: Relational Layer ✅ (2025-12-03-164442-pst)
   - Phase 3: Graph Layer ✅ (2025-12-03-165223-pst)
   - Phase 4: Full-Text Search ✅ (2025-12-03-173339-pst)
   - Phase 5: API and Integration ✅ (2025-12-03-175009-pst)
   - List all completed phases with dates and achievements

2. **What is your current work?**
   - Current phase, status, priority, estimated time
   - Waiting for Grain Core Agent's API Server (Phase 59) for integration

3. **What phases are planned?**
   - Phase 6: Integration with Grain Core Agent API Server (PLANNED)
   - Phase 7: Database Persistence (PLANNED)
   - Phase 8: Network Integration (PLANNED)
   - Phase 9: Authentication Integration (PLANNED)
   - Phase 10: AArch64 Cloud Deployment (PLANNED)

4. **What do you coordinate with other agents?**
   - Grain Core Agent (API Server, File Storage, Network Stack, Authentication Service)
   - Grain Mobile Agent (REST API, database backend)
   - Kernel Agent (file I/O, network syscalls)

5. **What dependencies do you have?**
   - What you need from other agents (API Server, File Storage, Network Stack, Authentication Service)
   - What you provide to other agents (database backend, REST API)

---

## Success Criteria

✅ Plan file created (`docs/plans/plan_database.md`)  
✅ Tasks file created (`docs/tasks/tasks_database.md`)  
✅ Files follow structure from reference files  
✅ Recent work (all 5 completed phases) included  
✅ Coordination points documented (especially with Grain Core Agent and Mobile Agent)  
✅ Master files updated (if needed)  
✅ File sizes reasonable (~400-600 lines for plan, ~300-500 for tasks)  
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
- **Grain Database Agent Prompt**: [`docs/grain_database_agent_prompt.md`](grain_database_agent_prompt.md) — Agent prompt and architecture
- **Archived Files**: `archaeology/docs/plan_tasks_archive/` — Previous versions

---

**Your Mission**: Create `docs/plans/plan_database.md` and `docs/tasks/tasks_database.md` following the hybrid documentation structure, including your recent work (all 5 completed phases) and coordination points with Grain Core Agent, Mobile Agent, and Kernel Agent.

**Remember**: Be detailed, be specific, be coordinated. The goal is to have focused agent files while maintaining coordination through master files. Your database is the backend foundation for mobile applications and the Grain OS ecosystem!

Good luck! 🚀

