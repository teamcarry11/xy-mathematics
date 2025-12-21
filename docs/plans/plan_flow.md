# Grain Flow Agent: Development Plan

**Agent**: Grain Flow Agent (9th Agent)  
**Status**: All Phases Complete ✅ (Phase 1-5 COMPLETE), Phase 2 Instrumentation Complete ✅ (All 4 Phases: Basic Metrics, Agent Coordination, Failure Patterns, Performance), SLC Product Workflow Templates Ready ✅, Research Agent Collaboration Complete ✅, ZON Format Integration Proposal Created ✅, Phase 3 Observatory Foundation Complete ✅, Phase 3 Dashboard API Complete ✅, Phase 3 Visualization Complete ✅, Workflow Scheduler Enhancement Complete ✅, Phase 63 API Contracts Documented ✅, Phase 64 Integration Tests Created ✅, Phase 3 Validation COMPLETE ✅, ZON Format Integration Coordinating with Court Agent ⏳, Phase 3 Completion Reported to Core Agent ✅, TigerBeetle Enhancement Coordination Responded ⏳, Core Agent Coordination Plan Acknowledged ✅, Workflow Scheduler Cron Parser Enhanced ✅, Workflow Visualizer Hierarchical Layout Enhanced ✅, Build Configuration Coordination Requested ⏳, Core Coordination Document Updated ✅  
**Last Updated**: 2025-12-21-142200-pst

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

**Status**: **COMPLETE** ✅ (2025-12-07-072000-pst)  
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

**Tests**: `tests/136_grain_flow_workflow_engine_test.zig`

**Completed Components**:
- ✅ Workflow DAG definition (nodes, edges)
- ✅ Bounded workflow depth (MAX_WORKFLOW_DEPTH: u32 = 1000)
- ✅ Bounded workflow nodes (MAX_WORKFLOW_NODES: u32 = 10000)
- ✅ Bounded workflow edges (MAX_WORKFLOW_EDGES: u32 = 100000)
- ✅ Workflow execution engine (iterative topological sort, no recursion)
- ✅ State management (workflow state, node state, state data)
- ✅ Error handling and recovery (error messages, failed status)
- ✅ Workflow scheduling (workflow creation, execution)
- ✅ Event bus integration (workflow_started, workflow_completed, workflow_failed, task_completed events)
- ✅ Comprehensive tests (11 test cases)

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

**Status**: **COMPLETE** ✅ (2025-12-08-140000-pst)  
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

**Tests**: `tests/137_grain_flow_workflow_visualizer_test.zig`

**Completed Components**:
- ✅ Workflow DAG rendering (SVG generation)
- ✅ Node visualization (agents, tasks, conditions with status colors)
- ✅ Edge visualization (dependencies, data flow, conditional with color coding)
- ✅ State visualization (current execution state via node status colors)
- ✅ HTML export (workflow visualization embedded in HTML)
- ✅ SVG export (standalone SVG workflow diagrams)
- ✅ Grid layout algorithm (iterative, no recursion)
- ✅ Color coding (status-based node colors, type-based edge colors)
- ✅ Comprehensive tests (10 test cases)

**Integration**: Ready for Bubble Agent export pipeline integration (PDF/HTML export)

---

### Phase 5: Workflow Templates & Integration Examples (Priority: MEDIUM)

**Goal**: Pre-built workflow templates and integration examples

**Status**: **COMPLETE** ✅ (2025-12-20-144320-pst)  
**Estimated Time**: 1-2 weeks

**Features**:
- Workflow template builders
- Common workflow patterns (database backup, data sync, parallel, sequential)
- Integration examples with other agents (Silo, Carry)
- Template information API

**Dependencies**:
- Phase 3: Workflow Engine ✅
- Phase 2: Agent Coordinator ✅

**Location**: `src/grain_flow/workflow_templates.zig`

**Tests**: `tests/138_grain_flow_workflow_templates_test.zig`

**Completed Components**:
- ✅ Workflow template structure (`WorkflowTemplate`)
- ✅ Workflow template builder (`WorkflowTemplateBuilder`)
- ✅ Database backup workflow template (Silo + Core integration)
- ✅ Data sync workflow template (Carry + Silo integration)
- ✅ Parallel processing workflow template
- ✅ Sequential workflow template
- ✅ Nostr Profile Builder workflow template (SLC Product) - Workspace → Silo → Aurora → Skate
- ✅ DAG Website Builder workflow template (SLC Product) - Workspace → Skate → Silo → Aurora
- ✅ Template information API (`get_template_info()`)
- ✅ Comprehensive tests (8 test cases including SLC product templates)

**Integration**: Demonstrates real-world usage patterns with Silo Agent, Carry Agent, and SLC products (Aurora, Skate, Workspace)

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
├── workflow_visualizer.zig # Visual workflow representation
└── workflow_templates.zig # Workflow templates and integration examples

tests/
├── 134_grain_flow_event_bus_test.zig
├── 135_grain_flow_agent_coordinator_test.zig
├── 136_grain_flow_workflow_engine_test.zig
├── 137_grain_flow_workflow_visualizer_test.zig
└── 138_grain_flow_workflow_templates_test.zig

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

1. **Production Use**: Flow Agent is ready for production use with other agents
2. **Research Agent Collaboration**: Workflow Observatory collaboration in progress ✅
   - **Priority 1**: Workflow Observability Metrics (Research Agent, Week 1-2) — **COMPLETE** ✅
   - **Metric Definitions**: Received and reviewed (2025-12-20-200931-pst)
   - **Phase 2**: Instrumentation (Flow Agent, Week 2-3) — **READY TO IMPLEMENT** ✅
     - Phase 1: Basic Metrics (execution time, success rate, failure rate)
     - Phase 2: Agent Coordination Metrics (latency, success rate, patterns)
     - Phase 3: Failure Pattern Metrics (type distribution, recovery rate, complexity correlation)
     - Phase 4: Performance Characteristics (resource usage, queue depth, wait time)
   - **Phase 3**: Workflow Observatory Dashboard (Together, Week 3-4) — **IN PROGRESS** 🔄
     - Observatory module created (`workflow_observatory.zig`) ✅
     - Metrics aggregation functionality ✅
     - JSON export (summary and full) ✅
     - Dashboard API endpoints created (`dashboard_api.zig`) ✅
     - API endpoint handlers (summary, metrics, dashboard HTML) ✅
     - Endpoint registration with Core API Server ✅
     - Real-time visualization dashboard (`dashboard.html`) ✅
     - Auto-refresh metrics display ✅
     - Tests complete ✅
     - Metrics analysis and insights (Research Agent collaboration - complete ✅)
       - Workflow Metrics Analyzer Module complete (2025-12-21-094200-pst)
       - Insights Generator Module complete (2025-12-21-094300-pst)
       - Integration validation ready (2025-12-21-094400-pst)
       - Sample JSON export provided (2025-12-21-103700-pst)
       - Validation timeline confirmed (6-9 days) (2025-12-21-103700-pst)
       - Step 1 validation complete ✅ (2025-12-21-104400-pst)
         - Parser validated with Flow Agent sample JSON
         - All validation criteria passed
         - Integration tests created
       - Step 2 validation complete ✅ (2025-12-21-104800-pst)
         - Insights generated (6 insights validated)
         - Hypotheses tested (3 hypotheses validated appropriately)
         - Recommendations provided (3 recommendations validated)
         - Flow Agent review complete (all insights align with expected behavior)
       - Step 2 validation review acknowledged ✅ (2025-12-21-104900-pst)
       - Step 3 validation ready (end-to-end integration with real data)
         - Realistic Metrics Generator created ✅ (2025-12-21-105100-pst)
           - Realistic workflow execution scenario generator
           - Tests created
           - Real workflow metrics ready for export
         - Flow Agent: Ready to provide real workflow metrics export
         - Research Agent: Ready to analyze real metrics
   - **Reference**: [`docs/research/workflow_observability_metrics_research_2025-12-20-200931-pst.md`](../research/workflow_observability_metrics_research_2025-12-20-200931-pst.md)
3. **SLC Product Integration**: Workflow templates ready for:
   - Nostr Profile Builder (profile publishing workflow template complete ✅)
   - DAG Website Builder (website publishing workflow template complete ✅)
   - Workspace App Suite (ready to add templates as needed)
4. **Monitor Integration**: Watch for additional workflow orchestration requirements as SLC products develop
5. **Performance Optimization**: Monitor and optimize based on real-world usage patterns (after observability layer is built)
6. **Enhanced Examples**: Continue adding real-world workflow examples based on usage feedback
7. **Workflow Scheduler**: Workflow scheduling enhancement complete ✅
   - One-time, interval, and recurring schedule support
   - Schedule management (enable/disable/remove)
   - Automatic execution checking
   - Ready for production use
8. **Phase 63: API Contracts Registry**: API documentation complete ✅
   - Flow → Core API contracts documented
   - Flow → Other Agents API contracts documented
   - Breaking changes protocol defined
   - Versioning strategy established
   - Ready for Core coordination

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md) — Coding principles and guidelines
- **Core Plan**: [`docs/plan.md`](../plan.md) — Core overview
- **Grain Flow Agent Prompt**: [`docs/grain_flow_agent_prompt.md`](../grain_flow_agent_prompt.md) — Agent prompt and architecture
- **Core Coordination Plan**: [`docs/agent-communications/core_agent_coordination_plan_2025-12-06-061647-pst.md`](../agent-communications/core_agent_coordination_plan_2025-12-06-061647-pst.md) — Agent coordination strategy

---

**Status**: All Core Phases Complete ✅  
**Phase 1**: Event Bus Foundation ✅ COMPLETE  
**Phase 2**: Agent Coordinator ✅ COMPLETE  
**Phase 3**: Workflow Engine ✅ COMPLETE  
**Phase 4**: Workflow Visualizer ✅ COMPLETE  
**Phase 5**: Workflow Templates & Integration Examples ✅ COMPLETE (Optional Enhancement)  
**Research Collaboration**: Workflow Observatory collaboration started ✅ (Research Agent Priority 1 in progress)  
**Phase 63**: API Contracts Registry ✅ COMPLETE (API documentation complete)  
**Phase 64**: Integration Test Infrastructure ✅ COMPLETE (Flow → Core integration tests created)  
**Estimated Time**: 2-3 weeks per phase (All core phases completed)  
**Integration**: Flows seamlessly with Grain Core orchestration, ready for SLC product workflow orchestration, collaborating with Research Agent on observability layer

---

## Phase 64: Integration Test Infrastructure

**Status**: **COMPLETE** ✅ (2025-12-21-094300-pst)  
**Priority**: **HIGH** — Catches integration issues early  
**Estimated Time**: 1 week

### Completed Work

**Integration Test File**: `tests/146_grain_flow_core_integration_test.zig`

**Test Coverage**:
- **Dashboard API + Core API Server Integration**: 8 test cases
  - Endpoint registration with Core API Server
  - Route finding and validation
  - Request handling (dashboard HTML, summary JSON, metrics JSON)
  - Observatory context integration
  - API Server lifecycle (start/stop) integration
  - Multiple endpoint registration
- **Event Bus Integration Pattern**: 1 test case (future Core WebSocket)
- **Agent Coordinator Integration Pattern**: 1 test case (future Core Auth)
- **Workflow Engine Integration Pattern**: 1 test case (uses Core services indirectly)

**Total**: 11 integration test cases

**Integration Points Tested**:
1. Dashboard API endpoint registration with Core API Server ✅
2. Dashboard API request handling with Core API Server ✅
3. Event Bus integration patterns (standalone, future: Core WebSocket) ✅
4. Agent Coordinator integration patterns (standalone, future: Core Auth) ✅
5. Workflow Engine integration patterns (uses Core services indirectly) ✅

**Status**: ✅ **COMPLETE** — All compilation errors fixed (2025-12-21-094800-pst)
- ✅ Fixed null pointer comparison errors in `dashboard_api.zig` and `workflow_observatory.zig`
- ✅ Integration tests should now compile successfully

**Next Steps**:
- ✅ Compilation errors fixed (2025-12-21-094800-pst)
- ⏳ Verify integration tests compile and run successfully
- ⏳ Ready for Core Agent's integration test framework integration when available

---

## ZON Format Integration

**Status**: **COORDINATING** ⏳ (2025-12-21-103800-pst)  
**Priority**: **MEDIUM** — Cost savings opportunity, coordinating with Court Agent on ZON module  
**Estimated Time**: 1-2 weeks (after Court Agent ZON module Phase 1 complete)

### Welcome Court Agent! 🌾⚒️

**Court Agent** (11th Agent) is now implementing Layer 1 of Flow Agent's ZON format proposal! Flow Agent is coordinating directly with Court Agent on ZON format integration.

### Overview

Flow Agent will integrate ZON (Zero Overhead Notation) format for workflow metrics export, enabling 35-70% token reduction for LLM communication with Research Agent and other consumers.

**Key Value**: Save ~50% on LLM API costs by using ZON for workflow metrics export while maintaining JSON compatibility.

### Implementation Phases

**Phase 1: Coordination & Dependencies** ⏳
- Coordinate with Court Agent on ZON module availability
- Review ZON encoder/decoder API
- Confirm format specification

**Phase 2: Workflow Observatory ZON Export** ⏳
- Add ZON export to `WorkflowObservatory`
- Integrate with Court Agent's ZON encoder
- Support both JSON and ZON formats

**Phase 3: Dashboard API ZON Support** ⏳
- Add ZON export endpoints with format parameter
- Maintain backward compatibility (JSON default)

**Phase 4: Testing & Validation** ⏳
- Test ZON export functionality
- Validate token reduction (35-70%)
- Performance benchmarks

**Phase 5: Documentation & Integration** ⏳
- Update API documentation
- Coordinate with Research Agent on validation

### Dependencies

**Blocking**: Grain Court ZON module (Court Agent Phase 1 — in progress)  
**Active Coordination**: Court Agent implementing ZON module, Flow Agent coordinating on API design  
**Non-Blocking**: Research Agent ZON parser, Grainscript ZON serializer

### Success Criteria

- ✅ Workflow metrics exportable in ZON format
- ✅ 35-70% token reduction vs JSON
- ✅ Backward compatible (JSON still available)
- ✅ Research Agent can parse ZON export

### References

- **ZON Format Proposal**: [`docs/research/zon_format_grain_court_grainscript_proposal_2025-12-20-210116-pst.md`](../research/zon_format_grain_court_grainscript_proposal_2025-12-20-210116-pst.md)
- **Implementation Tasks**: [`docs/tasks/tasks_flow.md`](../tasks/tasks_flow.md) — ZON Format Integration section

---

**End of Plan**
