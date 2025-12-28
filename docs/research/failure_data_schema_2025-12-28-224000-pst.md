# Failure Data Schema Design

**Date**: 2025-12-28-224000-pst  
**Agent**: Grain Research Agent (10th Agent)  
**Status**: Phase 1 (Failure Data Collection) - Schema Design Complete  
**Related**: Failure Pattern Analysis Research (`docs/research/failure_pattern_analysis_research_2025-12-28-223816-pst.md`)

---

## Overview

This document defines the failure data schema for collecting and analyzing failure patterns in workflow execution. The schema is designed to support Phase 1 of the Failure Pattern Analysis Research.

---

## Schema Design

### Core Failure Data Structure

```zig
// Failure data entry.
pub const FailureDataEntry = struct {
    failure_id: u32,
    workflow_id: u32,
    agent_id: u32,
    failure_type: FailureType,
    timestamp: u64,
    recovery_status: RecoveryStatus,
    recovery_time_ms: u64,
    error_message: []const u8,
    context_data: []const u8,
};
```

### Failure Type Classification

```zig
// Failure type enum (matches WorkflowMetricsAnalyzer).
pub const FailureType = enum(u8) {
    transient = 0,    // Recoverable failures (network, timeout)
    permanent = 1,    // Non-recoverable failures (invalid input, auth error)
    timeout = 2,      // Timeout failures
    unknown = 3,      // Unknown failure type
};
```

### Recovery Status

```zig
// Recovery status.
pub const RecoveryStatus = enum(u8) {
    not_attempted = 0,    // No recovery attempted
    in_progress = 1,      // Recovery in progress
    succeeded = 2,        // Recovery succeeded
    failed = 3,           // Recovery failed
    not_applicable = 4,   // Recovery not applicable (permanent failure)
};
```

---

## Data Collection Approach

### From Flow Agent

**Current Format**: Flow Agent exports failure metrics in JSON format:
```json
{
  "failure": {
    "total_failures": 7,
    "recovery_success_rate_percent": 80,
    "failure_type_distribution": {
      "transient": 5,
      "permanent": 2
    }
  }
}
```

**Extended Format Needed** (for detailed analysis):
```json
{
  "failure": {
    "total_failures": 7,
    "recovery_success_rate_percent": 80,
    "failure_type_distribution": {
      "transient": 5,
      "permanent": 2
    },
    "failures": [
      {
        "failure_id": 1,
        "workflow_id": 10,
        "agent_id": 5,
        "failure_type": "transient",
        "timestamp": 1234567890,
        "recovery_status": "succeeded",
        "recovery_time_ms": 500,
        "error_message": "Network timeout",
        "context_data": "..."
      }
    ]
  }
}
```

### Integration with WorkflowMetricsAnalyzer

The existing `WorkflowMetricsAnalyzer` already supports:
- `FailurePatternMetric` structure (failure_type, workflow_id, recovered, timestamp)
- `parse_failure_metrics()` function
- Failure pattern analysis functions (`analyze_failure_patterns()`, etc.)

**Enhancement Needed**:
- Extend `parse_failure_metrics()` to parse detailed failure entries
- Add support for recovery status and recovery time tracking
- Add support for error message and context data

---

## Data Collection Strategy

### Phase 1: Basic Collection (Current)

**Status**: ✅ **READY** — WorkflowMetricsAnalyzer already supports basic failure metrics

**Data Collected**:
- Failure type distribution (transient, permanent, timeout, unknown)
- Recovery success rate percentage
- Total failure count

**Limitations**:
- No individual failure details
- No recovery time tracking
- No error message tracking

### Phase 2: Enhanced Collection (Proposed)

**Status**: ⏳ **PENDING** — Requires Flow Agent coordination

**Data to Collect**:
- Individual failure entries with full details
- Recovery status per failure
- Recovery time per failure
- Error messages
- Context data (workflow state, agent state, etc.)

**Coordination Needed**:
- Flow Agent: Extend failure metrics export to include detailed failure entries
- Flow Agent: Add recovery status and recovery time tracking
- Flow Agent: Add error message and context data collection

---

## Schema Validation

### Bounded Allocations

```zig
// Bounded: Max failure entries.
pub const MAX_FAILURE_ENTRIES: u32 = 100_000;

// Bounded: Max error message length.
pub const MAX_ERROR_MESSAGE_LEN: u32 = 1024;

// Bounded: Max context data length.
pub const MAX_CONTEXT_DATA_LEN: u32 = 10_240; // 10KB
```

### Validation Rules

1. **Failure ID**: Must be unique, sequential (1, 2, 3, ...)
2. **Workflow ID**: Must reference existing workflow
3. **Agent ID**: Must reference existing agent (1-11)
4. **Timestamp**: Must be valid Unix timestamp (nanoseconds)
5. **Recovery Time**: Must be <= MAX_RECOVERY_TIME_MS (300,000ms = 5 minutes)
6. **Error Message**: Must be <= MAX_ERROR_MESSAGE_LEN
7. **Context Data**: Must be <= MAX_CONTEXT_DATA_LEN

---

## Integration Points

### With Flow Agent

**Current**: Flow Agent exports failure metrics in JSON format
**Proposed**: Flow Agent extends export to include detailed failure entries

**Coordination Message Needed**:
- Request Flow Agent to extend failure metrics export
- Specify schema requirements
- Coordinate on data collection approach

### With WorkflowMetricsAnalyzer

**Current**: WorkflowMetricsAnalyzer parses basic failure metrics
**Proposed**: Extend WorkflowMetricsAnalyzer to parse detailed failure entries

**Enhancement**:
- Extend `parse_failure_metrics()` to parse detailed entries
- Add `FailureDataEntry` structure
- Add recovery status and recovery time tracking

---

## Next Steps

1. **Coordinate with Flow Agent** (Priority: HIGH)
   - Request extended failure metrics export format
   - Specify schema requirements
   - Coordinate on data collection approach

2. **Extend WorkflowMetricsAnalyzer** (Priority: MEDIUM)
   - Add `FailureDataEntry` structure
   - Extend `parse_failure_metrics()` to parse detailed entries
   - Add recovery status and recovery time tracking

3. **Create Failure Data Collection Module** (Priority: MEDIUM)
   - Create `src/grain_research/failure_data_collection.zig`
   - Implement failure data collection from Flow Agent
   - Implement failure data storage and query

4. **Test Failure Data Collection** (Priority: LOW)
   - Create tests for failure data collection
   - Validate schema parsing
   - Test with sample Flow Agent data

---

## References

- **Failure Pattern Analysis Research**: `docs/research/failure_pattern_analysis_research_2025-12-28-223816-pst.md`
- **WorkflowMetricsAnalyzer**: `src/grain_research/workflow_metrics_analyzer.zig`
- **Flow Agent Coordination**: `docs/core-coordination/core-coordination_research.md`

---

**Date**: 2025-12-28-224000-pst  
**Agent**: Grain Research Agent  
**Status**: Schema Design Complete — Ready for Flow Agent Coordination
