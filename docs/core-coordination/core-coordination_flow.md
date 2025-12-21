# Grain Flow Agent: API Contracts Registry

**Date**: 2025-12-21-142100-pst  
**Agent**: Grain Flow Agent (9th Agent)  
**Status**: All Phases Complete ✅ (Phase 1-5 COMPLETE), SLC Product Workflow Templates Ready ✅, Research Agent Collaboration Complete ✅, Phase 3 Validation COMPLETE ✅, ZON Format Integration Coordinating with Court Agent ⏳, TigerBeetle Enhancement Coordination Responded ⏳, Core Agent Coordination Plan Acknowledged ✅, Workflow Scheduler Cron Parser Enhanced ✅, Workflow Visualizer Hierarchical Layout Enhanced ✅, Build Configuration Coordination Requested ⏳  
**Purpose**: Document Flow Agent's public APIs for Core coordination and other agents

---

## Overview

**Flow Agent Status**: All core phases complete (Phase 1-5). Currently coordinating with Court Agent on ZON format integration, awaiting Core Agent guidance on build configuration and TigerBeetle priority, and ready for next coordination steps.

**Recent Work**:
- ✅ Workflow Visualizer Hierarchical Layout Enhancement (2025-12-21-141900-pst)
- ✅ Workflow Scheduler Cron Parser Enhancement (2025-12-21-141800-pst)
- ✅ Phase 3 Validation Complete (2025-12-21-105500-pst)
- ⏳ Build Configuration Coordination Requested (2025-12-21-142100-pst)

**Pending Dependencies**:
1. **ZON Format Integration**: ⏳ Waiting on Court Agent's ZON module implementation (Phase 1)
2. **TigerBeetle Enhancement**: ⏳ Waiting on Core Agent's priority decision
3. **Build Configuration**: ⏳ Requesting Core Agent guidance on module definition ordering

---

## Active Coordination Requests

### 1. Build Configuration Guidance (Priority: HIGH)

**Date**: 2025-12-21-142100-pst  
**Status**: ⏳ Awaiting Core Agent Response  
**Document**: `docs/agent-communications/flow_to_core_build_and_next_steps_2025-12-21-142100-pst.md`

**Issue**: `build.zig` has error: `grain_court_module` references `grain_core_module` before it's defined (line 267 references line 286).

**Questions for Core Agent**:
- Is the current module order intentional?
- Should Flow Agent fix this directly, or is Core Agent handling it?
- Is there a dependency reason for the current order?

**Flow Agent Recommendation**: Fix by reordering module definitions (define `grain_core_module` before `grain_court_module`), but awaiting Core Agent guidance.

### 2. TigerBeetle Enhancement Priority (Priority: MEDIUM)

**Date**: 2025-12-21-120600-pst  
**Status**: ⏳ Awaiting Core Agent Priority Decision  
**Document**: `docs/agent-communications/research_to_core_tigerbeetle_priority_coordination_2025-12-21-120700-pst.md`

**Context**: Research Agent proposed TigerBeetle enhancements for deterministic features (abstracted time, simulation mode) for Event Bus, Grain Silo, and Basin Kernel.

**Flow Agent Response**: Provided design recommendations:
- Enhance existing code (don't replace)
- Runtime configuration for time abstraction
- Simulation mode always available
- Backward compatibility maintained
- Separate messaging/storage with shared infrastructure (phased approach)

**Questions for Core Agent**:
- Priority for TigerBeetle enhancement implementation?
- Phase 1 (Time Abstraction) timeline?
- Phase 2 (Simulation Mode) timeline?
- Phase 3 (Unified Messaging/Storage) timeline and coordination needs?

### 3. ZON Format Integration (Priority: LOW - Waiting on Court Agent)

**Date**: 2025-12-21-103800-pst  
**Status**: ⏳ Waiting on Court Agent ZON Module (Phase 1)  
**Document**: `docs/agent-communications/flow_to_court_welcome_2025-12-21-103800-pst.md`

**Context**: Flow Agent proposed ZON format integration for workflow metrics export (35-70% token reduction vs JSON).

**Dependencies**:
- ⏳ Court Agent: Implementing ZON module (`src/grain_court/zon_format.zig`)
- ⏳ Flow Agent: Ready to coordinate on API design and integration

**Next Steps**: Coordinate with Court Agent once ZON module is available.

---

## Public API Contracts

### Flow → Core APIs

Flow Agent uses the following Core Agent services:

#### API Server Integration

**Module**: `grain_core.api_server`  
**Usage**: Dashboard API endpoint registration  
**Functions Used**:
- `ApiServer.init()` - Initialize API server
- `ApiServer.register_endpoint()` - Register dashboard endpoints
- `ApiServer.start()` / `ApiServer.stop()` - Lifecycle management

**Integration Points**:
- `/api/workflow-observatory/dashboard` - Dashboard HTML
- `/api/workflow-observatory/summary` - Summary JSON
- `/api/workflow-observatory/metrics` - Full metrics JSON

**Status**: ✅ Integrated (Phase 3 Dashboard API)

**Future Integration**:
- WebSocket support for real-time event streaming
- Authentication integration for secure endpoints

#### Event Bus (Standalone, Future: Core WebSocket)

**Current**: Flow Agent maintains standalone Event Bus  
**Future**: Integrate with Core Agent WebSocket infrastructure

**Status**: ✅ Standalone implementation complete, ⏳ WebSocket integration pending

---

### Flow → Other Agents APIs

Flow Agent exposes the following APIs to other agents:

#### Workflow Observatory APIs

**Module**: `grain_flow.workflow_observatory`  
**Status**: ✅ Complete (Phase 3)

**Functions**:
- `WorkflowObservatory.init()` - Initialize observatory
- `WorkflowObservatory.export_all_metrics_json()` - Export all metrics as JSON
- `WorkflowObservatory.get_aggregated_summary()` - Get aggregated summary

**Future APIs**:
- `export_all_metrics_zon()` - ZON format export (⏳ Waiting on Court Agent)
- `get_aggregated_summary_zon()` - ZON format summary (⏳ Waiting on Court Agent)

#### Event Bus APIs

**Module**: `grain_flow.event_bus`  
**Status**: ✅ Complete (Phase 1)

**Functions**:
- `EventBus.init()` - Initialize event bus
- `EventBus.publish_event()` - Publish event
- `EventBus.publish_event_with_payload()` - Publish event with payload
- `EventBus.subscribe()` - Subscribe to event type
- `EventBus.unsubscribe()` - Unsubscribe from event type
- `EventBus.process_events()` - Process pending events

**Event Types**: 13 predefined types (agent_started, workflow_started, etc.) + custom events

**Future Enhancements**:
- Source filtering for subscribers (⏳ Requires Core Agent coordination if API changes needed)

#### Agent Coordinator APIs

**Module**: `grain_flow.agent_coordinator`  
**Status**: ✅ Complete (Phase 2)

**Functions**:
- `AgentCoordinator.init()` - Initialize coordinator
- `AgentCoordinator.register_agent()` - Register agent
- `AgentCoordinator.unregister_agent()` - Unregister agent
- `AgentCoordinator.find_agent()` - Find agent by ID
- `AgentCoordinator.get_agent_count()` - Get registered agent count

**Capabilities**:
- Agent registry (MAX_AGENTS: 64)
- Health monitoring
- Capability discovery
- Agent-to-agent RPC (MAX_RPC_REQUESTS: 1000)

#### Workflow Engine APIs

**Module**: `grain_flow.workflow_engine`  
**Status**: ✅ Complete (Phase 3)

**Functions**:
- `WorkflowEngine.init()` - Initialize engine
- `WorkflowEngine.create_workflow()` - Create workflow
- `WorkflowEngine.find_workflow()` - Find workflow by ID
- `WorkflowEngine.execute_workflow()` - Execute workflow
- `Workflow.add_node()` - Add node to workflow
- `Workflow.add_edge()` - Add edge to workflow

**Limits**:
- MAX_WORKFLOW_NODES: 10000
- MAX_WORKFLOW_EDGES: 100000
- MAX_WORKFLOW_DEPTH: 1000

#### Workflow Templates APIs

**Module**: `grain_flow.workflow_templates`  
**Status**: ✅ Complete (SLC Product Integration)

**Functions**:
- `create_nostr_profile_publish_workflow()` - Nostr Profile Builder workflow
- `create_dag_website_publish_workflow()` - DAG Website Builder workflow

**Usage**: Pre-built workflow patterns for SLC products

#### Workflow Visualizer APIs

**Module**: `grain_flow.workflow_visualizer`  
**Status**: ✅ Complete (Phase 4) + ✅ Hierarchical Layout Enhanced (2025-12-21)

**Functions**:
- `WorkflowVisualizer.init()` - Initialize visualizer
- `WorkflowVisualizer.render_to_svg()` - Render workflow to SVG
- `WorkflowVisualizer.render_to_html()` - Render workflow to HTML
- `WorkflowVisualizer.get_svg_content()` - Get SVG content
- `WorkflowVisualizer.get_html_content()` - Get HTML content

**Layout**: Hierarchical layout algorithm (nodes positioned by DAG structure)

#### Workflow Scheduler APIs

**Module**: `grain_flow.workflow_scheduler`  
**Status**: ✅ Complete (Phase 5) + ✅ Cron Parser Enhanced (2025-12-21)

**Functions**:
- `WorkflowScheduler.init()` - Initialize scheduler
- `WorkflowScheduler.schedule_one_time()` - Schedule one-time workflow
- `WorkflowScheduler.schedule_recurring()` - Schedule recurring workflow (cron)
- `WorkflowScheduler.check_and_execute()` - Check and execute due workflows

**Cron Support**: Basic cron parser (`* * * * *`, `0 * * * *`, numeric minutes)

---

## Bounded Allocations

All Flow Agent modules use bounded allocations (Grain Style requirement):

**Event Bus**:
- `MAX_EVENTS: u32 = 10000`
- `MAX_SUBSCRIBERS: u32 = 256`
- `MAX_PAYLOAD_SIZE: u32 = 65536`

**Agent Coordinator**:
- `MAX_AGENTS: u32 = 64`
- `MAX_RPC_REQUESTS: u32 = 1000`
- `MAX_CAPABILITIES: u32 = 32`

**Workflow Engine**:
- `MAX_WORKFLOW_NODES: u32 = 10000`
- `MAX_WORKFLOW_EDGES: u32 = 100000`
- `MAX_WORKFLOW_DEPTH: u32 = 1000`
- `MAX_NODE_NAME_LEN: u32 = 128`
- `MAX_STATE_DATA_SIZE: u32 = 65536`

**Workflow Metrics**:
- `MAX_EXECUTIONS: u32 = 10000`
- `MAX_WORKFLOWS: u32 = 1000`

**Agent Coordination Metrics**:
- `MAX_COORDINATIONS: u32 = 10000`
- `MAX_AGENT_PAIRS: u32 = 1024`

**Failure Pattern Metrics**:
- `MAX_FAILURES: u32 = 10000`
- `MAX_FAILURE_TYPES: u32 = 16`

**Performance Metrics**:
- `MAX_QUEUE_DEPTH_SAMPLES: u32 = 10000`
- `MAX_WAIT_TIME_SAMPLES: u32 = 10000`
- `MAX_RESOURCE_SAMPLES: u32 = 10000`

**Workflow Scheduler**:
- `MAX_SCHEDULES: u32 = 1000`
- `MAX_CRON_EXPR_LEN: u32 = 128`

**Workflow Visualizer**:
- `MAX_SVG_CONTENT_LEN: u32 = 2 * 1024 * 1024`
- `MAX_HTML_CONTENT_LEN: u32 = 2 * 1024 * 1024`
- `MAX_NODE_LABEL_LEN: u32 = 128`

---

## Breaking Changes Protocol

**Versioning**: Flow Agent uses semantic versioning (currently v1.0.0)  
**Deprecation Policy**: 2-phase deprecation (warning phase → removal phase)  
**Communication**: Breaking changes communicated via coordination documents

**Current Status**: No breaking changes planned. All APIs are stable.

**Future Breaking Changes** (if any):
- Event Bus source filtering (would require `subscribe()` signature change - ⏳ Requires Core Agent coordination)
- ZON format integration (additive, backward compatible)

---

## Integration Examples

### Dashboard API Integration

```zig
// Initialize Flow Agent components
var event_bus = grain_flow.EventBus.init();
var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);

// Initialize observatory and collectors
var workflow_collector = grain_flow.WorkflowMetricsCollector.init();
var coordination_collector = grain_flow.AgentCoordinationMetricsCollector.init();
var failure_collector = grain_flow.FailurePatternMetricsCollector.init();
var performance_collector = grain_flow.PerformanceMetricsCollector.init();

var observatory = grain_flow.WorkflowObservatory.init();
observatory.set_workflow_collector(&workflow_collector);
observatory.set_coordination_collector(&coordination_collector);
observatory.set_failure_collector(&failure_collector);
observatory.set_performance_collector(&performance_collector);

// Register dashboard API endpoints with Core API Server
var dashboard_api = grain_flow.DashboardApiContext.init();
dashboard_api.set_observatory(&observatory);
grain_flow.register_dashboard_endpoints(api_server);
```

### Workflow Execution

```zig
// Create workflow
const workflow_id = engine.create_workflow("my_workflow", timestamp);
const workflow = engine.find_workflow(workflow_id.?);

// Add nodes
const node1 = grain_flow.WorkflowNode.init(1, "task1", agent_id);
const node2 = grain_flow.WorkflowNode.init(2, "task2", agent_id);
_ = workflow.?.add_node(node1);
_ = workflow.?.add_node(node2);

// Add edges (dependencies)
const edge = grain_flow.WorkflowEdge.init(1, 2, .dependency);
_ = workflow.?.add_edge(edge);

// Execute workflow
_ = engine.execute_workflow(workflow_id.?, timestamp);
```

### Event Bus Usage

```zig
// Subscribe to event type
_ = event_bus.subscribe(
    grain_flow.EventType.workflow_completed,
    agent_id,
    my_handler_fn,
    user_data,
);

// Publish event
_ = event_bus.publish_event(
    grain_flow.EventType.workflow_started,
    source_agent_id,
    0, // broadcast
    timestamp,
);
```

---

## Performance Characteristics

**Event Bus**:
- O(1) event publishing (bounded queue)
- O(n) event routing (n = subscribers per type, bounded)
- Iterative processing (no recursion)

**Agent Coordinator**:
- O(1) agent registration (bounded registry)
- O(n) agent lookup (n = registered agents, bounded)

**Workflow Engine**:
- O(V + E) workflow execution (V = nodes, E = edges)
- Iterative topological sort (no recursion)
- Bounded workflow size (MAX_WORKFLOW_NODES, MAX_WORKFLOW_EDGES)

**Workflow Observatory**:
- O(1) metric recording (bounded storage)
- O(n) JSON export (n = stored metrics, bounded)

---

## Security Considerations

**Event Bus**:
- Event filtering by destination agent ID (authorization)
- Bounded payload size (prevents DoS)
- Bounded event queue (prevents memory exhaustion)

**Agent Coordinator**:
- Agent ID validation (non-zero IDs required)
- Bounded agent registry (prevents DoS)
- Capability-based access control (future)

**Workflow Engine**:
- Bounded workflow size (prevents DoS)
- State data size limits (MAX_STATE_DATA_SIZE)

**Dashboard API**:
- Future: Authentication integration with Core Agent
- Future: Rate limiting for API endpoints

---

## Coordination Status Summary

**Complete**:
- ✅ Phase 1-5 Implementation Complete
- ✅ Phase 3 Validation Complete (Research Agent collaboration)
- ✅ API Contracts Documented (Phase 63)
- ✅ Integration Tests Created (Phase 64)
- ✅ SLC Product Workflow Templates Complete

**In Progress**:
- ⏳ ZON Format Integration (Waiting on Court Agent ZON module)
- ⏳ TigerBeetle Enhancement (Waiting on Core Agent priority decision)
- ⏳ Build Configuration Fix (Requesting Core Agent guidance)

**Future**:
- Event Bus WebSocket Integration (Core Agent)
- Dashboard API Authentication (Core Agent)
- Event Bus Source Filtering (May require API changes, needs Core coordination)

---

## References

**Flow Agent Documents**:
- Task List: `docs/tasks/tasks_flow.md`
- Plan: `docs/plans/plan_flow.md`
- Phase 3 Validation: `docs/agent-communications/flow_to_research_phase3_step3_review_2025-12-21-105600-pst.md`

**Coordination Messages**:
- Build Configuration: `docs/agent-communications/flow_to_core_build_and_next_steps_2025-12-21-142100-pst.md`
- TigerBeetle Response: `docs/agent-communications/flow_to_research_tigerbeetle_enhancement_response_2025-12-21-120600-pst.md`
- Phase 3 Completion: `docs/agent-communications/flow_to_core_phase3_completion_2025-12-21-105900-pst.md`

**Research Agent Collaboration**:
- Phase 3 Validation Complete: `docs/agent-communications/research_to_flow_phase3_step3_validation_2025-12-21-105500-pst.md`

**Court Agent Coordination**:
- ZON Format Welcome: `docs/agent-communications/flow_to_court_welcome_2025-12-21-103800-pst.md`

---

**Last Updated**: 2025-12-21-142100-pst  
**Next Review**: After Core Agent responses on coordination requests
