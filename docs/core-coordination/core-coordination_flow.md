# Grain Flow Agent: API Contracts Registry

**Date**: 2025-12-21-120600-pst  
**Agent**: Grain Flow Agent (9th Agent)  
**Status**: API Contracts Documented — Phase 63 Complete, Phase 64 Complete, ZON Format Integration Coordinating with Court Agent, Phase 3 Validation Step 2 Complete, Step 2 Review Acknowledged, Step 3 Real Metrics Provided, Step 3 Validation Complete, Phase 3 Validation COMPLETE ✅, Phase 3 Completion Reported to Core Agent ✅, TigerBeetle Enhancement Coordination Responded ✅  
**Purpose**: Document Flow Agent's public APIs for Core coordination and other agents

---

## Overview

Grain Flow Agent provides workflow orchestration, agent coordination, and automation services to the Grain OS ecosystem. This document defines all public APIs that Flow Agent exposes to other agents, particularly Core Agent and other agents that use Flow's orchestration services.

**Key Services**:
- Event Bus: Centralized event routing for agent communication
- Agent Coordinator: Agent registry, health monitoring, RPC
- Workflow Engine: DAG-based workflow execution
- Workflow Scheduler: Scheduled and recurring workflow execution
- Workflow Observatory: Metrics aggregation and dashboard

---

## API Contracts: Flow → Core

### 1. Event Bus API

**Module**: `src/grain_flow/event_bus.zig`  
**Purpose**: Centralized event routing for agent-to-agent communication

#### Public Types

**`EventBus`**:
- Centralized event bus instance
- Manages event queue and subscriptions
- Routes events to subscribed agents

**`EventType`** (enum):
- `agent_started = 1`
- `agent_stopped = 2`
- `agent_health_check = 3`
- `workflow_started = 4`
- `workflow_completed = 5`
- `workflow_failed = 6`
- `task_completed = 7`
- `task_failed = 8`
- `data_backup_started = 9`
- `data_backup_completed = 10`
- `data_backup_failed = 11`
- `database_query_completed = 12`
- `api_request_completed = 13`
- `custom = 1000` (for custom event types)

**`Event`** (struct):
- `event_type: EventType`
- `source_agent_id: u32`
- `destination_agent_id: u32`
- `timestamp: u64`
- `payload: [MAX_PAYLOAD_SIZE]u8` (64KB max)
- `payload_len: u32`
- `processed: bool`

#### Public Functions

**`EventBus.init() EventBus`**:
- Initialize event bus
- Returns: New event bus instance

**`EventBus.publish_event(...) bool`**:
- Parameters:
  - `event_type: EventType`
  - `source_agent_id: u32`
  - `destination_agent_id: u32` (0 for broadcast)
  - `timestamp: u64`
- Returns: `true` if event published successfully
- Behavior: Adds event to queue, routes to subscribers

**`EventBus.subscribe(...) bool`**:
- Parameters:
  - `event_type: EventType`
  - `agent_id: u32`
  - `callback: EventSubscriberFn`
  - `user_data: ?*anyopaque`
- Returns: `true` if subscription successful
- Behavior: Registers callback for event type

**`EventBus.unsubscribe(...) bool`**:
- Parameters:
  - `event_type: EventType`
  - `agent_id: u32`
- Returns: `true` if unsubscription successful

**`EventBus.process_events(...) u32`**:
- Parameters:
  - `max_events: u32` (max events to process)
- Returns: Number of events processed
- Behavior: Processes events from queue, calls subscriber callbacks

#### Bounded Allocations

- `MAX_EVENTS: u32 = 10000` (max events in queue)
- `MAX_SUBSCRIBERS: u32 = 256` (max subscribers per event type)
- `MAX_PAYLOAD_SIZE: u32 = 65536` (64KB max payload)

#### Breaking Changes Protocol

**Version**: 1.0 (2025-12-07-054000-pst)

**Stable APIs** (no breaking changes expected):
- `EventBus.init()`
- `EventBus.publish_event()`
- `EventBus.subscribe()`
- `EventBus.unsubscribe()`
- `EventBus.process_events()`

**Future Changes** (deprecation timeline):
- None currently planned

---

### 2. Agent Coordinator API

**Module**: `src/grain_flow/agent_coordinator.zig`  
**Purpose**: Agent registry, health monitoring, and RPC communication

#### Public Types

**`AgentCoordinator`**:
- Manages agent registry
- Tracks agent health and capabilities
- Handles RPC requests between agents

**`Agent`** (struct):
- `agent_id: u32`
- `name: [MAX_AGENT_NAME_LEN]u8` (64 bytes)
- `name_len: u32`
- `status: AgentStatus`
- `last_health_check: u64`
- `capabilities: [MAX_CAPABILITIES]AgentCapability` (32 max)
- `capabilities_len: u32`
- `registered_at: u64`
- `active: bool`

**`AgentStatus`** (enum):
- `inactive = 0`
- `active = 1`
- `unhealthy = 2`
- `unknown = 3`

**`AgentCapability`** (struct):
- `name: [MAX_CAPABILITY_NAME_LEN]u8` (64 bytes)
- `name_len: u32`
- `version: u32`

**`RpcRequest`** (struct):
- `request_id: u32`
- `from_agent_id: u32`
- `to_agent_id: u32`
- `method: [MAX_METHOD_LEN]u8` (128 bytes)
- `method_len: u32`
- `payload: [MAX_PAYLOAD_SIZE]u8` (64KB)
- `payload_len: u32`
- `timestamp: u64`
- `status: RpcStatus`

**`RpcStatus`** (enum):
- `pending = 0`
- `completed = 1`
- `failed = 2`
- `timeout = 3`

#### Public Functions

**`AgentCoordinator.init(...) AgentCoordinator`**:
- Parameters:
  - `event_bus: *EventBus`
- Returns: New agent coordinator instance

**`AgentCoordinator.register_agent(...) ?u32`**:
- Parameters:
  - `name: []const u8`
  - `timestamp: u64`
- Returns: Agent ID if registration successful, `null` otherwise
- Behavior: Registers agent in registry, assigns unique agent ID

**`AgentCoordinator.unregister_agent(...) bool`**:
- Parameters:
  - `agent_id: u32`
- Returns: `true` if unregistration successful
- Behavior: Removes agent from registry

**`AgentCoordinator.update_agent_health(...) bool`**:
- Parameters:
  - `agent_id: u32`
  - `status: AgentStatus`
  - `timestamp: u64`
- Returns: `true` if update successful
- Behavior: Updates agent health status and last check time

**`AgentCoordinator.add_agent_capability(...) bool`**:
- Parameters:
  - `agent_id: u32`
  - `capability: AgentCapability`
- Returns: `true` if capability added successfully
- Behavior: Adds capability to agent's capability list

**`AgentCoordinator.find_agent(...) ?*const Agent`**:
- Parameters:
  - `agent_id: u32`
- Returns: Agent pointer if found, `null` otherwise

**`AgentCoordinator.find_agent_by_name(...) ?*const Agent`**:
- Parameters:
  - `name: []const u8`
- Returns: Agent pointer if found, `null` otherwise

**`AgentCoordinator.send_rpc_request(...) ?u32`**:
- Parameters:
  - `from_agent_id: u32`
  - `to_agent_id: u32`
  - `method: []const u8`
  - `payload: []const u8`
  - `timestamp: u64`
- Returns: Request ID if successful, `null` otherwise
- Behavior: Creates RPC request, routes to target agent

**`AgentCoordinator.get_agent_count() u32`**:
- Returns: Number of registered agents

**`AgentCoordinator.get_active_agent_count() u32`**:
- Returns: Number of active agents

#### Bounded Allocations

- `MAX_AGENTS: u32 = 64` (max agents in registry)
- `MAX_RPC_REQUESTS: u32 = 1000` (max RPC requests in queue)
- `MAX_AGENT_NAME_LEN: u32 = 64` (max agent name length)
- `MAX_CAPABILITIES: u32 = 32` (max capabilities per agent)
- `MAX_CAPABILITY_NAME_LEN: u32 = 64` (max capability name length)
- `MAX_METHOD_LEN: u32 = 128` (max RPC method name length)
- `MAX_PAYLOAD_SIZE: u32 = 65536` (64KB max RPC payload)

#### Breaking Changes Protocol

**Version**: 1.0 (2025-12-07-071000-pst)

**Stable APIs** (no breaking changes expected):
- `AgentCoordinator.init()`
- `AgentCoordinator.register_agent()`
- `AgentCoordinator.unregister_agent()`
- `AgentCoordinator.update_agent_health()`
- `AgentCoordinator.send_rpc_request()`
- `AgentCoordinator.find_agent()`

**Future Changes** (deprecation timeline):
- None currently planned

---

### 3. Workflow Engine API

**Module**: `src/grain_flow/workflow_engine.zig`  
**Purpose**: DAG-based workflow execution

#### Public Types

**`WorkflowEngine`**:
- Executes DAG-based workflows
- Manages workflow state and execution
- Coordinates workflow nodes

**`Workflow`** (struct):
- `workflow_id: u32`
- `name: [MAX_WORKFLOW_NAME_LEN]u8` (128 bytes)
- `name_len: u32`
- `nodes: [MAX_WORKFLOW_NODES]WorkflowNode` (10000 max)
- `nodes_len: u32`
- `edges: [MAX_WORKFLOW_EDGES]WorkflowEdge` (100000 max)
- `edges_len: u32`
- `status: WorkflowStatus`
- `created_at: u64`
- `started_at: u64`
- `completed_at: u64`

**`WorkflowNode`** (struct):
- `node_id: u32`
- `name: [MAX_NODE_NAME_LEN]u8` (128 bytes)
- `name_len: u32`
- `agent_id: u32`
- `status: NodeStatus`
- `started_at: u64`
- `completed_at: u64`
- `error_message: [256]u8`
- `error_message_len: u32`
- `state_data: [MAX_STATE_DATA_SIZE]u8` (64KB)
- `state_data_len: u32`

**`WorkflowEdge`** (struct):
- `from_node_id: u32`
- `to_node_id: u32`
- `edge_type: EdgeType`

**`WorkflowStatus`** (enum):
- `pending = 0`
- `running = 1`
- `completed = 2`
- `failed = 3`
- `cancelled = 4`

**`NodeStatus`** (enum):
- `pending = 0`
- `running = 1`
- `completed = 2`
- `failed = 3`
- `skipped = 4`

**`EdgeType`** (enum):
- `dependency = 0`
- `data_flow = 1`
- `conditional = 2`

#### Public Functions

**`WorkflowEngine.init(...) WorkflowEngine`**:
- Parameters:
  - `event_bus: *EventBus`
  - `coordinator: *AgentCoordinator`
- Returns: New workflow engine instance

**`WorkflowEngine.create_workflow(...) ?u32`**:
- Parameters:
  - `name: []const u8`
  - `timestamp: u64`
- Returns: Workflow ID if successful, `null` otherwise
- Behavior: Creates new workflow, assigns unique workflow ID

**`WorkflowEngine.find_workflow(...) ?*Workflow`**:
- Parameters:
  - `workflow_id: u32`
- Returns: Workflow pointer if found, `null` otherwise

**`WorkflowEngine.execute_workflow(...) bool`**:
- Parameters:
  - `workflow_id: u32`
  - `timestamp: u64`
- Returns: `true` if execution started successfully
- Behavior: Executes workflow DAG in topological order

**`WorkflowEngine.cancel_workflow(...) bool`**:
- Parameters:
  - `workflow_id: u32`
- Returns: `true` if cancellation successful
- Behavior: Cancels workflow execution

**`Workflow.add_node(...) bool`**:
- Parameters:
  - `node: WorkflowNode`
- Returns: `true` if node added successfully

**`Workflow.add_edge(...) bool`**:
- Parameters:
  - `edge: WorkflowEdge`
- Returns: `true` if edge added successfully

#### Bounded Allocations

- `MAX_WORKFLOW_NODES: u32 = 10000` (max nodes per workflow)
- `MAX_WORKFLOW_EDGES: u32 = 100000` (max edges per workflow)
- `MAX_NODE_NAME_LEN: u32 = 128` (max node name length)
- `MAX_STATE_DATA_SIZE: u32 = 65536` (64KB max state data)

#### Breaking Changes Protocol

**Version**: 1.0 (2025-12-07-072000-pst)

**Stable APIs** (no breaking changes expected):
- `WorkflowEngine.init()`
- `WorkflowEngine.create_workflow()`
- `WorkflowEngine.execute_workflow()`
- `Workflow.add_node()`
- `Workflow.add_edge()`

**Future Changes** (deprecation timeline):
- None currently planned

---

### 4. Workflow Scheduler API

**Module**: `src/grain_flow/workflow_scheduler.zig`  
**Purpose**: Scheduled and recurring workflow execution

#### Public Types

**`WorkflowScheduler`**:
- Manages scheduled workflows
- Checks and executes due workflows
- Tracks schedule state

**`ScheduledWorkflow`** (struct):
- `schedule_id: u32`
- `workflow_id: u32`
- `schedule_name: [MAX_SCHEDULE_NAME_LEN]u8` (128 bytes)
- `schedule_name_len: u32`
- `schedule_type: ScheduleType`
- `next_execution: u64` (Unix timestamp, milliseconds)
- `interval_ms: u64` (for interval type)
- `cron_expr: [MAX_CRON_EXPR_LEN]u8` (64 bytes, for recurring)
- `cron_expr_len: u32`
- `enabled: bool`
- `execution_count: u64`
- `last_execution: u64`

**`ScheduleType`** (enum):
- `once = 0` (execute once at specific time)
- `recurring = 1` (execute on cron schedule)
- `interval = 2` (execute at fixed intervals)

#### Public Functions

**`WorkflowScheduler.init(...) WorkflowScheduler`**:
- Parameters:
  - `engine: *WorkflowEngine`
- Returns: New scheduler instance

**`WorkflowScheduler.schedule_once(...) ?u32`**:
- Parameters:
  - `workflow_id: u32`
  - `schedule_name: []const u8`
  - `execution_time: u64` (Unix timestamp, milliseconds)
- Returns: Schedule ID if successful, `null` otherwise
- Behavior: Schedules workflow for one-time execution

**`WorkflowScheduler.schedule_interval(...) ?u32`**:
- Parameters:
  - `workflow_id: u32`
  - `schedule_name: []const u8`
  - `interval_ms: u64` (interval in milliseconds)
  - `first_execution: u64` (Unix timestamp, milliseconds)
- Returns: Schedule ID if successful, `null` otherwise
- Behavior: Schedules workflow for interval-based execution

**`WorkflowScheduler.schedule_recurring(...) ?u32`**:
- Parameters:
  - `workflow_id: u32`
  - `schedule_name: []const u8`
  - `cron_expr: []const u8` (cron expression, basic support)
  - `next_execution: u64` (Unix timestamp, milliseconds)
- Returns: Schedule ID if successful, `null` otherwise
- Behavior: Schedules workflow for recurring execution

**`WorkflowScheduler.check_and_execute(...) u32`**:
- Parameters:
  - `current_time: u64` (Unix timestamp, milliseconds)
- Returns: Number of workflows executed
- Behavior: Checks due schedules and executes workflows

**`WorkflowScheduler.enable_schedule(...) bool`**:
- Parameters:
  - `schedule_id: u32`
- Returns: `true` if enable successful

**`WorkflowScheduler.disable_schedule(...) bool`**:
- Parameters:
  - `schedule_id: u32`
- Returns: `true` if disable successful

**`WorkflowScheduler.remove_schedule(...) bool`**:
- Parameters:
  - `schedule_id: u32`
- Returns: `true` if removal successful

**`WorkflowScheduler.get_schedule(...) ?*const ScheduledWorkflow`**:
- Parameters:
  - `schedule_id: u32`
- Returns: Schedule pointer if found, `null` otherwise

#### Bounded Allocations

- `MAX_SCHEDULED_WORKFLOWS: u32 = 1000` (max scheduled workflows)
- `MAX_SCHEDULE_NAME_LEN: u32 = 128` (max schedule name length)
- `MAX_CRON_EXPR_LEN: u32 = 64` (max cron expression length)

#### Breaking Changes Protocol

**Version**: 1.0 (2025-12-21-091028-pst)

**Stable APIs** (no breaking changes expected):
- `WorkflowScheduler.init()`
- `WorkflowScheduler.schedule_once()`
- `WorkflowScheduler.schedule_interval()`
- `WorkflowScheduler.check_and_execute()`

**Future Changes** (deprecation timeline):
- Full cron expression parsing (enhancement, not breaking)
- Schedule persistence (new feature, not breaking)

---

### 5. Dashboard API

**Module**: `src/grain_flow/dashboard_api.zig`  
**Purpose**: HTTP endpoints for Workflow Observatory dashboard

#### Public Functions

**`register_dashboard_endpoints(...) u32`**:
- Parameters:
  - `api_server: *grain_core.api_server.ApiServer`
- Returns: Number of endpoints registered
- Behavior: Registers dashboard API endpoints with Core API Server

**Registered Endpoints**:
- `GET /api/workflow-observatory/dashboard` — Dashboard HTML
- `GET /api/workflow-observatory/summary` — Aggregated metrics summary (JSON)
- `GET /api/workflow-observatory/metrics` — Full metrics export (JSON)

**`set_dashboard_context(...) void`**:
- Parameters:
  - `obs: *WorkflowObservatory`
- Behavior: Sets observatory instance for dashboard handlers

#### Breaking Changes Protocol

**Version**: 1.0 (2025-12-21-084005-pst)

**Stable APIs** (no breaking changes expected):
- `register_dashboard_endpoints()`
- Endpoint paths and response formats

**Future Changes** (deprecation timeline):
- None currently planned

---

## API Contracts: Flow → Other Agents

### Event Bus (All Agents)

**Purpose**: Any agent can publish/subscribe to events

**Usage Pattern**:
```zig
// Subscribe to workflow events
event_bus.subscribe(
    EventType.workflow_completed,
    my_agent_id,
    my_callback,
    null,
);

// Publish custom event
event_bus.publish_event(
    EventType.custom,
    my_agent_id,
    0, // broadcast
    timestamp,
);
```

### Agent Coordinator (All Agents)

**Purpose**: Agents register themselves and communicate via RPC

**Usage Pattern**:
```zig
// Register agent
const agent_id = coordinator.register_agent("my_agent", timestamp);

// Update health
coordinator.update_agent_health(agent_id, AgentStatus.active, timestamp);

// Send RPC request
const request_id = coordinator.send_rpc_request(
    my_agent_id,
    target_agent_id,
    "method_name",
    payload,
    timestamp,
);
```

### Workflow Engine (All Agents)

**Purpose**: Agents can create and execute workflows

**Usage Pattern**:
```zig
// Create workflow
const workflow_id = engine.create_workflow("my_workflow", timestamp);

// Add nodes (tasks)
const node = WorkflowNode.init(1, "task_name", agent_id);
workflow.add_node(node);

// Add edges (dependencies)
const edge = WorkflowEdge.init(1, 2, EdgeType.dependency);
workflow.add_edge(edge);

// Execute workflow
engine.execute_workflow(workflow_id, timestamp);
```

### Workflow Scheduler (All Agents)

**Purpose**: Agents can schedule workflows for automation

**Usage Pattern**:
```zig
// Schedule one-time execution
scheduler.schedule_once(
    workflow_id,
    "backup_schedule",
    execution_timestamp,
);

// Schedule interval execution
scheduler.schedule_interval(
    workflow_id,
    "sync_schedule",
    60000, // 1 minute
    first_execution_timestamp,
);

// Check and execute due workflows
scheduler.check_and_execute(current_timestamp);
```

---

## Dependencies: Flow → Core

### Core Services Used by Flow Agent

**API Server** (`grain_core.api_server`):
- Used by: Dashboard API endpoints
- Purpose: HTTP server for dashboard and metrics endpoints
- Integration: `register_dashboard_endpoints()` registers routes

**Authentication Service** (`grain_core.auth_service`):
- Used by: Agent Coordinator (future: agent authentication)
- Purpose: Agent identity and authentication
- Integration: Planned for future agent authentication

**WebSocket** (`grain_core.websocket`):
- Used by: Event Bus (future: real-time event delivery)
- Purpose: Real-time communication
- Integration: Planned for WebSocket-based event delivery

**HTTP Client** (`grain_core.http_client`):
- Used by: Agent Coordinator (future: RPC over HTTP)
- Purpose: HTTP communication for RPC
- Integration: Planned for HTTP-based RPC

---

## Versioning Strategy

### Current Version

**Flow Agent API Version**: 1.0  
**Initial Release**: 2025-12-07-040000-pst  
**Last Updated**: 2025-12-21-094141-pst

### Versioning Policy

**Major Version** (breaking changes):
- Changes that require code changes in dependent agents
- Removal of public APIs
- Changes to function signatures
- Changes to data structure layouts

**Minor Version** (additive changes):
- New APIs added
- New optional parameters
- New event types
- New capabilities

**Patch Version** (bug fixes):
- Bug fixes that don't change APIs
- Performance improvements
- Internal optimizations

### Deprecation Timeline

**Current**: No deprecations planned

**Future Deprecations** (if any):
- 6 months notice before removal
- Migration guide provided
- Deprecated APIs marked in documentation

---

## Breaking Changes Protocol

### When Breaking Changes Are Needed

1. **Security Issues**: Immediate breaking change if security vulnerability
2. **Architecture Changes**: Major refactoring requiring API changes
3. **Performance**: Significant performance improvements requiring API changes

### Breaking Change Process

1. **Announcement**: Document breaking change 6 months in advance
2. **Deprecation**: Mark APIs as deprecated in code and documentation
3. **Migration Guide**: Provide migration guide for affected agents
4. **Version Bump**: Increment major version number
5. **Coordination**: Coordinate with Core Agent and affected agents

### Current Status

**No Breaking Changes Planned**: All APIs are stable and production-ready.

---

## Integration Examples

### Example 1: Silo Agent Using Event Bus

```zig
// Silo Agent subscribes to workflow events
event_bus.subscribe(
    EventType.workflow_started,
    silo_agent_id,
    handle_workflow_started,
    null,
);

// Silo Agent publishes database events
event_bus.publish_event(
    EventType.database_query_completed,
    silo_agent_id,
    0, // broadcast
    timestamp,
);
```

### Example 2: Carry Agent Using Agent Coordinator

```zig
// Carry Agent registers itself
const carry_agent_id = coordinator.register_agent("carry", timestamp);

// Carry Agent sends RPC to Silo Agent
const request_id = coordinator.send_rpc_request(
    carry_agent_id,
    silo_agent_id,
    "query_records",
    query_payload,
    timestamp,
);
```

### Example 3: Workspace Agent Using Workflow Engine

```zig
// Workspace Agent creates backup workflow
const workflow_id = engine.create_workflow("backup_workflow", timestamp);

// Add backup task node
const backup_node = WorkflowNode.init(1, "backup_data", silo_agent_id);
workflow.add_node(backup_node);

// Execute workflow
engine.execute_workflow(workflow_id, timestamp);
```

### Example 4: Any Agent Using Workflow Scheduler

```zig
// Schedule daily backup
scheduler.schedule_interval(
    backup_workflow_id,
    "daily_backup",
    86400000, // 24 hours
    first_backup_timestamp,
);

// Check and execute (call periodically)
scheduler.check_and_execute(current_timestamp);
```

---

## Testing Requirements

### API Contract Tests

All Flow Agent APIs must have:
- Unit tests for each public function
- Integration tests with Core Agent services
- Error handling tests
- Bounded allocation tests
- Performance tests (for critical paths)

### Test Coverage

**Current Coverage**:
- Event Bus: Comprehensive tests ✅
- Agent Coordinator: Comprehensive tests ✅
- Workflow Engine: Comprehensive tests ✅
- Workflow Scheduler: Comprehensive tests ✅
- Dashboard API: Comprehensive tests ✅

**Test Files**:
- `tests/133_grain_flow_event_bus_test.zig`
- `tests/134_grain_flow_agent_coordinator_test.zig`
- `tests/135_grain_flow_workflow_engine_test.zig`
- `tests/145_grain_flow_workflow_scheduler_test.zig`
- `tests/144_grain_flow_dashboard_api_test.zig`

---

## Performance Characteristics

### Event Bus

- **Event Processing**: O(n) where n = number of subscribers
- **Queue Operations**: O(1) enqueue, O(n) dequeue (bounded)
- **Memory**: Bounded by `MAX_EVENTS` and `MAX_SUBSCRIBERS`

### Agent Coordinator

- **Agent Lookup**: O(n) where n = number of agents (bounded to 64)
- **RPC Routing**: O(1) request creation, O(n) lookup
- **Memory**: Bounded by `MAX_AGENTS` and `MAX_RPC_REQUESTS`

### Workflow Engine

- **Workflow Execution**: O(n + m) where n = nodes, m = edges
- **Topological Sort**: O(n + m) iterative algorithm
- **Memory**: Bounded by `MAX_WORKFLOW_NODES` and `MAX_WORKFLOW_EDGES`

### Workflow Scheduler

- **Schedule Check**: O(n) where n = number of schedules
- **Execution**: O(1) per workflow execution
- **Memory**: Bounded by `MAX_SCHEDULED_WORKFLOWS`

---

## Security Considerations

### Input Validation

- All agent IDs validated (must be > 0)
- All timestamps validated (must be > 0)
- All string inputs bounded (MAX_* constants)
- All payload sizes bounded (MAX_PAYLOAD_SIZE)

### Resource Limits

- Bounded allocations prevent memory exhaustion
- Queue limits prevent unbounded growth
- Execution limits prevent infinite loops

### Access Control

- Agent registration required before RPC
- Event subscription requires valid agent ID
- Workflow execution requires valid workflow ID

---

## Migration Guide

### From Previous Versions

**Current Version**: 1.0 (first stable release)  
**No Migration Required**: This is the initial API version.

### Future Migrations

When breaking changes are introduced:
1. Deprecation notice (6 months advance)
2. Migration guide with code examples
3. Compatibility layer (if possible)
4. Version-specific documentation

---

## References

- **Flow Agent Plan**: [`docs/plans/plan_flow.md`](../plans/plan_flow.md)
- **Flow Agent Tasks**: [`docs/tasks/tasks_flow.md`](../tasks/tasks_flow.md)
- **Grain Style**: [`docs/grain_style.md`](../grain_style.md)
- **Core Agent API Server**: `src/grain_core/api_server.zig`

---

## ZON Format Integration

**Status**: **PLANNED** ⏳ (2025-12-21-094700-pst)  
**Priority**: **MEDIUM** — Cost savings opportunity, depends on Grain Court ZON module  
**Estimated Time**: 1-2 weeks (after Court Agent ZON module is available)

### Overview

Flow Agent will integrate ZON (Zero Overhead Notation) format for workflow metrics export, enabling **35-70% token reduction** for LLM communication with Research Agent and other consumers.

**Key Value**: Save ~50% on LLM API costs by using ZON for workflow metrics export while maintaining JSON compatibility.

### Integration Points

**Workflow Observatory ZON Export**:
- Add ZON export option to `WorkflowObservatory.export_all_metrics_zon()`
- Add ZON summary export to `WorkflowObservatory.get_aggregated_summary_zon()`
- Support both JSON and ZON export formats (backward compatible)

**Dashboard API ZON Support**:
- Add ZON export endpoint: `/api/workflow-observatory/metrics?format=zon`
- Add ZON summary endpoint: `/api/workflow-observatory/summary?format=zon`
- Maintain JSON endpoints for backward compatibility

### Dependencies

**Blocking**:
- ⏳ Grain Court ZON module (`src/grain_court/zon_format.zig`) — Court Agent Phase 1 (in progress)
- ⏳ ZON encoder/decoder API availability — Coordinating with Court Agent

**Active Coordination**:
- ✅ Court Agent: Implementing ZON module (Layer 1 from Flow Agent's proposal)
- ⏳ Flow Agent: Ready to coordinate on API design and integration

**Non-Blocking**:
- Research Agent ZON parser (can proceed in parallel)
- Grainscript ZON serializer (independent)

### Coordination Required

**With Grain Court Agent** (Active Coordination Partner):
- ✅ Court Agent: Implementing ZON module (Layer 1 from Flow Agent's proposal)
- ⏳ Coordinate on ZON encoder/decoder API design
- ⏳ Review ZON encoder/decoder interface when available
- ⏳ Confirm format specification and data type support
- **Status**: Court Agent Phase 1 in progress, Flow Agent ready to coordinate

**With Research Agent**:
- Coordinate on ZON export format requirements
- Test ZON export with Research Agent's parser (when available)
- Validate token count reduction (35-70% vs JSON)

### Success Criteria

- ✅ Workflow metrics exportable in ZON format
- ✅ 35-70% token reduction vs JSON (validated)
- ✅ Backward compatible (JSON still available)
- ✅ Research Agent can parse ZON export

### References

- **ZON Format Proposal**: [`docs/research/zon_format_grain_court_grainscript_proposal_2025-12-20-210116-pst.md`](../research/zon_format_grain_court_grainscript_proposal_2025-12-20-210116-pst.md)
- **ZON Token Efficiency Validation**: [`docs/research/zon_format_token_efficiency_validation_2025-12-20-211812-pst.md`](../research/zon_format_token_efficiency_validation_2025-12-20-211812-pst.md)
- **Implementation Tasks**: [`docs/tasks/tasks_flow.md`](../tasks/tasks_flow.md) — ZON Format Integration section

---

**Date**: 2025-12-21-104900-pst  
**Agent**: Grain Flow Agent  
**Status**: API Contracts Documented — Ready for Core Coordination, ZON Format Integration Coordinating with Court Agent, Phase 3 Validation Step 2 Complete, Step 2 Review Acknowledged, Court Agent Welcome

This document defines all public APIs that Flow Agent exposes to Core Agent and other agents. All APIs are stable and production-ready. Breaking changes will follow the deprecation timeline (6 months notice).
