# Grain Flow Dashboard API Documentation

**Last Updated**: 2025-12-28-224600-pst  
**Agent**: Grain Flow Agent (9th Agent)  
**Module**: `src/grain_flow/dashboard_api.zig`

---

## Overview

The Dashboard API provides HTTP endpoints for accessing Workflow Observatory metrics data. The API supports both JSON and ZON (Zero Overhead Notation) formats for efficient data exchange with LLMs and other consumers.

**Base Path**: `/api/workflow-observatory`

**Integration**: Integrates with Core Agent's API Server to expose observatory data.

---

## Endpoints

### 1. Get Aggregated Summary

**Endpoint**: `GET /api/workflow-observatory/summary`

**Description**: Returns aggregated summary metrics from all collectors (workflow, coordination, failure, performance). Includes only summary statistics (no detailed execution records).

**Query Parameters**:
- `format` (optional): Output format. Valid values:
  - `json` (default): JSON format
  - `zon`: ZON format (35-70% more token-efficient)

**Response Format**: 
- JSON (default): `application/json`
- ZON: `text/plain; charset=utf-8`

**Example Requests**:
```
GET /api/workflow-observatory/summary
GET /api/workflow-observatory/summary?format=json
GET /api/workflow-observatory/summary?format=zon
```

**Example JSON Response**:
```json
{
  "workflow": {
    "total_executions": 1000,
    "success_rate_percent": 95,
    "failure_rate_percent": 5,
    "avg_execution_time_ms": 150
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

**Example ZON Response**:
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

**Status Codes**:
- `200 OK`: Success
- `400 Bad Request`: Invalid format parameter
- `500 Internal Server Error`: Server error

---

### 2. Get All Metrics

**Endpoint**: `GET /api/workflow-observatory/metrics`

**Description**: Returns all metrics from all collectors, including detailed execution records. This endpoint provides complete observability data including individual workflow execution records.

**Query Parameters**:
- `format` (optional): Output format. Valid values:
  - `json` (default): JSON format
  - `zon`: ZON format (35-70% more token-efficient)

**Response Format**: 
- JSON (default): `application/json`
- ZON: `text/plain; charset=utf-8`

**Example Requests**:
```
GET /api/workflow-observatory/metrics
GET /api/workflow-observatory/metrics?format=json
GET /api/workflow-observatory/metrics?format=zon
```

**Example JSON Response**:
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
      },
      {
        "workflow_id": 2,
        "name": "workflow2",
        "execution_time_ms": 180,
        "status": "failure"
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

**Example ZON Response**:
```
workflow:total_executions:1000
workflow:success_rate_percent:95
workflow:failure_rate_percent:5
workflow:avg_execution_time_ms:150
workflow:executions@(3):workflow_id,name,execution_time_ms,status
1,workflow1,120,success
2,workflow2,180,failure
coordination:total_coordinations:500
coordination:success_rate:98
coordination:avg_latency_ms:25
failures:total_failures:50
failures:recovery_rate:90
performance:avg_queue_depth:10
performance:avg_wait_time_ms:50
performance:avg_cpu_percent:45
```

**Status Codes**:
- `200 OK`: Success
- `400 Bad Request`: Invalid format parameter
- `500 Internal Server Error`: Server error

---

## Format Selection

### JSON Format (Default)

**Content-Type**: `application/json`

**Use Cases**:
- Human-readable debugging
- Standard API integrations
- Tools that expect JSON

**Characteristics**:
- Readable and familiar format
- Standard JSON structure
- Larger payload size (more tokens for LLMs)

### ZON Format

**Content-Type**: `text/plain; charset=utf-8`

**Use Cases**:
- LLM communication (35-70% token reduction)
- High-volume data exchange
- Cost-sensitive applications

**Characteristics**:
- Compact notation (key:value pairs, tabular arrays)
- 35-70% smaller than JSON (token count)
- More efficient for LLM processing

**ZON Format Specification**:
- Key-value pairs: `key:value`
- Tabular arrays: `key@(N):field1,field2,...` followed by rows
- String values: Plain text (no quotes)
- Numeric values: Plain numbers (no quotes)
- See `docs/research/zon_format_grain_court_grainscript_proposal_2025-12-20-210116-pst.md` for full specification

---

## Implementation Details

### Code Location

**Dashboard API Module**: `src/grain_flow/dashboard_api.zig`  
**Workflow Observatory Module**: `src/grain_flow/workflow_observatory.zig`

### Key Functions

- `handle_summary_request()`: Handles `/summary` endpoint requests
- `handle_metrics_request()`: Handles `/metrics` endpoint requests
- `get_query_param()`: Parses query string parameters
- `export_all_metrics_json()`: Exports all metrics in JSON format
- `export_all_metrics_zon()`: Exports all metrics in ZON format
- `get_aggregated_summary()`: Gets aggregated summary in JSON format
- `get_aggregated_summary_zon()`: Gets aggregated summary in ZON format

### Response Size Limits

- **Max JSON Response Size**: 10MB (`MAX_JSON_RESPONSE_SIZE: u32 = 10_485_760`)
- **Max ZON Response Size**: 10MB (`MAX_ZON_RESPONSE_SIZE: u32 = 10_485_760`)

---

## Integration with Core Agent

The Dashboard API integrates with Core Agent's API Server:

1. **Registration**: Dashboard API endpoints are registered with Core Agent's API Server
2. **Request Handling**: Core Agent routes requests to Dashboard API handlers
3. **Response Format**: Dashboard API generates responses in requested format (JSON/ZON)
4. **Content-Type**: Appropriate headers set based on format

---

## Usage Examples

### Using JSON Format

```bash
# Get summary in JSON format (default)
curl http://localhost:8080/api/workflow-observatory/summary

# Get all metrics in JSON format (default)
curl http://localhost:8080/api/workflow-observatory/metrics

# Explicitly request JSON format
curl http://localhost:8080/api/workflow-observatory/summary?format=json
```

### Using ZON Format

```bash
# Get summary in ZON format
curl http://localhost:8080/api/workflow-observatory/summary?format=zon

# Get all metrics in ZON format
curl http://localhost:8080/api/workflow-observatory/metrics?format=zon
```

### Parsing ZON Format

For LLM consumption, ZON format can be parsed by Court Agent's ZON decoder:

```zig
const decode_result = try grain_court.ZonFormat.decode_zon(zon_data, allocator);
defer decode_result.deinit();
// Access decoded key-value pairs
for (decode_result.pairs) |pair| {
    std.debug.print("{}: {}\n", .{ pair.key, pair.value });
}
```

---

## Backward Compatibility

The API maintains backward compatibility:

- **Default Format**: JSON (if `format` parameter not specified)
- **Existing Integrations**: Continue to work without changes
- **New Integrations**: Can opt-in to ZON format for efficiency

---

## References

- **ZON Format Proposal**: `docs/research/zon_format_grain_court_grainscript_proposal_2025-12-20-210116-pst.md`
- **ZON Integration Preparation**: `docs/agent-communications/flow_zon_integration_preparation_2025-12-23-173000-pst.md`
- **ZON Integration Completion Report**: `docs/agent-communications/flow_to_core_zon_integration_completion_2025-12-28-224500-pst.md`
- **Dashboard API Module**: `src/grain_flow/dashboard_api.zig`
- **Workflow Observatory Module**: `src/grain_flow/workflow_observatory.zig`

---

**Date**: 2025-12-28-224600-pst  
**Agent**: Grain Flow Agent (9th Agent)  
**Status**: API Documentation Complete
