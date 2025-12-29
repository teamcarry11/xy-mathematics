# WorkflowMetricsAnalyzer Extension Plan

**Date**: 2025-12-29-041147-pst  
**Agent**: Grain Research Agent (10th Agent)  
**Status**: Extension Plan Documented — Ready for Implementation  
**Dependencies**: Flow Agent extended failure metrics export (1-2 weeks estimated)

---

## Overview

This document outlines the plan to extend `WorkflowMetricsAnalyzer` to parse detailed failure entries from Flow Agent's extended failure metrics export. The extension will enable Phase 1 of Failure Pattern Analysis Research.

---

## Current Implementation

### Current `parse_failure_metrics()` Function

**Location**: `src/grain_research/workflow_metrics_analyzer.zig:284`

**Current Capabilities**:
- Parses `failure_type_distribution` object
- Creates `FailurePatternMetric` entries with limited data (failure_type, workflow_id=0, recovered=false, timestamp=0)
- Does not parse individual failure entries

**Current Structure**:
```zig
pub const FailurePatternMetric = struct {
    failure_type: FailureType,
    workflow_id: u32,
    recovered: bool,
    timestamp: u64,
};
```

---

## Required Extension

### 1. Add New Types

**Location**: `src/grain_research/workflow_metrics_analyzer.zig` (after line 69)

**Add RecoveryStatus Enum**:
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

**Add FailureDataEntry Structure**:
```zig
// Bounded: Max error message length.
pub const MAX_ERROR_MESSAGE_LEN: u32 = 1024;

// Bounded: Max context data length.
pub const MAX_CONTEXT_DATA_LEN: u32 = 10_240; // 10KB

// Failure data entry (detailed failure information).
pub const FailureDataEntry = struct {
    failure_id: u32,
    workflow_id: u32,
    agent_id: u32,
    failure_type: FailureType,
    timestamp: u64,
    recovery_status: RecoveryStatus,
    recovery_time_ms: u64,
    error_message: [MAX_ERROR_MESSAGE_LEN:0]u8,
    error_message_len: u32,
    context_data: [MAX_CONTEXT_DATA_LEN:0]u8,
    context_data_len: u32,
};
```

### 2. Extend WorkflowMetricsAnalyzer Structure

**Location**: `src/grain_research/workflow_metrics_analyzer.zig:81` (add after line 86)

**Add Failure Data Entries List**:
```zig
// Workflow metrics analyzer.
pub const WorkflowMetricsAnalyzer = struct {
    allocator: std.mem.Allocator,
    workflow_executions: std.ArrayListUnmanaged(WorkflowExecutionMetric),
    coordination_metrics: std.ArrayListUnmanaged(AgentCoordinationMetric),
    failure_metrics: std.ArrayListUnmanaged(FailurePatternMetric),
    performance_metrics: std.ArrayListUnmanaged(PerformanceMetric),
    failure_data_entries: std.ArrayListUnmanaged(FailureDataEntry), // NEW
    coordination_success_rate_percent: u32,
    // ...
};
```

**Update `init()` Function**:
```zig
pub fn init(allocator: std.mem.Allocator) WorkflowMetricsAnalyzer {
    // ...
    return WorkflowMetricsAnalyzer{
        // ...
        .failure_data_entries = .{}, // NEW
        // ...
    };
}
```

**Update `deinit()` Function**:
```zig
pub fn deinit(self: *WorkflowMetricsAnalyzer) void {
    // ...
    self.failure_data_entries.deinit(self.allocator); // NEW
    // ...
}
```

### 3. Extend `parse_failure_metrics()` Function

**Location**: `src/grain_research/workflow_metrics_analyzer.zig:284`

**Add Parsing for `failures` Array** (after existing failure_type_distribution parsing):

```zig
fn parse_failure_metrics(
    self: *WorkflowMetricsAnalyzer,
    failure_val: std.json.Value,
) !void {
    std.debug.assert(failure_val == .object);

    const failure_obj = failure_val.object;

    // Parse failure type distribution (existing code).
    if (failure_obj.get("failure_type_distribution")) |types_val| {
        // ... existing code ...
    }

    // NEW: Parse detailed failure entries.
    if (failure_obj.get("failures")) |failures_val| {
        if (failures_val == .array) {
            const failures_array = failures_val.array;
            var i: u32 = 0;
            while (i < failures_array.items.len and
                i < MAX_METRIC_ENTRIES) : (i += 1)
            {
                const failure_entry_val = failures_array.items[i];
                if (failure_entry_val == .object) {
                    const entry_obj = failure_entry_val.object;
                    var entry = FailureDataEntry{
                        .failure_id = 0,
                        .workflow_id = 0,
                        .agent_id = 0,
                        .failure_type = .unknown,
                        .timestamp = 0,
                        .recovery_status = .not_attempted,
                        .recovery_time_ms = 0,
                        .error_message = [_]u8{0} ** MAX_ERROR_MESSAGE_LEN,
                        .error_message_len = 0,
                        .context_data = [_]u8{0} ** MAX_CONTEXT_DATA_LEN,
                        .context_data_len = 0,
                    };

                    // Parse failure_id.
                    if (entry_obj.get("failure_id")) |id_val| {
                        if (id_val == .integer) {
                            entry.failure_id = @intCast(id_val.integer);
                        }
                    }

                    // Parse workflow_id.
                    if (entry_obj.get("workflow_id")) |wf_id_val| {
                        if (wf_id_val == .integer) {
                            entry.workflow_id = @intCast(wf_id_val.integer);
                        }
                    }

                    // Parse agent_id.
                    if (entry_obj.get("agent_id")) |agent_id_val| {
                        if (agent_id_val == .integer) {
                            entry.agent_id = @intCast(agent_id_val.integer);
                        }
                    }

                    // Parse failure_type.
                    if (entry_obj.get("failure_type")) |type_val| {
                        if (type_val == .string) {
                            entry.failure_type = parse_failure_type(type_val.string);
                        }
                    }

                    // Parse timestamp.
                    if (entry_obj.get("timestamp")) |ts_val| {
                        if (ts_val == .integer) {
                            entry.timestamp = @intCast(ts_val.integer);
                        }
                    }

                    // Parse recovery_status.
                    if (entry_obj.get("recovery_status")) |status_val| {
                        if (status_val == .string) {
                            entry.recovery_status = parse_recovery_status(status_val.string);
                        }
                    }

                    // Parse recovery_time_ms.
                    if (entry_obj.get("recovery_time_ms")) |rt_val| {
                        if (rt_val == .integer) {
                            entry.recovery_time_ms = @intCast(rt_val.integer);
                        }
                    }

                    // Parse error_message.
                    if (entry_obj.get("error_message")) |err_msg_val| {
                        if (err_msg_val == .string) {
                            const err_msg = err_msg_val.string;
                            const copy_len = @min(err_msg.len, MAX_ERROR_MESSAGE_LEN);
                            @memcpy(entry.error_message[0..copy_len], err_msg[0..copy_len]);
                            entry.error_message_len = copy_len;
                        }
                    }

                    // Parse context_data.
                    if (entry_obj.get("context_data")) |ctx_val| {
                        if (ctx_val == .string) {
                            const ctx_data = ctx_val.string;
                            const copy_len = @min(ctx_data.len, MAX_CONTEXT_DATA_LEN);
                            @memcpy(entry.context_data[0..copy_len], ctx_data[0..copy_len]);
                            entry.context_data_len = copy_len;
                        }
                    }

                    try self.failure_data_entries.append(self.allocator, entry);
                }
            }
        }
    }
}
```

### 4. Add Helper Functions

**Location**: `src/grain_research/workflow_metrics_analyzer.zig` (after `parse_failure_type()`)

**Add `parse_recovery_status()` Function**:
```zig
// Parse recovery status from string.
fn parse_recovery_status(status_str: []const u8) RecoveryStatus {
    std.debug.assert(status_str.len > 0);

    if (std.mem.eql(u8, status_str, "succeeded")) {
        return .succeeded;
    } else if (std.mem.eql(u8, status_str, "failed")) {
        return .failed;
    } else if (std.mem.eql(u8, status_str, "in_progress")) {
        return .in_progress;
    } else if (std.mem.eql(u8, status_str, "not_applicable")) {
        return .not_applicable;
    } else {
        return .not_attempted;
    }
}
```

### 5. Update Failure Pattern Analysis Functions

**Location**: `src/grain_research/workflow_metrics_analyzer.zig` (existing functions)

**Enhancement**: The existing failure pattern analysis functions (`analyze_failure_patterns()`, `get_failure_count_by_type()`, etc.) can use `failure_data_entries` for more detailed analysis once the data is available.

**Note**: Current functions work with `failure_metrics` (basic data). Future enhancements can use `failure_data_entries` for detailed analysis.

---

## Implementation Steps

### Step 1: Add Types and Structures (1-2 hours)
- Add `RecoveryStatus` enum
- Add `FailureDataEntry` structure
- Add bounded constants (`MAX_ERROR_MESSAGE_LEN`, `MAX_CONTEXT_DATA_LEN`)

### Step 2: Extend WorkflowMetricsAnalyzer (1 hour)
- Add `failure_data_entries` list to struct
- Update `init()` and `deinit()` functions

### Step 3: Extend Parser (2-3 hours)
- Add `failures` array parsing to `parse_failure_metrics()`
- Add `parse_recovery_status()` helper function
- Test with mock JSON data

### Step 4: Testing (1-2 hours)
- Create test cases for extended format
- Test with sample Flow Agent export format
- Validate error handling and bounds checking

**Total Estimated Time**: 5-8 hours (1 day)

---

## Testing Strategy

### Test Cases

1. **Parse Extended Format**:
   - Test parsing `failures` array with all fields populated
   - Test parsing `failures` array with missing optional fields
   - Test parsing empty `failures` array

2. **Bounds Checking**:
   - Test error_message exceeding MAX_ERROR_MESSAGE_LEN
   - Test context_data exceeding MAX_CONTEXT_DATA_LEN
   - Test failures array exceeding MAX_METRIC_ENTRIES

3. **Recovery Status Parsing**:
   - Test all recovery status values ("succeeded", "failed", "in_progress", "not_applicable", "not_attempted")
   - Test invalid recovery status values (default to "not_attempted")

4. **Backward Compatibility**:
   - Test parsing format without `failures` array (existing format)
   - Test parsing format with both `failure_type_distribution` and `failures` array

---

## Integration with Failure Pattern Analysis

### Phase 1: Data Collection (Current)
- Parse extended failure metrics from Flow Agent
- Store detailed failure entries in `failure_data_entries`
- Ready for analysis

### Phase 2: Analysis (Future)
- Use `failure_data_entries` for detailed pattern analysis
- Analyze recovery strategies
- Identify common failure modes
- Generate insights and recommendations

---

## Dependencies

### Flow Agent
- **Status**: ⏳ Implementation in progress (1-2 weeks estimated)
- **Required**: Extended failure metrics export with `failures` array
- **Format**: JSON format as specified in coordination confirmation

### Research Agent
- **Status**: ⏳ Extension plan ready
- **Action**: Implement extension once Flow Agent export is available
- **Timeline**: 1 day implementation after Flow Agent completion

---

## References

- **Failure Data Schema**: `docs/research/failure_data_schema_2025-12-28-224000-pst.md`
- **Failure Pattern Analysis Research**: `docs/research/failure_pattern_analysis_research_2025-12-28-223816-pst.md`
- **Failure Pattern Analysis Methodology**: `docs/research/failure_pattern_analysis_methodology_2025-12-29-001544-pst.md`
- **Flow Agent Coordination**: `docs/agent-communications/research_to_flow_failure_data_collection_confirmation_2025-12-29-041147-pst.md`
- **WorkflowMetricsAnalyzer**: `src/grain_research/workflow_metrics_analyzer.zig`

---

**Date**: 2025-12-29-041147-pst  
**Agent**: Grain Research Agent (10th Agent)  
**Status**: Extension Plan Documented ✅ — Ready for Implementation When Flow Agent Export Available
