# Flow Agent: ZON Format Integration Preparation Document

**Date**: 2025-12-23-173000-pst  
**Agent**: Grain Flow Agent (9th Agent)  
**Purpose**: Detailed preparation for ZON format integration with Court Agent ZON module

---

## Summary

This document provides detailed preparation for integrating ZON format export into Flow Agent's Workflow Observatory. It maps workflow metrics data structures to ZON format, documents the conversion approach, and prepares for implementation once Court Agent provides the bounded allocation API.

**Status**: Preparation complete, waiting on Court Agent allocator coordination response

---

## Workflow Metrics Data Structure Mapping

### Current JSON Structure

Flow Agent exports workflow metrics in nested JSON structure:

```json
{
  "workflow": {
    "total_executions": 1000,
    "success_rate_percent": 95,
    "failure_rate_percent": 5,
    "avg_execution_time_ms": 150,
    "executions": [
      {
        "workflow_id": 1,
        "name": "workflow1",
        "execution_time_ms": 120,
        "status": "success"
      }
    ]
  },
  "coordination": {
    "total_coordinations": 500,
    "success_rate": 98,
    "avg_latency_ms": 25
  },
  "failures": {
    "total_failures": 50,
    "recovery_rate": 90
  },
  "performance": {
    "avg_queue_depth": 10,
    "avg_wait_time_ms": 50,
    "avg_cpu_percent": 45
  }
}
```

### Proposed ZON Structure

**Option 1: Key-Value Pairs (Simple)**
```
workflow:total_executions:1000
workflow:success_rate_percent:95
workflow:failure_rate_percent:5
workflow:avg_execution_time_ms:150
coordination:total_coordinations:500
coordination:success_rate:98
coordination:avg_latency_ms:25
failures:total_failures:50
failures:recovery_rate:90
performance:avg_queue_depth:10
performance:avg_wait_time_ms:50
performance:avg_cpu_percent:45
```

**Option 2: Tabular Array Format (For Arrays)**
```
workflow:total_executions:1000
workflow:success_rate_percent:95
workflow:failure_rate_percent:5
workflow:avg_execution_time_ms:150
workflow:executions@(3):workflow_id,name,execution_time_ms,status
1,workflow1,120,success
2,workflow2,150,success
3,workflow3,200,failure
coordination:total_coordinations:500
coordination:success_rate:98
coordination:avg_latency_ms:25
failures:total_failures:50
failures:recovery_rate:90
performance:avg_queue_depth:10
performance:avg_wait_time_ms:50
performance:avg_cpu_percent:45
```

**Recommendation**: Use Option 2 (Tabular Array) for `executions` array to maximize token efficiency.

---

## Data Structure Conversion Mapping

### Workflow Metrics (`workflow_metrics.zig`)

**Fields to Convert**:
- `total_executions`: u32 → ZON u32
- `success_rate_percent`: u32 → ZON u32
- `failure_rate_percent`: u32 → ZON u32
- `avg_execution_time_ms`: u64 → ZON u64
- `executions[]`: Array of `WorkflowExecutionRecord` → ZON tabular array

**WorkflowExecutionRecord Fields**:
- `workflow_id`: u32 → ZON u32
- `name`: string → ZON string
- `execution_time_ms`: u64 → ZON u64
- `status`: enum → ZON string ("success" or "failure")

### Coordination Metrics (`agent_coordination_metrics.zig`)

**Fields to Convert**:
- `total_coordinations`: u32 → ZON u32
- `success_rate`: u32 → ZON u32 (percent)
- `avg_latency_ms`: u64 → ZON u64

### Failure Metrics (`failure_pattern_metrics.zig`)

**Fields to Convert**:
- `total_failures`: u32 → ZON u32
- `recovery_rate`: u32 → ZON u32 (percent)

### Performance Metrics (`performance_metrics.zig`)

**Fields to Convert**:
- `avg_queue_depth`: u32 → ZON u32
- `avg_wait_time_ms`: u64 → ZON u64
- `avg_cpu_percent`: u32 → ZON u32 (percent)

---

## Implementation Approach

### Bounded Allocation API (Preferred)

**Court Agent Function** (Requested):
```zig
pub fn encode_tabular_array_zon_bounded(
    key: []const u8,
    field_names: []const []const u8,
    rows: []const []const ZonValue,
    output: []u8,
    output_pos: *u32,
) bool
```

**Flow Agent Implementation Plan**:

1. **Simple Key-Value Pairs**:
   - Use direct ZON encoding for scalar values
   - Format: `key:value\n`
   - Example: `workflow:total_executions:1000\n`

2. **Tabular Arrays**:
   - Use `encode_tabular_array_zon_bounded()` for arrays
   - Convert `WorkflowExecutionRecord[]` to `[]const []const ZonValue`
   - Format: `key@(N):field1,field2\nrow1_val1,row1_val2\nrow2_val1,row2_val2\n`

3. **Nested Objects**:
   - Use dot notation: `workflow.total_executions:1000`
   - Or flatten: `workflow:total_executions:1000`

### Implementation Steps

**Step 1: Convert Scalar Metrics**
```zig
// Convert workflow metrics scalars
const total_executions = collector.total_executions;
// Write: "workflow:total_executions:1000\n"
```

**Step 2: Convert Arrays**
```zig
// Convert executions array to tabular format
const field_names = [_][]const u8{ "workflow_id", "name", "execution_time_ms", "status" };
var rows: [MAX_EXECUTIONS][]const ZonValue = undefined;
// Populate rows from collector.executions
// Call: encode_tabular_array_zon_bounded("workflow:executions", &field_names, &rows, output, &offset)
```

**Step 3: Aggregate All Metrics**
- Write workflow metrics (scalars + array)
- Write coordination metrics (scalars)
- Write failure metrics (scalars)
- Write performance metrics (scalars)

---

## Token Efficiency Estimation

**Current JSON Size** (example):
- Workflow metrics: ~500 bytes
- Coordination metrics: ~150 bytes
- Failure metrics: ~100 bytes
- Performance metrics: ~150 bytes
- **Total**: ~900 bytes

**Expected ZON Size** (35-70% reduction):
- Workflow metrics: ~200-325 bytes (35-60% reduction)
- Coordination metrics: ~50-100 bytes (33-50% reduction)
- Failure metrics: ~30-65 bytes (35-50% reduction)
- Performance metrics: ~50-100 bytes (33-50% reduction)
- **Total**: ~330-590 bytes (35-65% reduction)

**Token Count Reduction**: 35-70% fewer tokens for LLM processing

---

## Integration Points

### WorkflowObservatory Functions

**1. `export_all_metrics_zon()`**:
- Export all metrics in ZON format
- Include all collectors (workflow, coordination, failure, performance)
- Use tabular array format for arrays
- Return bytes written (u32)

**2. `get_aggregated_summary_zon()`**:
- Export aggregated summary in ZON format
- Include only summary statistics (no arrays)
- Use simple key-value pairs
- Return bytes written (u32)

### Dashboard API Integration

**Endpoints to Add**:
- `/api/workflow-observatory/metrics?format=zon`
- `/api/workflow-observatory/summary?format=zon`

**Implementation**:
- Parse `format` query parameter
- Call `export_all_metrics_zon()` or `get_aggregated_summary_zon()` if format=zon
- Set Content-Type: `application/zon` or `text/zon`
- Fallback to JSON if format not specified or invalid

---

## Testing Plan

### Unit Tests

1. **ZON Export Tests**:
   - Test `export_all_metrics_zon()` with sample data
   - Test `get_aggregated_summary_zon()` with sample data
   - Verify ZON format correctness
   - Verify token count reduction

2. **Integration Tests**:
   - Test with Court Agent ZON decoder (round-trip)
   - Test with Research Agent parser
   - Verify data integrity

3. **API Tests**:
   - Test `/api/workflow-observatory/metrics?format=zon`
   - Test `/api/workflow-observatory/summary?format=zon`
   - Test backward compatibility (JSON still works)

### Validation Criteria

- ✅ ZON format is valid (parsable by Court Agent decoder)
- ✅ Token count is 35-70% lower than JSON
- ✅ All metrics are correctly converted
- ✅ Round-trip conversion works (ZON → JSON → ZON)
- ✅ Backward compatibility maintained (JSON export still works)

---

## Dependencies

**Blocking**:
- ⏳ Court Agent: Bounded allocation API (`encode_tabular_array_zon_bounded`)
- ⏳ Court Agent: Allocator coordination response

**Non-Blocking**:
- Research Agent: ZON parser (for validation, not required for implementation)
- Court Agent: ZON module completion (Phase 4 helpers available, ~90% complete)

---

## Timeline

**Estimated Implementation Time**: 3-4 days after Court Agent provides bounded allocation API

**Breakdown**:
- Day 1: Implement `export_all_metrics_zon()` (scalar metrics)
- Day 2: Implement tabular array conversion for `executions` array
- Day 3: Implement `get_aggregated_summary_zon()` and Dashboard API endpoints
- Day 4: Testing, validation, and documentation

---

## References

- **ZON Format Proposal**: `docs/research/zon_format_grain_court_grainscript_proposal_2025-12-20-210116-pst.md`
- **Court Agent Coordination**: `docs/agent-communications/court_to_flow_zon_coordination_2025-12-21-190500-pst.md`
- **Flow Agent Allocator Coordination**: `docs/agent-communications/flow_to_court_zon_allocator_coordination_2025-12-21-210000-pst.md`
- **Court Agent ZON Module**: `src/grain_court/zon_format.zig`
- **Flow Agent Workflow Observatory**: `src/grain_flow/workflow_observatory.zig`

---

**Date**: 2025-12-23-173000-pst  
**Agent**: Grain Flow Agent (9th Agent)  
**Status**: Integration Preparation Complete, Ready for Implementation
