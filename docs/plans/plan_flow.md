# Grain Flow Agent: Development Plan

**Agent**: Grain Flow Agent (9th Agent)  
**Status**: Phase 1 Event Bus Foundation COMPLETE ✅, Phase 2 Agent Coordinator COMPLETE ✅  
**Last Updated**: 2025-12-07-071000-pst

---

## Overview

Grain Flow Agent is responsible for workflow orchestration, agent coordination, and automation flows in the Grain OS ecosystem. Flow Agent integrates seamlessly with Grain Core orchestration, providing the orchestration layer that coordinates multiple agents using Core's system services.

**Key Goals**:
- Workflow orchestration engine (DAG-based workflows)
- Agent coordination (event-driven communication)
- Event bus (centralized event routing)
- Workflow automation (agent-to-agent workflows, scheduled tasks)
- Workflow visualization (for debugging and design)

**Integration**: Flows in with Grain Core orchestration — Core provides infrastructure; Flow provides orchestration.

---

## Architecture Integration

### Dependency Chain

```
Basin Kernel (RISC-V64) [Layer 2: Foundation]
    ↓ (provides syscalls)
Core Agent (System Services) [Layer 3: System Services]
    ↓ (provides services)
Flow Agent (Workflow Orchestration) [Layer 4: Orchestration]
    ↓ (coordinates)
    ├─→ Silo Agent (Database)
    ├─→ Carry Agent (Mobile)
    ├─→ Workspace Agent (Desktop Apps)
    ├─→ Bubble Agent (Design Tool)
    ├─→ Aurora Agent (IDE/Browser)
    ├─→ Skate Agent (Knowledge Graph)
    └─→ Vantage Agent (VM/Kernel)
```

**Key Points**:
- **Flow depends on Core** (uses Core's API Server, WebSocket, Auth)
- **Flow coordinates other agents** (provides workflow orchestration)
- **Flow can work in parallel with** most agents (except when coordinating)

### Dependency Matrix

| Agent | Depends On | Provides To | Can Work In Parallel With |
|-------|------------|-------------|--------------------------|
| **Flow** | **Core** (API ✅, WebSocket ✅, Auth ✅), **Basin** (via Core) | All agents (orchestration) | Aurora, Skate, Workspace, Bubble (when not coordinating) |

---

## Implementation Phases

### Phase 1: Event Bus Foundation (Priority: HIGHEST)

**Goal**: Centralized event routing for agent communication

**Status**: **COMPLETE** ✅ (2025-12-07-054000-pst)  
**Estimated Time**: 2-3 weeks

**Features**:
- Event type definitions (enum-based)
- Event publishing API
- Event subscription API
- Event routing engine (iterative matching)
- Bounded event queue
- Event filtering (by type, source, destination)

**Dependencies**:
- Core Agent: WebSocket support ✅
- Core Agent: API Server ✅

**Location**: `src/grain_flow/event_bus.zig`

**Tests**: `tests/134_grain_flow_event_bus_test.zig`

**Completed Components**:
- ✅ Event type definitions (enum-based, 13 event types)
- ✅ Event structure (type, source, destination, payload, timestamp)
- ✅ Event publishing API (`publish_event()`, `publish_event_with_payload()`)
- ✅ Event subscription API (`subscribe()`, `unsubscribe()`)
- ✅ Event routing engine (iterative matching, no recursion)
- ✅ Bounded event queue (MAX_EVENTS: u32 = 10000)
- ✅ Bounded subscribers per event type (MAX_SUBSCRIBERS: u32 = 256)
- ✅ Event filtering (by type, source, destination)
- ✅ Event processing (iterative, no recursion)
- ✅ Comprehensive tests (11 test cases)

**GrainStyle Requirements**:
- Bounded event queue (MAX_EVENTS: u32 = 10000)
- Bounded subscribers per event type (MAX_SUBSCRIBERS: u32 = 256)
- Explicit event types (enum, not string matching)
- Iterative event processing (no recursion)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line

---

### Phase 2: Agent Coordinator (Priority: HIGH)

**Goal**: Agent registry and coordination

**Status**: **COMPLETE** ✅ (2025-12-07-071000-pst)  
**Estimated Time**: 2-3 weeks

**Features**:
- Agent registry (track active agents)
- Agent health monitoring
- Agent capability discovery
- Agent-to-agent RPC (via Core API)
- Agent status tracking

**Dependencies**:
- Phase 1: Event Bus ✅
- Core Agent: API Server ✅
- Core Agent: Authentication ✅

**Location**: `src/grain_flow/agent_coordinator.zig`

**Tests**: `tests/135_grain_flow_agent_coordinator_test.zig`

**Completed Components**:
- ✅ Agent registry (track active agents, MAX_AGENTS: u32 = 64)
- ✅ Agent ID management (explicit u32 IDs, not strings)
- ✅ Agent health monitoring (status tracking, health check events)
- ✅ Agent capability discovery (capability registration, search by capability)
- ✅ Agent-to-agent RPC (RPC request queue, MAX_RPC_REQUESTS: u32 = 1000)
- ✅ Agent status tracking (active, inactive, unhealthy, unknown)
- ✅ Iterative coordination algorithms (no recursion)
- ✅ Event bus integration (agent_started, agent_stopped, agent_health_check events)
- ✅ Comprehensive tests (11 test cases)

**GrainStyle Requirements**:
- Bounded agent registry (MAX_AGENTS: u32 = 64)
- Explicit agent IDs (u32, not strings)
- Bounded RPC queue (MAX_RPC_REQUESTS: u32 = 1000)
- Iterative coordination algorithms
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line

---

### Phase 3: Workflow Engine (Priority: HIGH)

**Goal**: DAG-based workflow execution

**Status**: **PLANNED** — Waiting for Phase 2  
**Estimated Time**: 3-4 weeks

**Features**:
- Workflow DAG definition (nodes, edges)
- Workflow execution engine (iterative)
- State management (workflow state)
- Error handling and recovery
- Workflow scheduling

**Dependencies**:
- Phase 1: Event Bus ✅
- Phase 2: Agent Coordinator ✅

**Location**: `src/grain_flow/workflow_engine.zig`

**Tests**: `tests/134_grain_flow_workflow_engine_test.zig`

**GrainStyle Requirements**:
- Bounded workflow depth (MAX_WORKFLOW_DEPTH: u32 = 1000)
- Bounded workflow nodes (MAX_WORKFLOW_NODES: u32 = 10000)
- Bounded workflow edges (MAX_WORKFLOW_EDGES: u32 = 100000)
- Iterative execution (no recursion)
- Explicit state management
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line

---

### Phase 4: Workflow Visualizer (Priority: MEDIUM)

**Goal**: Visual workflow representation

**Status**: **PLANNED** — Waiting for Phase 3  
**Estimated Time**: 2-3 weeks

**Features**:
- Workflow DAG rendering
- Node/edge visualization
- State visualization
- Export to PDF/HTML (via Bubble Agent export)

**Dependencies**:
- Phase 3: Workflow Engine ✅
- Bubble Agent: Export pipeline ✅

**Location**: `src/grain_flow/workflow_visualizer.zig`

**Tests**: `tests/135_grain_flow_workflow_visualizer_test.zig`

**Integration**: Uses Grain Bubble for visual rendering

---

## Integration Points

### With Core Agent

**Uses**:
- API Server (for agent RPC)
- WebSocket (for real-time event delivery)
- Authentication (for agent identity)
- Network Stack (for agent communication)

**Provides**:
- Workflow orchestration services
- Event bus services
- Agent coordination services

**Coordination**:
- Check in before modifying Core API contracts
- Coordinate on WebSocket event delivery
- Coordinate on authentication integration

### With Other Agents

**Coordinates**:
- All agents (via event bus and workflows)
- Silo Agent (database workflows)
- Carry Agent (mobile workflows)
- Workspace Agent (desktop app workflows)
- Bubble Agent (design workflows)
- Aurora Agent (IDE workflows)
- Skate Agent (knowledge graph workflows)

**Pattern**:
- Agents publish events to Flow's event bus
- Flow routes events to subscribed agents
- Flow executes workflows that coordinate multiple agents
- Agents can query Flow for workflow status

---

## Example Workflow

### Multi-Agent Workflow: Database Backup

```
Workflow: "Database Backup"
Nodes:
  1. Silo Agent: Create backup snapshot
  2. Core Agent: Store backup file
  3. Silo Agent: Verify backup integrity
  4. Core Agent: Update backup metadata

Edges:
  1 → 2 (backup data flows to Core)
  2 → 3 (file stored, verify)
  3 → 4 (verified, update metadata)

Execution:
  - Flow coordinates agents via event bus
  - Each node publishes completion event
  - Flow routes events to next node
  - Error handling: if any node fails, workflow stops
```

---

## Directory Structure

```
src/grain_flow/
├── root.zig              # Module exports
├── event_bus.zig         # Event routing engine
├── agent_coordinator.zig # Agent registry and coordination
├── workflow_engine.zig   # Workflow execution engine
└── workflow_visualizer.zig # Visual workflow representation

tests/
├── 132_grain_flow_event_bus_test.zig
├── 133_grain_flow_agent_coordinator_test.zig
├── 134_grain_flow_workflow_engine_test.zig
└── 135_grain_flow_workflow_visualizer_test.zig

docs/
├── plans/plan_flow.md
└── tasks/tasks_flow.md
```

---

## Success Metrics

### Code Quality
- ✅ Zero compiler warnings
- ✅ All tests pass (`zig build test`)
- ✅ Grain Style compliance (`grainwrap-100`, `grain validate-70`)
- ✅ Bounded allocations with explicit limits
- ✅ Minimum 2 assertions per function
- ✅ **NO `usize`/`isize` usage** (use `u32`/`u64`/`i32`/`i64`)

### Coordination
- ✅ No merge conflicts
- ✅ API contracts maintained
- ✅ Shared modules coordinated
- ✅ Documentation updated

### Performance
- ✅ Bounded memory usage
- ✅ Efficient event routing
- ✅ Deterministic workflow execution
- ✅ Zero-copy where possible

---

## Next Steps

1. **Start with Phase 1**: Event Bus Foundation
2. **Coordinate with Core Agent**: Ensure API Server and WebSocket integration
3. **Build incrementally**: Each phase enables the next
4. **Test thoroughly**: All workflows must be deterministic
5. **Document workflows**: Update plan and tasks docs

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md) — Coding principles and guidelines
- **Core Plan**: [`docs/plan.md`](../plan.md) — Core overview
- **Grain Flow Agent Prompt**: [`docs/grain_flow_agent_prompt.md`](../grain_flow_agent_prompt.md) — Agent prompt and architecture
- **Core Coordination Plan**: [`docs/agent-communications/core_agent_coordination_plan_2025-12-06-061647-pst.md`](../agent-communications/core_agent_coordination_plan_2025-12-06-061647-pst.md) — Agent coordination strategy

---

**Status**: Phase 1 Complete, Ready for Phase 2  
**First Phase**: Event Bus Foundation ✅ COMPLETE  
**Next Phase**: Agent Coordinator  
**Estimated Time**: 2-3 weeks per phase  
**Integration**: Flows seamlessly with Grain Core orchestration

---

**End of Plan**
