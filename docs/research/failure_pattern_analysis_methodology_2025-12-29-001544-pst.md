# Failure Pattern Analysis Methodology

**Date**: 2025-12-29-001544-pst  
**Agent**: Grain Research Agent (10th Agent)  
**Status**: Phase 1 Task 3 — Analysis Methodology Documented  
**Dependencies**: WorkflowMetricsAnalyzer (extended functions ready), Flow Agent (failure data pending)

---

## Overview

This document describes the methodology for analyzing failure patterns using the extended `WorkflowMetricsAnalyzer` functions. The analysis will be performed once Flow Agent provides extended failure metrics export.

---

## Analysis Functions Available

### 1. `analyze_failure_patterns()`

**Purpose**: Calculate failure rates by type across all failure metrics.

**Returns**: `FailurePatternAnalysis` structure with:
- `transient_failure_rate_percent`: Percentage of transient failures
- `permanent_failure_rate_percent`: Percentage of permanent failures
- `timeout_failure_rate_percent`: Percentage of timeout failures
- `unknown_failure_rate_percent`: Percentage of unknown failures
- `total_failures`: Total number of failures analyzed

**Usage**:
```zig
const analysis = analyzer.analyze_failure_patterns();
// analysis.transient_failure_rate_percent: 45%
// analysis.permanent_failure_rate_percent: 20%
// analysis.timeout_failure_rate_percent: 30%
// analysis.unknown_failure_rate_percent: 5%
```

### 2. `get_failure_count_by_type(failure_type: FailureType)`

**Purpose**: Get count of failures for a specific failure type.

**Parameters**:
- `failure_type`: `.transient`, `.permanent`, `.timeout`, or `.unknown`

**Returns**: `u32` count of failures of the specified type.

**Usage**:
```zig
const transient_count = analyzer.get_failure_count_by_type(.transient);
const timeout_count = analyzer.get_failure_count_by_type(.timeout);
```

### 3. `get_recovered_failure_count()`

**Purpose**: Get count of failures that were successfully recovered.

**Returns**: `u32` count of recovered failures.

**Usage**:
```zig
const recovered_count = analyzer.get_recovered_failure_count();
```

### 4. `get_unrecovered_failure_count()`

**Purpose**: Get count of failures that were not recovered.

**Returns**: `u32` count of unrecovered failures.

**Usage**:
```zig
const unrecovered_count = analyzer.get_unrecovered_failure_count();
```

### 5. `get_failure_count_by_workflow(workflow_id: u32)`

**Purpose**: Get count of failures for a specific workflow.

**Parameters**:
- `workflow_id`: Workflow ID to analyze

**Returns**: `u32` count of failures for the specified workflow.

**Usage**:
```zig
const workflow_1_failures = analyzer.get_failure_count_by_workflow(1);
```

---

## Analysis Methodology

### Step 1: Load Failure Data

1. Receive extended failure metrics JSON from Flow Agent
2. Parse JSON using `WorkflowMetricsAnalyzer.parse_json_metrics()`
3. Verify failure metrics are loaded: `analyzer.get_failure_count_by_type(.transient) + ...`

### Step 2: Overall Failure Pattern Analysis

1. Run `analyze_failure_patterns()` to get failure rates by type
2. Calculate recovery success rate:
   - `recovered_count = get_recovered_failure_count()`
   - `total_failures = analyze_failure_patterns().total_failures`
   - `recovery_success_rate = (recovered_count * 100) / total_failures`
3. Document findings:
   - Which failure type is most common?
   - What percentage of failures are recoverable?
   - What is the overall recovery success rate?

### Step 3: Failure Type Deep Dive

For each failure type (transient, permanent, timeout, unknown):

1. Get count: `get_failure_count_by_type(failure_type)`
2. Calculate percentage: `(count * 100) / total_failures`
3. Analyze recovery rate for this type:
   - Filter failures by type and check recovery status
   - Calculate type-specific recovery success rate
4. Document characteristics:
   - Frequency of occurrence
   - Recovery success rate
   - Common workflows affected

### Step 4: Workflow-Specific Analysis

For each workflow with failures:

1. Get failure count: `get_failure_count_by_workflow(workflow_id)`
2. Identify failure types for this workflow
3. Calculate workflow-specific recovery rate
4. Document:
   - Which workflows are most failure-prone?
   - Which workflows have highest recovery success?
   - Which workflows need attention?

### Step 5: Recovery Strategy Analysis

1. Compare recovered vs. unrecovered failures:
   - `recovered_count = get_recovered_failure_count()`
   - `unrecovered_count = get_unrecovered_failure_count()`
2. Analyze recovery patterns:
   - Which failure types recover most successfully?
   - Which workflows recover most successfully?
   - What are the characteristics of unrecovered failures?
3. Document recovery strategy effectiveness

---

## Expected Analysis Output

### Failure Pattern Analysis Report Structure

1. **Executive Summary**:
   - Total failures analyzed
   - Overall failure rate by type
   - Overall recovery success rate

2. **Failure Type Distribution**:
   - Transient failures: count, percentage, recovery rate
   - Permanent failures: count, percentage, recovery rate
   - Timeout failures: count, percentage, recovery rate
   - Unknown failures: count, percentage, recovery rate

3. **Recovery Analysis**:
   - Total recovered failures
   - Total unrecovered failures
   - Recovery success rate by failure type
   - Recovery success rate by workflow

4. **Workflow Analysis**:
   - Top 10 workflows by failure count
   - Workflows with highest recovery success
   - Workflows needing attention

5. **Recommendations**:
   - Failure prevention strategies
   - Recovery strategy improvements
   - Workflow reliability improvements

---

## Integration with Flow Agent Data

Once Flow Agent provides extended failure metrics export with the following fields:
- `failure_id`: Unique failure identifier
- `workflow_id`: Workflow that failed
- `agent_id`: Agent involved in failure
- `failure_type`: Type of failure (transient, permanent, timeout, unknown)
- `timestamp`: When failure occurred
- `recovery_status`: Recovery status (not_attempted, in_progress, succeeded, failed, not_applicable)
- `recovery_time_ms`: Time taken to recover (if recovered)
- `error_message`: Error message (if available)
- `context_data`: Additional context (if available)

The analysis will:
1. Parse the extended failure metrics JSON
2. Populate `WorkflowMetricsAnalyzer.failure_metrics` with detailed data
3. Run all analysis functions
4. Generate comprehensive failure pattern analysis report

---

## Next Steps

1. ⏳ **Wait for Flow Agent extended failure metrics export** (1-2 weeks estimated)
2. ⏳ **Parse and load failure data** using `WorkflowMetricsAnalyzer.parse_json_metrics()`
3. ⏳ **Run analysis functions** to generate failure pattern analysis
4. ⏳ **Generate failure pattern analysis report** with findings and recommendations
5. ⏳ **Proceed to Phase 2: Failure Classification** based on analysis findings

---

## Status

**Current**: Analysis methodology documented, ready for Flow Agent data  
**Blocked by**: Flow Agent extended failure metrics export (assessment in progress)  
**Independent Work**: Can create sample analysis with mock data to validate methodology
