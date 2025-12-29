# Failure Pattern Analysis Phase 1: Analysis Scenarios

**Date**: 2025-12-29-041700-pst  
**Agent**: Grain Research Agent (10th Agent)  
**Status**: Preparation Document — Ready for Phase 1 Analysis  
**Purpose**: Sample analysis scenarios and mock data for Phase 1 failure pattern analysis

---

## Overview

This document provides sample analysis scenarios and mock data structures for Phase 1 of Failure Pattern Analysis Research. These scenarios can be used to:
1. Test analysis functions before Flow Agent data is available
2. Validate analysis methodology
3. Prepare for real data analysis

---

## Sample Analysis Scenarios

### Scenario 1: High Transient Failure Rate

**Description**: System experiencing high transient failures (network issues, timeouts) with good recovery rates.

**Mock Data**:
```json
{
  "failure": {
    "total_failures": 50,
    "recovery_success_rate_percent": 85,
    "failure_type_distribution": {
      "transient": 40,
      "timeout": 8,
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
        "error_message": "Network timeout after 30s",
        "context_data": "{\"workflow_step\":3,\"retry_count\":2}"
      },
      {
        "failure_id": 2,
        "workflow_id": 10,
        "agent_id": 5,
        "failure_type": "transient",
        "timestamp": 1234567891,
        "recovery_status": "succeeded",
        "recovery_time_ms": 300,
        "error_message": "Connection refused",
        "context_data": "{\"endpoint\":\"/api/v1/process\"}"
      }
      // ... 48 more failures
    ]
  }
}
```

**Expected Analysis Results**:
- Transient failure rate: ~80% (40/50)
- Timeout failure rate: ~16% (8/50)
- Permanent failure rate: ~4% (2/50)
- Recovery success rate: 85%
- Most common workflow: Workflow 10 (high failure count)
- Average recovery time: ~400ms

**Analysis Questions**:
1. Why is Workflow 10 experiencing so many transient failures?
2. Are recovery times reasonable (< 1s)?
3. What patterns exist in error messages?
4. Are there specific agents or endpoints causing issues?

---

### Scenario 2: Mixed Failure Types with Low Recovery

**Description**: System with mixed failure types and low recovery success rate, indicating potential systemic issues.

**Mock Data**:
```json
{
  "failure": {
    "total_failures": 30,
    "recovery_success_rate_percent": 40,
    "failure_type_distribution": {
      "transient": 15,
      "permanent": 10,
      "timeout": 5
    },
    "failures": [
      {
        "failure_id": 1,
        "workflow_id": 5,
        "agent_id": 3,
        "failure_type": "permanent",
        "timestamp": 1234567890,
        "recovery_status": "not_applicable",
        "recovery_time_ms": 0,
        "error_message": "Invalid authentication token",
        "context_data": "{\"auth_provider\":\"oauth2\"}"
      },
      {
        "failure_id": 2,
        "workflow_id": 7,
        "agent_id": 2,
        "failure_type": "transient",
        "timestamp": 1234567891,
        "recovery_status": "failed",
        "recovery_time_ms": 2000,
        "error_message": "Database connection pool exhausted",
        "context_data": "{\"db_pool_size\":10,\"active_connections\":10}"
      }
      // ... 28 more failures
    ]
  }
}
```

**Expected Analysis Results**:
- Transient failure rate: 50% (15/30)
- Permanent failure rate: ~33% (10/30)
- Timeout failure rate: ~17% (5/30)
- Recovery success rate: 40% (low)
- Permanent failures: 10 (not recoverable)
- Failed recoveries: ~9 (transient failures that didn't recover)

**Analysis Questions**:
1. Why is recovery success rate so low (40%)?
2. What causes permanent failures (auth issues, invalid input)?
3. Are there resource constraints (DB pool exhausted)?
4. Which workflows need immediate attention?

---

### Scenario 3: Workflow-Specific Failure Patterns

**Description**: Specific workflows experiencing high failure rates, indicating workflow-specific issues.

**Mock Data**:
```json
{
  "failure": {
    "total_failures": 25,
    "recovery_success_rate_percent": 60,
    "failure_type_distribution": {
      "transient": 20,
      "timeout": 5
    },
    "failures": [
      {
        "failure_id": 1,
        "workflow_id": 12,
        "agent_id": 8,
        "failure_type": "transient",
        "timestamp": 1234567890,
        "recovery_status": "succeeded",
        "recovery_time_ms": 800,
        "error_message": "API rate limit exceeded",
        "context_data": "{\"api_provider\":\"external_service\",\"rate_limit\":100}"
      }
      // ... 24 more failures, mostly from workflow_id 12
    ]
  }
}
```

**Expected Analysis Results**:
- Workflow 12: 20 failures (80% of total)
- Workflow 12: High transient failure rate
- Recovery success rate: 60% (moderate)
- Common error: "API rate limit exceeded"
- Average recovery time: ~800ms

**Analysis Questions**:
1. Why is Workflow 12 experiencing so many failures?
2. Is the external API rate limit too restrictive?
3. Can we implement better rate limiting handling?
4. Should we add retry logic with exponential backoff?

---

## Analysis Workflow Examples

### Workflow 1: Overall System Health Check

**Steps**:
1. Parse Flow Agent extended failure metrics export
2. Run `analyze_failure_patterns()` to get failure rates
3. Calculate overall recovery success rate
4. Identify top 5 workflows by failure count
5. Generate summary report

**Code Example**:
```zig
// Parse metrics
var analyzer = WorkflowMetricsAnalyzer.init(allocator);
defer analyzer.deinit();
try analyzer.parse_json_metrics(flow_agent_json_data);

// Get overall patterns
const patterns = analyzer.analyze_failure_patterns();
const recovered = analyzer.get_recovered_failure_count();
const total = patterns.total_failures;
const recovery_rate = if (total > 0) (recovered * 100) / total else 0;

// Generate report
std.debug.print("Total failures: {}\n", .{total});
std.debug.print("Transient: {}%\n", .{patterns.transient_failure_rate_percent});
std.debug.print("Recovery success: {}%\n", .{recovery_rate});
```

---

### Workflow 2: Failure Type Deep Dive

**Steps**:
1. For each failure type (transient, permanent, timeout, unknown):
   - Get count using `get_failure_count_by_type()`
   - Filter failure_data_entries by type
   - Calculate recovery rate for this type
   - Analyze error message patterns
2. Document findings for each type

**Code Example**:
```zig
const FailureType = grain_research.FailureType;

// Analyze transient failures
const transient_count = analyzer.get_failure_count_by_type(.transient);
var transient_recovered: u32 = 0;
for (analyzer.failure_data_entries.items) |entry| {
    if (entry.failure_type == .transient and 
        entry.recovery_status == .succeeded) {
        transient_recovered += 1;
    }
}
const transient_recovery_rate = if (transient_count > 0) 
    (transient_recovered * 100) / transient_count else 0;

std.debug.print("Transient failures: {}\n", .{transient_count});
std.debug.print("Transient recovery rate: {}%\n", .{transient_recovery_rate});
```

---

### Workflow 3: Workflow-Specific Analysis

**Steps**:
1. Get failure count by workflow using `get_failure_count_by_workflow()`
2. For each workflow with failures:
   - Filter failure_data_entries by workflow_id
   - Calculate workflow-specific recovery rate
   - Identify common error messages
   - Analyze recovery times
3. Rank workflows by failure count and recovery rate

**Code Example**:
```zig
// Get workflows with failures
var workflow_failures = std.AutoHashMap(u32, u32).init(allocator);
defer workflow_failures.deinit();

for (analyzer.failure_data_entries.items) |entry| {
    const count = workflow_failures.get(entry.workflow_id) orelse 0;
    try workflow_failures.put(entry.workflow_id, count + 1);
}

// Analyze each workflow
var it = workflow_failures.iterator();
while (it.next()) |entry| {
    const workflow_id = entry.key_ptr.*;
    const failure_count = entry.value_ptr.*;
    const workflow_recovery_rate = analyzer.get_recovery_rate_for_workflow(workflow_id);
    
    std.debug.print("Workflow {}: {} failures, {}% recovery\n", 
        .{workflow_id, failure_count, workflow_recovery_rate});
}
```

---

## Mock Data Generation

### Sample Mock Data Generator

**Purpose**: Generate realistic mock data for testing analysis functions.

**Structure**:
- 50-100 failure entries
- Mix of failure types (transient: 60%, permanent: 20%, timeout: 15%, unknown: 5%)
- Mix of recovery statuses (succeeded: 70%, failed: 15%, not_attempted: 10%, in_progress: 3%, not_applicable: 2%)
- Realistic error messages
- Realistic context data (JSON strings)

**Usage**: Generate mock data, parse with WorkflowMetricsAnalyzer, run analysis functions, validate results.

---

## Validation Checklist

### Before Running Analysis

- [ ] Flow Agent extended failure metrics export received
- [ ] WorkflowMetricsAnalyzer extension complete
- [ ] All 9 required fields parsed correctly
- [ ] RecoveryStatus enum values correct
- [ ] FailureDataEntry structure populated correctly

### During Analysis

- [ ] All analysis functions called correctly
- [ ] Failure rates calculated correctly
- [ ] Recovery rates calculated correctly
- [ ] Workflow-specific analysis complete
- [ ] Error message patterns identified

### After Analysis

- [ ] Analysis report generated
- [ ] Findings documented
- [ ] Recommendations provided
- [ ] Next steps identified

---

## Next Steps

1. **Wait for Flow Agent Data** (1-2 weeks estimated):
   - Receive extended failure metrics export
   - Validate data format
   - Parse with WorkflowMetricsAnalyzer

2. **Run Phase 1 Analysis** (1 week estimated):
   - Execute analysis workflows
   - Generate failure pattern analysis report
   - Document findings

3. **Generate Recommendations** (2-3 days):
   - Identify failure prevention strategies
   - Recommend recovery strategy improvements
   - Suggest workflow reliability improvements

---

**Date**: 2025-12-29-041700-pst  
**Agent**: Grain Research Agent (10th Agent)  
**Status**: Preparation Complete — Ready for Phase 1 Analysis When Flow Agent Data Available
