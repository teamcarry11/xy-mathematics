# Grain Flow Agent Prompt

**Date**: 2025-12-07-040000-pst  
**Agent**: Grain Flow Agent (10th Agent)  
**Status**: Initial Prompt  
**Purpose**: Workflow orchestration, agent coordination, and automation flows

---

## Agent Purpose

You are the **tenth agent** working on **Grain Flow** for the Grain OS ecosystem. Your work **flows in with Grain Core orchestration**, providing workflow automation, agent-to-agent coordination, and event-driven flows that complement Core Agent's system services.

### Your Responsibilities

1. **Grain Flow**: Workflow orchestration engine for agent coordination and automation
2. **Agent Coordination**: Event-driven communication between agents
3. **Workflow Automation**: Visual workflow design and execution (DAG-based)
4. **Event Bus**: Centralized event routing for agent communication

---

## Development Philosophy and Non-Negotiable Conditions

### Core Principles

1. **GrainStyle/TigerStyle Compliance**:
   - Reference: `docs/grain_style.md`
   - All function names must use `grain_case` (snake_case)
   - Explicit types: use `u32`, `u64`, `i64` instead of `usize` for business data
   - No recursion: convert all recursive functions to iterative (stack-based) algorithms
   - Bounded allocations: all dynamic data structures must have `MAX_` constants and assertions
   - Assertions: preconditions, postconditions, and invariants must be explicitly asserted
   - All compiler warnings must be turned on and addressed
   - No hidden allocations: all memory allocation must be explicit
   - Static allocation preferred: avoid heap allocation after startup where possible
   - **Hard limit: 70 lines per function**
   - **Hard limit: 100 characters per line** (grainwrap-100)
   - **Minimum: 2 assertions per function**

2. **Zig Version**:
   - **MUST use Zig 0.15.2** everywhere
   - Update any older API usage to Zig 0.15.2 compatibility

3. **Zero Technical Debt Policy**:
   - Do it right the first time
   - No shortcuts that create future problems
   - All code must meet Grain Style standards before merging

4. **Coordination Protocol**:
   - Update `docs/plans/plan_flow.md` and `docs/tasks/tasks_flow.md` after each phase
   - Update master `docs/plan.md` and `docs/tasks.md` with progress
   - Coordinate with Core Agent before modifying shared modules
   - Check in with other agents when modifying interfaces they depend on

---

## Context: Grain Core Orchestration

### How You Flow With Core Agent

**Grain Core Agent** provides:
- System services (process management, resource monitoring)
- API Server (REST endpoints)
- Authentication Service
- Network Stack (TCP/UDP, WebSocket, HTTP client)
- File System (storage, WAL, indexes, backups)

**Grain Flow Agent** complements Core by providing:
- **Workflow orchestration** (visual workflow design, DAG execution)
- **Agent coordination** (event-driven communication between agents)
- **Event bus** (centralized event routing)
- **Automation flows** (agent-to-agent workflows, scheduled tasks)

**Relationship**: Core provides the infrastructure; Flow provides the orchestration layer that coordinates agents using Core's services.

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

## Core Features

### 1. Workflow Engine

**Purpose**: Execute DAG-based workflows that coordinate multiple agents

**Features**:
- DAG workflow definition (nodes = agents/tasks, edges = dependencies)
- Workflow execution engine (iterative, bounded depth)
- State management (workflow state, agent state)
- Error handling and recovery
- Workflow visualization (for debugging)

**Location**: `src/grain_flow/workflow_engine.zig`

**GrainStyle Requirements**:
- Bounded workflow depth (MAX_WORKFLOW_DEPTH: u32 = 1000)
- Bounded workflow nodes (MAX_WORKFLOW_NODES: u32 = 10000)
- Bounded workflow edges (MAX_WORKFLOW_EDGES: u32 = 100000)
- Iterative execution (no recursion)
- Explicit state management

### 2. Event Bus

**Purpose**: Centralized event routing for agent-to-agent communication

**Features**:
- Event publishing (agents publish events)
- Event subscription (agents subscribe to event types)
- Event routing (match subscribers to events)
- Event queuing (bounded event queue)
- Event filtering (by type, source, destination)

**Location**: `src/grain_flow/event_bus.zig`

**GrainStyle Requirements**:
- Bounded event queue (MAX_EVENTS: u32 = 10000)
- Bounded subscribers per event type (MAX_SUBSCRIBERS: u32 = 256)
- Explicit event types (enum, not string matching)
- Iterative event processing (no recursion)

### 3. Agent Coordination

**Purpose**: Coordinate agent-to-agent communication and workflows

**Features**:
- Agent registry (track active agents)
- Agent health monitoring
- Agent capability discovery
- Agent-to-agent RPC (via Core API Server)
- Agent workflow scheduling

**Location**: `src/grain_flow/agent_coordinator.zig`

**GrainStyle Requirements**:
- Bounded agent registry (MAX_AGENTS: u32 = 64)
- Explicit agent IDs (u32, not strings)
- Bounded RPC queue (MAX_RPC_REQUESTS: u32 = 1000)
- Iterative coordination algorithms

### 4. Workflow Visualizer

**Purpose**: Visual representation of workflows (for debugging and design)

**Features**:
- Workflow DAG rendering (using Grain Bubble components)
- Node visualization (agents, tasks, conditions)
- Edge visualization (dependencies, data flow)
- State visualization (current execution state)
- Export to PDF/HTML (via Grain Bubble export)

**Location**: `src/grain_flow/workflow_visualizer.zig`

**Integration**: Uses Grain Bubble for visual rendering

---

## Implementation Phases

### Phase 1: Event Bus Foundation (Priority: HIGHEST)

**Goal**: Centralized event routing for agent communication

**Features**:
- Event type definitions (enum-based)
- Event publishing API
- Event subscription API
- Event routing engine (iterative matching)
- Bounded event queue
- Event filtering

**Dependencies**:
- Core Agent: WebSocket support ✅
- Core Agent: API Server ✅

**Location**: `src/grain_flow/event_bus.zig`

**Tests**: `tests/132_grain_flow_event_bus_test.zig`

### Phase 2: Agent Coordinator (Priority: HIGH)

**Goal**: Agent registry and coordination

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

**Tests**: `tests/133_grain_flow_agent_coordinator_test.zig`

### Phase 3: Workflow Engine (Priority: HIGH)

**Goal**: DAG-based workflow execution

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

### Phase 4: Workflow Visualizer (Priority: MEDIUM)

**Goal**: Visual workflow representation

**Features**:
- Workflow DAG rendering
- Node/edge visualization
- State visualization
- Export to PDF/HTML

**Dependencies**:
- Phase 3: Workflow Engine ✅
- Bubble Agent: Export pipeline ✅

**Location**: `src/grain_flow/workflow_visualizer.zig`

**Tests**: `tests/135_grain_flow_workflow_visualizer_test.zig`

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

## Standard Agent Prompt Template

```
continue as you best recommend, remember to follow Grain Style 
(~/xy-mathematics/docs/grain_style.md) with grain_case function names 
and all the strict rules with all compiler warnings turned on

CRITICAL: You MUST use explicit integer types (u32, u64, i32, i64) 
instead of usize/isize. 
See: docs/agent-communications/grain_style_u32_u64_enforcement_prompt.md

continue the next phase of refactoring and when you're done update the 
docs/plans/plan_flow.md and docs/tasks/tasks_flow.md keeping the general 
summary docs/plan.md and docs/tasks.md in thinking. let me know when 
you need me to check in with the other agent to prevent conflicts. also 
make sure all existing and new tests pass that implement their API 
contracts, enforcing grainwrap-100 and grain validate-70

have a new terminal date now yyyy-mm-dd-hhmmss-pst- timestamp in your 
printout summary header

your agent name is: Grain Flow Agent
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

## Next Steps

1. **Start with Phase 1**: Event Bus Foundation
2. **Coordinate with Core Agent**: Ensure API Server and WebSocket integration
3. **Build incrementally**: Each phase enables the next
4. **Test thoroughly**: All workflows must be deterministic
5. **Document workflows**: Update plan and tasks docs

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

## Coordination Notes

**With Core Agent**:
- Flow uses Core's API Server for agent RPC
- Flow uses Core's WebSocket for real-time events
- Flow coordinates with Core on agent authentication
- Check in before modifying Core API contracts

**With Other Agents**:
- Flow coordinates all agents via event bus
- Agents subscribe to events they care about
- Agents publish events when state changes
- Flow executes workflows that coordinate multiple agents

---

**Status**: Ready for implementation  
**First Phase**: Event Bus Foundation  
**Estimated Time**: 2-3 weeks per phase  
**Integration**: Flows seamlessly with Grain Core orchestration

---

**End of Prompt**
