# Grain Flow Agent: Task List

**Agent**: Grain Flow Agent (9th Agent)  
**Status**: Phase 1 Event Bus Foundation COMPLETE ✅  
**Last Updated**: 2025-12-07-054000-pst

---

## Completed: Phase 1 - Event Bus Foundation ✅

**Priority**: **HIGHEST** — Foundation for all workflow orchestration  
**Status**: **COMPLETE** ✅ (2025-12-07-054000-pst)  
**Estimated Time**: 2-3 weeks

### Completed Tasks

- [x] Create `src/grain_flow/` directory structure
- [x] Create `src/grain_flow/root.zig` module root
- [x] Create `src/grain_flow/event_bus.zig` module structure
- [x] Implement event type definitions (enum-based, 13 event types)
- [x] Implement event structure (type, source, destination, payload)
- [x] Implement event publishing API (`publish_event()`, `publish_event_with_payload()`)
- [x] Implement event subscription API (`subscribe()`, `unsubscribe()`)
- [x] Implement event routing engine (iterative matching)
- [x] Implement bounded event queue (MAX_EVENTS: u32 = 10000)
- [x] Implement bounded subscribers per event type (MAX_SUBSCRIBERS: u32 = 256)
- [x] Implement event filtering (by type, source, destination)
- [x] Implement event processing (iterative, no recursion)
- [x] Create comprehensive tests (`tests/134_grain_flow_event_bus_test.zig` - 11 test cases)
- [x] Update `build.zig` with new module and tests
- [x] Update `docs/plans/plan_flow.md` and `docs/tasks/tasks_flow.md` with progress

### Grain Style Requirements

- All functions use `grain_case` naming
- Bounded allocations: `MAX_EVENTS`, `MAX_SUBSCRIBERS`
- Explicit event types (enum, not string matching)
- Iterative event processing (no recursion)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled
- **NO `usize`/`isize` usage** (use `u32`/`u64`/`i32`/`i64`)

### Dependencies

- **Needs**: Core Agent WebSocket support ✅, Core Agent API Server ✅
- **Provides**: Event bus for agent communication
- **Coordinates with**: Core Agent (WebSocket integration)

---

## Planned: Phase 2 - Agent Coordinator

**Priority**: **HIGH** — Agent registry and coordination  
**Status**: **PLANNED** — Waiting for Phase 1  
**Estimated Time**: 2-3 weeks

### Tasks

- [ ] Create `src/grain_flow/agent_coordinator.zig` module structure
- [ ] Implement agent registry (track active agents, MAX_AGENTS: u32 = 64)
- [ ] Implement agent ID management (explicit u32 IDs, not strings)
- [ ] Implement agent health monitoring
- [ ] Implement agent capability discovery
- [ ] Implement agent-to-agent RPC (via Core API Server)
- [ ] Implement bounded RPC queue (MAX_RPC_REQUESTS: u32 = 1000)
- [ ] Implement agent status tracking
- [ ] Implement iterative coordination algorithms (no recursion)
- [ ] Create comprehensive tests (`tests/133_grain_flow_agent_coordinator_test.zig`)
- [ ] Update `build.zig` with new module and tests
- [ ] Update `docs/plans/plan_flow.md` and `docs/tasks/tasks_flow.md` with progress

### Grain Style Requirements

- All functions use `grain_case` naming
- Bounded allocations: `MAX_AGENTS`, `MAX_RPC_REQUESTS`
- Explicit agent IDs (u32, not strings)
- Iterative coordination algorithms (no recursion)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled
- **NO `usize`/`isize` usage** (use `u32`/`u64`/`i32`/`i64`)

### Dependencies

- **Needs**: Phase 1 Event Bus ✅, Core Agent API Server ✅, Core Agent Authentication ✅
- **Provides**: Agent coordination services
- **Coordinates with**: Core Agent (API contracts), All agents (coordination)

---

## Planned: Phase 3 - Workflow Engine

**Priority**: **HIGH** — DAG-based workflow execution  
**Status**: **PLANNED** — Waiting for Phase 2  
**Estimated Time**: 3-4 weeks

### Tasks

- [ ] Create `src/grain_flow/workflow_engine.zig` module structure
- [ ] Implement workflow DAG definition (nodes, edges)
- [ ] Implement bounded workflow depth (MAX_WORKFLOW_DEPTH: u32 = 1000)
- [ ] Implement bounded workflow nodes (MAX_WORKFLOW_NODES: u32 = 10000)
- [ ] Implement bounded workflow edges (MAX_WORKFLOW_EDGES: u32 = 100000)
- [ ] Implement workflow execution engine (iterative, no recursion)
- [ ] Implement state management (workflow state, agent state)
- [ ] Implement error handling and recovery
- [ ] Implement workflow scheduling
- [ ] Create comprehensive tests (`tests/134_grain_flow_workflow_engine_test.zig`)
- [ ] Update `build.zig` with new module and tests
- [ ] Update `docs/plans/plan_flow.md` and `docs/tasks/tasks_flow.md` with progress

### Grain Style Requirements

- All functions use `grain_case` naming
- Bounded allocations: `MAX_WORKFLOW_DEPTH`, `MAX_WORKFLOW_NODES`, `MAX_WORKFLOW_EDGES`
- Iterative execution (no recursion)
- Explicit state management
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled
- **NO `usize`/`isize` usage** (use `u32`/`u64`/`i32`/`i64`)

### Dependencies

- **Needs**: Phase 1 Event Bus ✅, Phase 2 Agent Coordinator ✅
- **Provides**: Workflow orchestration services
- **Coordinates with**: All agents (workflow execution)

---

## Planned: Phase 4 - Workflow Visualizer

**Priority**: **MEDIUM** — Visual workflow representation  
**Status**: **PLANNED** — Waiting for Phase 3  
**Estimated Time**: 2-3 weeks

### Tasks

- [ ] Create `src/grain_flow/workflow_visualizer.zig` module structure
- [ ] Implement workflow DAG rendering
- [ ] Implement node visualization (agents, tasks, conditions)
- [ ] Implement edge visualization (dependencies, data flow)
- [ ] Implement state visualization (current execution state)
- [ ] Integrate with Bubble Agent export pipeline (PDF/HTML export)
- [ ] Create comprehensive tests (`tests/135_grain_flow_workflow_visualizer_test.zig`)
- [ ] Update `build.zig` with new module and tests
- [ ] Update `docs/plans/plan_flow.md` and `docs/tasks/tasks_flow.md` with progress

### Grain Style Requirements

- All functions use `grain_case` naming
- Bounded allocations (all limits explicit)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled
- **NO `usize`/`isize` usage** (use `u32`/`u64`/`i32`/`i64`)

### Dependencies

- **Needs**: Phase 3 Workflow Engine ✅, Bubble Agent Export pipeline ✅
- **Provides**: Workflow visualization services
- **Coordinates with**: Bubble Agent (export integration)

---

## Coordination Tasks

### With Core Agent

**Pending Coordination**:
- [ ] **API Contracts**: Coordinate on agent RPC API when implementing Phase 2
- [ ] **WebSocket Integration**: Coordinate on event delivery when implementing Phase 1
- [ ] **Authentication**: Coordinate on agent identity when implementing Phase 2

**Integration Points**:
- API Server (Phase 59) for agent RPC
- WebSocket (Phase 61) for real-time event delivery
- Authentication (Phase 60) for agent identity
- Network Stack (Phase 61) for agent communication

### With Other Agents

**Pending Coordination**:
- [ ] **Event Bus Integration**: Coordinate with all agents on event publishing/subscription
- [ ] **Workflow Execution**: Coordinate with agents on workflow node execution
- [ ] **Visualization**: Coordinate with Bubble Agent on export integration

**Integration Points**:
- Event bus for agent-to-agent communication
- Workflow engine for multi-agent workflows
- Agent coordinator for agent registry and health monitoring

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md) — Coding principles and guidelines
- **Core Plan**: [`docs/plan.md`](../plan.md) — Core overview
- **Core Tasks**: [`docs/tasks.md`](../tasks.md) — Core task list
- **Grain Flow Agent Prompt**: [`docs/grain_flow_agent_prompt.md`](../grain_flow_agent_prompt.md) — Agent prompt and architecture
- **Grain Flow Agent Plan**: [`docs/plans/plan_flow.md`](../plans/plan_flow.md) — Flow Agent plan
- **Core Coordination Plan**: [`docs/agent-communications/core_agent_coordination_plan_2025-12-06-061647-pst.md`](../agent-communications/core_agent_coordination_plan_2025-12-06-061647-pst.md) — Agent coordination strategy

---

**Last Updated**: 2025-12-07-040000-pst  
**Next Review**: When Phase 1 implementation begins

---

**End of Tasks**
