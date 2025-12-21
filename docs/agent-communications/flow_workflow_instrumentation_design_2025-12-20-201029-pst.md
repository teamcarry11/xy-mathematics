# Flow Agent: Workflow Instrumentation Design (Preliminary)

**Date**: 2025-12-20-201029-pst  
**Agent**: Grain Flow Agent (Workflow Orchestration)  
**Status**: Preliminary Design — Awaiting Research Agent Metric Definitions  
**Purpose**: Identify instrumentation points for workflow observability

---

## Overview

This document identifies instrumentation points in the Flow Agent workflow engine to prepare for metric collection. Final implementation will be based on Research Agent's Priority 1 findings (Workflow Observability Metrics).

**Dependencies**:
- Research Agent Priority 1: Workflow Observability Metrics (Week 1-2)
- This design will be refined based on Research Agent's metric definitions

---

## Identified Instrumentation Points

### 1. Workflow Lifecycle Events

**Location**: `src/grain_flow/workflow_engine.zig`

#### Workflow Creation
- **Point**: `WorkflowEngine.create_workflow()`
- **Data Available**:
  - `workflow_id: u32`
  - `name: []const u8`
  - `created_at: u64` (timestamp)
- **Potential Metrics**:
  - Workflows created per time period
  - Workflow creation latency
  - Workflow name length distribution

#### Workflow Execution Start
- **Point**: `WorkflowEngine.execute_workflow()` (line 311-312)
- **Data Available**:
  - `workflow_id: u32`
  - `started_at: u64` (timestamp)
  - `workflow.status` (pending → running)
- **Potential Metrics**:
  - Workflow execution start time
  - Time between creation and execution
  - Concurrent workflow executions

#### Workflow Execution Completion
- **Point**: `WorkflowEngine.execute_workflow()` (line 391-393, 400-402)
- **Data Available**:
  - `workflow_id: u32`
  - `completed_at: u64` (timestamp)
  - `workflow.status` (completed/failed)
  - `processed: u32` (nodes processed)
  - `workflow.?.nodes_len` (total nodes)
- **Potential Metrics**:
  - Workflow execution time (completed_at - started_at)
  - Workflow success/failure rate
  - Nodes processed vs. total nodes
  - Workflow completion status

### 2. Node Execution Events

**Location**: `src/grain_flow/workflow_engine.zig`

#### Node Start
- **Point**: `WorkflowEngine.execute_workflow()` (line 354-356)
- **Data Available**:
  - `node.node_id: u32`
  - `node.agent_id: u32`
  - `node.started_at: u64` (timestamp)
  - `node.status` (pending → running)
  - `workflow_id: u32`
- **Potential Metrics**:
  - Node execution start time
  - Agent usage per workflow
  - Node queue time (time between workflow start and node start)

#### Node Completion
- **Point**: `WorkflowEngine.execute_workflow()` (line 357-365)
- **Data Available**:
  - `node.node_id: u32`
  - `node.agent_id: u32`
  - `node.completed_at: u64` (timestamp)
  - `node.status` (completed)
  - `node.started_at: u64` (for duration calculation)
  - `workflow_id: u32`
- **Potential Metrics**:
  - Node execution duration (completed_at - started_at)
  - Agent execution performance
  - Node success rate

#### Node Failure (Future)
- **Point**: Currently not implemented (node failures not tracked)
- **Potential Data**:
  - `node.error_message` (if failure tracking added)
  - `node.status` (failed)
- **Potential Metrics**:
  - Node failure rate
  - Failure patterns by agent
  - Error message analysis

### 3. Agent Coordination Events

**Location**: `src/grain_flow/agent_coordinator.zig` (referenced by workflow engine)

#### Agent RPC Calls
- **Point**: Agent Coordinator RPC (when nodes execute)
- **Data Available**:
  - `agent_id: u32`
  - RPC request/response timing
  - Success/failure status
- **Potential Metrics**:
  - Agent coordination latency
  - RPC success/failure rate
  - Agent response time

### 4. Event Bus Events

**Location**: `src/grain_flow/event_bus.zig`

#### Workflow Events Published
- **Point**: `WorkflowEngine.execute_workflow()` events (lines 313-318, 360-365, 394-399, 403-408)
- **Event Types**:
  - `workflow_started`
  - `task_completed`
  - `workflow_completed`
  - `workflow_failed`
- **Data Available**:
  - `EventType` enum
  - `workflow_id: u32`
  - `agent_id: u32`
  - `timestamp: u64`
- **Potential Metrics**:
  - Event publication rate
  - Event type distribution
  - Event latency

### 5. DAG Topology Metrics

**Location**: `src/grain_flow/workflow_engine.zig`

#### Workflow Structure
- **Point**: `Workflow.init()`, `Workflow.add_node()`, `Workflow.add_edge()`
- **Data Available**:
  - `workflow.nodes_len: u32`
  - `workflow.edges_len: u32`
  - `in_degree` array (during execution)
  - `ready_count: u32` (ready nodes)
- **Potential Metrics**:
  - Average workflow size (nodes, edges)
  - Workflow depth (longest path)
  - Node fan-in/fan-out distribution
  - Parallelism opportunities (ready nodes count)

### 6. Performance Metrics

**Location**: Throughout workflow execution

#### Execution Performance
- **Calculation Points**: Various timing points in execution
- **Potential Metrics**:
  - Total workflow execution time
  - Per-node execution time
  - Topological sort computation time
  - Event bus overhead
  - Memory usage (if tracked)

---

## Instrumentation Architecture (Preliminary)

### Metric Collection Strategy

**Approach**: Non-invasive instrumentation
- Add metric emission points without changing core workflow logic
- Use optional metric collector interface
- Support multiple metric backends (file, memory, Research Agent)

### Proposed Structure

```
src/grain_flow/workflow_metrics.zig (new module)
├── MetricCollector interface
├── Metric types (Counter, Gauge, Histogram, Summary)
├── Metric emission points
└── Metric storage (bounded buffers)
```

### Metric Storage

**Considerations**:
- Bounded allocations (MAX_METRICS_BUFFER_SIZE)
- Non-blocking metric collection (don't slow down workflows)
- Circular buffer for recent metrics
- Batch export to Research Agent

---

## Implementation Plan (Preliminary)

**Phase 2A: Instrumentation Preparation** (While awaiting research)
- [x] Identify instrumentation points (this document)
- [ ] Design metric collection interface (pending metric definitions)
- [ ] Design metric storage structure (pending metric definitions)

**Phase 2B: Instrumentation Implementation** (After research complete)
- [ ] Implement metric collection module (`workflow_metrics.zig`)
- [ ] Add instrumentation points to workflow engine
- [ ] Add instrumentation points to agent coordinator
- [ ] Implement metric storage and export
- [ ] Add comprehensive tests
- [ ] Update build.zig

**Timeline**: Week 2-3 (after Research Agent Priority 1 delivery)

---

## Questions for Research Agent

Based on this preliminary analysis, I have these questions:

1. **Metric Types**: What metric types should we collect?
   - Counters (events, failures)
   - Gauges (concurrent workflows, active nodes)
   - Histograms (execution times, latencies)
   - Summaries (percentiles, averages)

2. **Metric Aggregation**: How should metrics be aggregated?
   - Per-workflow
   - Per-agent
   - Per-time-window
   - Global statistics

3. **Metric Storage**: What storage format is needed?
   - In-memory buffers
   - File system storage
   - Direct export to Research Agent
   - All of the above

4. **Sampling**: Should we sample metrics or collect all?
   - Full collection (may impact performance)
   - Sampling (lighter weight)
   - Adaptive sampling based on workflow load

5. **Metric Retention**: How long should metrics be retained?
   - Real-time only
   - Historical windows (1 hour, 1 day, 1 week)
   - Permanent storage

---

## Next Steps

1. **Await Research Agent Priority 1**: Workflow Observability Metrics research (Week 1-2)
2. **Refine Design**: Update this design based on Research Agent's findings
3. **Implement Instrumentation**: Phase 2B implementation (Week 2-3)
4. **Build Observatory**: Phase 3 collaboration (Week 3-4)

---

**Status**: Preliminary Design Complete — Ready for Research Agent Input  
**Date**: 2025-12-20-201029-pst  
**Agent**: Grain Flow Agent
