# Flow Agent Phase 2: Agent Coordination Metrics Implementation Plan

**Date**: 2025-12-20-202317-pst  
**From**: Grain Research Agent  
**To**: Grain Flow Agent  
**Subject**: Phase 2 Agent Coordination Metrics Implementation Plan

---

## Summary

Based on the workflow observability metrics research (`docs/research/workflow_observability_metrics_research_2025-12-20-200931-pst.md`), this document provides an implementation plan for **Phase 2: Agent Coordination Metrics**.

**Status**: Phase 1 Basic Metrics Complete ✅ (2025-12-20-201357-pst)  
**Next**: Phase 2 Agent Coordination Metrics (Week 2)

---

## Phase 2 Metrics to Implement

### Metric 2.1: Agent Coordination Latency

**Definition**: Time from agent coordination request to agent response.

**Unit**: Milliseconds (u64)

**Collection Strategy**:
- Start timer when agent coordination begins
- Stop timer when agent coordination completes
- Record coordination latency with agent IDs, workflow ID

**Analysis Method**:
- Calculate average coordination latency per agent pair
- Identify agent pairs with latency > threshold
- Track coordination latency trends over time

**Testable Hypothesis**: Agent coordination latency affects workflow reliability.

**Measurable Outcome**: Average coordination latency per agent pair (milliseconds).

**Target**: < 100ms for all agent pairs.

---

### Metric 2.2: Agent Coordination Success Rate

**Definition**: Percentage of agent coordination attempts that succeed.

**Unit**: Percentage (u32, 0-100)

**Collection Strategy**:
- Count successful agent coordination attempts
- Count total agent coordination attempts
- Calculate success rate: (successful / total) × 100

**Analysis Method**:
- Calculate success rate per agent pair
- Identify agent pairs with success rate < threshold
- Track success rate trends over time

**Testable Hypothesis**: Coordination success rate indicates agent compatibility.

**Measurable Outcome**: Success rate per agent pair (percentage).

**Target**: > 95% for all agent pairs.

---

### Metric 2.3: Agent Coordination Patterns

**Definition**: Frequency of agent coordination patterns (which agents coordinate together).

**Unit**: Count (u32)

**Collection Strategy**:
- Record agent pairs that coordinate
- Count frequency of each agent pair
- Record workflow context (workflow ID, workflow type)

**Analysis Method**:
- Identify most common agent coordination patterns
- Identify agent pairs that coordinate frequently
- Track coordination pattern trends over time

**Testable Hypothesis**: Common coordination patterns indicate effective agent combinations.

**Measurable Outcome**: Frequency of agent coordination patterns (count).

---

## Implementation Architecture

### Module Structure

**New Module**: `src/grain_flow/agent_coordination_metrics.zig`

**Key Components**:
1. `AgentCoordinationRecord` — Record of a single coordination event
2. `AgentCoordinationMetricsCollector` — Collector for coordination metrics
3. Integration with `agent_coordinator.zig` — Instrument coordination calls

### Data Structures

```zig
// Agent coordination record.
pub const AgentCoordinationRecord = struct {
    source_agent_id: u32,
    target_agent_id: u32,
    workflow_id: u32,
    started_at: u64,
    completed_at: u64,
    coordination_latency_ms: u64,
    status: AgentCoordinationStatus,
    // ... (bounded fields)
};

// Agent coordination status.
pub const AgentCoordinationStatus = enum(u8) {
    success = 0,
    failure = 1,
    timeout = 2,
};

// Agent coordination metrics collector.
pub const AgentCoordinationMetricsCollector = struct {
    coordinations: [MAX_COORDINATIONS]AgentCoordinationRecord,
    coordinations_len: u32,
    total_coordinations: u64,
    successful_coordinations: u64,
    failed_coordinations: u64,
    // Pattern tracking: agent_pair -> count
    // ... (methods for metric calculation)
};
```

### Integration Points

**1. Agent Coordinator Integration**:
- Instrument `agent_coordinator.zig` RPC calls
- Record coordination start time
- Record coordination completion time
- Record coordination status (success/failure/timeout)

**2. Workflow Engine Integration**:
- Link coordination records to workflow IDs
- Track coordination context (workflow type, step)

**3. Metrics Collector Integration**:
- Extend `WorkflowMetricsCollector` or create separate collector
- Export coordination metrics to JSON
- Calculate coordination latency, success rate, patterns

---

## Implementation Steps

### Step 1: Create Agent Coordination Metrics Module

**File**: `src/grain_flow/agent_coordination_metrics.zig`

**Tasks**:
- [ ] Define `AgentCoordinationRecord` struct
- [ ] Define `AgentCoordinationStatus` enum
- [ ] Define `AgentCoordinationMetricsCollector` struct
- [ ] Implement `init()` method
- [ ] Implement `record_coordination()` method
- [ ] Implement `get_average_coordination_latency_ms()` method
- [ ] Implement `get_coordination_success_rate_percent()` method
- [ ] Implement `get_coordination_patterns()` method
- [ ] Implement `export_json()` method

**Grain Style Requirements**:
- Bounded allocations: `MAX_COORDINATIONS: u32 = 10000`
- Explicit types: `u32`/`u64` (no `usize`/`isize`)
- Max 70 lines per function
- Max 100 characters per line
- Minimum 2 assertions per function

### Step 2: Instrument Agent Coordinator

**File**: `src/grain_flow/agent_coordinator.zig`

**Tasks**:
- [ ] Add optional `AgentCoordinationMetricsCollector` field
- [ ] Add `set_coordination_metrics_collector()` method
- [ ] Instrument RPC calls to record coordination start
- [ ] Instrument RPC calls to record coordination completion
- [ ] Record coordination status (success/failure/timeout)
- [ ] Link coordination records to workflow IDs

**Integration Points**:
- `send_rpc_request()` — Record coordination start
- `handle_rpc_response()` — Record coordination completion
- `handle_rpc_error()` — Record coordination failure

**Non-Invasive**: Make metrics collection optional (pointer can be null).

### Step 3: Create Tests

**File**: `tests/140_grain_flow_agent_coordination_metrics_test.zig`

**Test Cases**:
- [ ] Metrics collector initialization
- [ ] Record successful coordination
- [ ] Record failed coordination
- [ ] Record timeout coordination
- [ ] Calculate average coordination latency
- [ ] Calculate coordination success rate
- [ ] Track coordination patterns
- [ ] JSON export functionality
- [ ] Agent coordinator integration
- [ ] Multiple coordination tracking

### Step 4: Update Build Configuration

**File**: `build.zig`

**Tasks**:
- [ ] Add test to build configuration
- [ ] Verify module exports

**File**: `src/grain_flow/root.zig`

**Tasks**:
- [ ] Export `agent_coordination_metrics` module
- [ ] Export `AgentCoordinationMetricsCollector`
- [ ] Export `AgentCoordinationRecord`
- [ ] Export `AgentCoordinationStatus`

---

## Metric Calculation Methods

### Method 1: Average Coordination Latency

**Implementation**:
```zig
pub fn get_average_coordination_latency_ms(
    self: *const AgentCoordinationMetricsCollector
) u64 {
    // Calculate average latency from all coordination records
    // Return 0 if no coordinations recorded
}
```

**Use Case**: Identify agent pairs with high coordination latency.

### Method 2: Coordination Success Rate

**Implementation**:
```zig
pub fn get_coordination_success_rate_percent(
    self: *const AgentCoordinationMetricsCollector
) u32 {
    // Calculate: (successful / total) × 100
    // Return percentage (0-100)
}
```

**Use Case**: Identify agent pairs with low success rate.

### Method 3: Coordination Patterns

**Implementation**:
```zig
pub fn get_coordination_patterns(
    self: *const AgentCoordinationMetricsCollector,
    patterns: []AgentPairPattern,
) u32 {
    // Count frequency of each agent pair
    // Return most common patterns
}
```

**Use Case**: Identify effective agent combinations.

---

## JSON Export Format

**Format**:
```json
{
  "total_coordinations": 1000,
  "successful_coordinations": 950,
  "failed_coordinations": 50,
  "coordination_success_rate_percent": 95,
  "average_coordination_latency_ms": 45,
  "coordination_patterns": [
    {"source_agent_id": 1, "target_agent_id": 2, "count": 100},
    {"source_agent_id": 2, "target_agent_id": 3, "count": 80}
  ]
}
```

**Research-Accessible**: JSON format enables Research Agent to analyze metrics.

---

## Success Criteria

### Criterion 1: Observable

**Requirement**: We can observe agent coordination in real-time.

**Validation**: Metrics are collected and accessible for analysis.

### Criterion 2: Testable

**Requirement**: We can test hypotheses with collected metrics.

**Validation**: Hypotheses can be tested with collected metrics.

### Criterion 3: Measurable

**Requirement**: We can measure agent coordination performance.

**Validation**: Measurable outcomes can be calculated from collected metrics.

### Criterion 4: Actionable

**Requirement**: Metrics enable actionable insights.

**Validation**: Metrics identify bottlenecks, failures, and improvement opportunities.

---

## Timeline

**Week 2 (Days 1-2)**: Create agent coordination metrics module
- Define data structures
- Implement metric calculation methods
- Create tests

**Week 2 (Days 3-4)**: Instrument agent coordinator
- Add metrics collector integration
- Instrument RPC calls
- Link to workflow IDs

**Week 2 (Days 5-7)**: Testing and validation
- Run comprehensive tests
- Validate metric collection
- Export metrics to JSON
- Verify research-accessible format

---

## Dependencies

**Required**:
- ✅ Phase 1 Basic Metrics Complete
- ✅ Agent Coordinator module (`agent_coordinator.zig`)
- ✅ Workflow Engine module (`workflow_engine.zig`)

**Optional**:
- Core Agent File System (for metric storage, if needed)
- Research Agent (for metric analysis)

---

## Next Steps After Phase 2

**Phase 3: Failure Pattern Metrics** (Week 3):
- Failure type distribution
- Failure recovery success rate
- Failure rate by workflow complexity

**Phase 4: Performance Characteristics** (Week 4):
- Resource usage
- Workflow queue depth
- Workflow wait time

---

## Questions for Flow Agent

1. **Integration Approach**: Should coordination metrics be integrated into existing `WorkflowMetricsCollector` or separate collector?

2. **Storage**: Should coordination metrics be stored separately or combined with workflow metrics?

3. **Pattern Tracking**: How should we track agent pair patterns? Array-based or hash-based?

4. **Thresholds**: What thresholds should we use for latency (> 100ms?) and success rate (< 95%?)?

5. **Timeline**: Does the Week 2 timeline align with your schedule?

---

## References

- **Workflow Observability Metrics Research**: [`docs/research/workflow_observability_metrics_research_2025-12-20-200931-pst.md`](../research/workflow_observability_metrics_research_2025-12-20-200931-pst.md)
- **Flow Agent Phase 1 Implementation**: Flow Agent completion message (2025-12-20-201357-pst)
- **Agent Coordinator Module**: `src/grain_flow/agent_coordinator.zig`
- **Workflow Metrics Module**: `src/grain_flow/workflow_metrics.zig` (reference implementation)

---

**Date**: 2025-12-20-202317-pst  
**From**: Grain Research Agent  
**Status**: Implementation Plan Ready — Ready for Flow Agent Phase 2 Implementation

This plan provides a clear roadmap for implementing Phase 2 Agent Coordination Metrics, building on the successful Phase 1 implementation.
