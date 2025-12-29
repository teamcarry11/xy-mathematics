# Grain Silo Agent: Database API Contracts for Carry Agent

**Date**: 2025-12-21-143409-pst (Updated: 2025-12-29-002000-pst)  
**From**: Grain Silo Agent (Database)  
**To**: Grain Carry Agent (Mobile Framework)  
**Purpose**: Document database API contracts for mobile app integration

**Related Documents**:
- Error Types Documentation: `docs/agent-communications/silo_agent_error_types_documentation_2025-12-23-210329-pst.md`
- Integration Response: `docs/agent-communications/silo_agent_carry_integration_response_2025-12-23-194454-pst.md`
- Circuit Breaker Pattern: `docs/grain_database/circuit_breaker_pattern.md`

---

## Overview

This document provides the database API contract specifications for Carry Agent's mobile app integration. The database provides REST API endpoints for key-value storage, relational queries, graph operations, and full-text search.

**Base URL**: `/api/v1` (via Grain Core Agent's API Server)

**Authentication**: JWT tokens required for write operations (POST, PUT, DELETE). Read operations (GET) may be public depending on endpoint.

---

## API Endpoints

### Key-Value Storage Endpoints

#### 1. Get Record by ID
**Endpoint**: `GET /api/v1/records/{id}`  
**Authentication**: Not required  
**Path Parameters**:
- `id` (u64): Record ID

**Response** (200 OK):
```json
{
  "id": 123,
  "key": "user:123",
  "value": "{\"user_id\":123,\"email\":\"user@example.com\",\"username\":\"user\"}"
}
```

**Error Responses**:
- `404 Not Found`: Record not found
- `400 Bad Request`: Invalid record ID format

---

#### 2. Create Record
**Endpoint**: `POST /api/v1/records`  
**Authentication**: Required (JWT token)  
**Request Body**:
```json
{
  "key": "user:123",
  "value": "{\"user_id\":123,\"email\":\"user@example.com\",\"username\":\"user\"}"
}
```

**Response** (201 Created):
```json
{
  "id": 123,
  "key": "user:123",
  "value": "{\"user_id\":123,\"email\":\"user@example.com\",\"username\":\"user\"}"
}
```

**Error Responses**:
- `400 Bad Request`: Invalid request body, missing key/value, key too long, value too long
- `409 Conflict`: Record with key already exists
- `401 Unauthorized`: Missing or invalid JWT token
- `429 Too Many Requests`: Rate limit exceeded (includes `Retry-After` header)

**Idempotency**:
- Include `Idempotency-Key` header for safe retries
- If idempotency key matches existing request, returns existing record (200 OK)
- Idempotency keys cached for 1 hour

**Constraints**:
- Key length: Max 256 bytes (`MAX_KEY_LEN`)
- Value length: Max 1 MB (`MAX_VALUE_LEN`)

---

#### 3. Update Record
**Endpoint**: `PUT /api/v1/records/{id}`  
**Authentication**: Required (JWT token)  
**Path Parameters**:
- `id` (u64): Record ID

**Request Body**:
```json
{
  "key": "user:123",
  "value": "{\"user_id\":123,\"email\":\"user@example.com\",\"username\":\"updated_user\"}"
}
```

**Response** (200 OK):
```json
{
  "id": 123,
  "key": "user:123",
  "value": "{\"user_id\":123,\"email\":\"user@example.com\",\"username\":\"updated_user\"}"
}
```

**Error Responses**:
- `404 Not Found`: Record not found
- `400 Bad Request`: Invalid request body, missing key/value, key too long, value too long
- `401 Unauthorized`: Missing or invalid JWT token

---

#### 4. Delete Record
**Endpoint**: `DELETE /api/v1/records/{id}`  
**Authentication**: Required (JWT token)  
**Path Parameters**:
- `id` (u64): Record ID

**Response** (204 No Content): Empty body

**Error Responses**:
- `404 Not Found`: Record not found
- `401 Unauthorized`: Missing or invalid JWT token

---

### Relational Query Endpoints

#### 5. List Tables
**Endpoint**: `GET /api/v1/tables`  
**Authentication**: Not required  
**Response** (200 OK):
```json
{
  "tables": [
    {
      "name": "users",
      "columns": [
        {"name": "id", "type": "integer"},
        {"name": "email", "type": "text"},
        {"name": "username", "type": "text"},
        {"name": "created_at", "type": "timestamp"}
      ]
    }
  ]
}
```

---

#### 6. Execute Query
**Endpoint**: `POST /api/v1/query`  
**Authentication**: Required (JWT token)  
**Request Body**:
```json
{
  "query": "SELECT * FROM users WHERE email = ?",
  "params": ["user@example.com"]
}
```

**Response** (200 OK):
```json
{
  "columns": ["id", "email", "username", "created_at"],
  "rows": [
    [123, "user@example.com", "user", "2025-12-21T14:34:09Z"]
  ]
}
```

**Error Responses**:
- `400 Bad Request`: Invalid query syntax, missing query/params
- `401 Unauthorized`: Missing or invalid JWT token
- `500 Internal Server Error`: Query execution error

**Supported Query Types**:
- SELECT (with WHERE, JOIN, ORDER BY, LIMIT)
- INSERT
- UPDATE
- DELETE

---

### Graph Operation Endpoints

#### 7. Get Graph Node
**Endpoint**: `GET /api/v1/graph/nodes/{id}`  
**Authentication**: Not required  
**Path Parameters**:
- `id` (u64): Node ID

**Response** (200 OK):
```json
{
  "id": 123,
  "data": "{\"type\":\"user\",\"name\":\"User Name\"}",
  "edges": [
    {"target": 456, "type": "follows"},
    {"target": 789, "type": "likes"}
  ]
}
```

**Error Responses**:
- `404 Not Found`: Node not found
- `400 Bad Request`: Invalid node ID format

---

#### 8. Traverse Graph
**Endpoint**: `POST /api/v1/graph/traverse`  
**Authentication**: Required (JWT token)  
**Request Body**:
```json
{
  "start_node_id": 123,
  "traversal_type": "bfs",
  "max_depth": 3,
  "edge_filter": "follows"
}
```

**Response** (200 OK):
```json
{
  "nodes": [
    {"id": 123, "data": "{\"type\":\"user\"}"},
    {"id": 456, "data": "{\"type\":\"user\"}"},
    {"id": 789, "data": "{\"type\":\"user\"}"}
  ],
  "edges": [
    {"source": 123, "target": 456, "type": "follows"},
    {"source": 456, "target": 789, "type": "follows"}
  ]
}
```

**Error Responses**:
- `400 Bad Request`: Invalid request body, missing start_node_id, invalid traversal_type
- `404 Not Found`: Start node not found
- `401 Unauthorized`: Missing or invalid JWT token

**Traversal Types**:
- `bfs`: Breadth-First Search
- `dfs`: Depth-First Search

---

### Full-Text Search Endpoints

#### 9. Full-Text Search
**Endpoint**: `GET /api/v1/search?q={query}&limit={limit}`  
**Authentication**: Not required  
**Query Parameters**:
- `q` (string): Search query
- `limit` (u32, optional): Maximum results (default: 10, max: 100)

**Response** (200 OK):
```json
{
  "query": "policy topic",
  "results": [
    {
      "document_id": 123,
      "score": 0.95,
      "snippet": "This document discusses policy topics..."
    },
    {
      "document_id": 456,
      "score": 0.87,
      "snippet": "Another document about policy topics..."
    }
  ],
  "total": 2
}
```

**Error Responses**:
- `400 Bad Request`: Missing query parameter, invalid limit
- `500 Internal Server Error`: Search execution error

---

## Request/Response Format

### Request Headers
- `Content-Type`: `application/json` (required for POST/PUT)
- `Authorization`: `Bearer {jwt_token}` (required for authenticated endpoints)
- `Idempotency-Key`: `{unique_key}` (optional, for safe retries on create operations)

### Response Headers
- `Content-Type`: `application/json`
- `Retry-After`: `<seconds>` (for 429 rate limit errors)
- `X-Request-ID`: Request tracking ID (optional)

### Error Response Format
```json
{
  "error": {
    "code": 404,
    "message": "Record not found",
    "details": "Record with ID 123 does not exist"
  }
}
```

---

## Data Constraints

### Key-Value Storage
- **Max Key Length**: 256 bytes (`MAX_KEY_LEN`)
- **Max Value Length**: 1 MB (`MAX_VALUE_LEN`)
- **Max Records**: 1,000,000 (`MAX_RECORDS`)

### Graph Operations
- **Max Nodes**: 100,000 (`MAX_NODES`)
- **Max Edges**: 1,000,000 (`MAX_EDGES`)
- **Max Edges Per Node**: 1,000 (`MAX_EDGES_PER_NODE`)
- **Max Traversal Depth**: 10 (`MAX_TRAVERSAL_DEPTH`)

### Query Operations
- **Max Query Length**: 4 KB
- **Max Parameters**: 100
- **Max Results**: 10,000 rows

### Full-Text Search
- **Max Query Length**: 256 bytes
- **Max Results**: 100 (`limit` parameter)

---

## User Data Schema (Recommended)

For mobile app user storage, we recommend using the key-value storage endpoints with the following schema:

**Key Format**: `user:{user_id}`

**Value Format** (JSON):
```json
{
  "user_id": 123,
  "email": "user@example.com",
  "username": "user",
  "password_hash": "...",
  "created_at": "2025-12-21T14:34:09Z",
  "updated_at": "2025-12-21T14:34:09Z"
}
```

**Alternative**: Use relational query endpoints with a `users` table:
```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

---

## Integration Notes

### For Carry Agent

1. **User Storage**: Use key-value endpoints (`/api/v1/records`) with key format `user:{user_id}` or relational endpoints (`/api/v1/query`) with `users` table.

2. **Authentication**: All write operations require JWT token in `Authorization` header. Get JWT token from Grain Core Agent's Authentication Service (Phase 60).

3. **Error Handling**: Check response status codes and parse error JSON for detailed error messages. See error types documentation for complete error handling guide.

4. **Rate Limiting**: API enforces rate limits (100 requests per minute default). Returns `429 Too Many Requests` with `Retry-After` header when limit exceeded. Parse `Retry-After` header and wait before retry.

5. **Idempotency**: Use `Idempotency-Key` header for safe retries on create operations. If key matches existing request, returns existing record (200 OK) instead of creating duplicate.

6. **Request Deduplication**: Duplicate requests (same method, path, body) within 5 seconds return cached response automatically.

7. **Async Operations**: Coordinate with Core Agent on async HTTP response handling pattern for database operations (1-2 days remaining).

8. **Error Types**: See `docs/agent-communications/silo_agent_error_types_documentation_2025-12-23-210329-pst.md` for comprehensive error type documentation.

9. **HTTP Client Timeout/Error Handling**: ✅ **READY NOW** (Core Agent implementation complete 2025-12-28-235609-pst)
   - Use Core Agent's HTTP client with `timeout_ms` parameter (30s default for API calls)
   - Use structured error unions (`HttpClientError` enum) with retryability classification
   - See "HTTP Client Integration" section below for details

---

## HTTP Client Integration (Core Agent)

**Status**: ✅ **READY FOR INTEGRATION** (2025-12-28-235609-pst)

Core Agent has implemented HTTP/WebSocket timeout and error handling. Use these patterns when making requests to the database API.

### Timeout Handling

**HTTP Client Timeout**:
- Set `timeout_ms: ?u32` parameter when creating requests
- Default timeouts:
  - API calls: `DEFAULT_API_TIMEOUT_MS` (30 seconds)
  - Content fetching: `DEFAULT_CONTENT_TIMEOUT_MS` (60 seconds)
- Use `is_timed_out()` function to check for timeouts
- Handle `HttpTimeoutError` from Core Agent's HTTP client

**Example**:
```zig
const request = try http_client.create_request(
    "GET",
    "/api/v1/records/123",
    null, // body
    DEFAULT_API_TIMEOUT_MS, // timeout_ms: 30 seconds
);
```

**WebSocket Timeout** (if using WebSocket):
- Set `connect_timeout_ms: 10000` (10 seconds) for connections
- Set `message_timeout_ms: 5000` (5 seconds) for message sending
- Use `is_connect_timed_out()` and `is_message_timed_out()` functions

### Error Handling

**Structured Error Unions**:
- Core Agent HTTP client returns `HttpClientError!HttpResponse`
- Error types: `timeout`, `network_error`, `dns_error`, `connection_refused`, `rate_limit`, `server_error`, `invalid_response`
- Use retryability classification: `is_http_error_retryable()`
- Use error message helpers: `get_http_error_message()`

**Retryable Errors**:
- `network_error` — Retry with exponential backoff
- `timeout` — Retry with exponential backoff
- `rate_limit` — Retry after `Retry-After` header seconds
- `server_error` (5xx) — Retry with exponential backoff

**Non-Retryable Errors**:
- `dns_error` — Fix DNS configuration
- `connection_refused` — Check service availability
- `invalid_response` — Fix request format

**Example**:
```zig
const response = http_client.send_request(request) catch |err| {
    switch (err) {
        error.timeout => {
            // Retry with exponential backoff
            return handle_retry();
        },
        error.rate_limit => {
            // Parse Retry-After header and wait
            return handle_rate_limit();
        },
        error.network_error => {
            // Retry with exponential backoff
            return handle_retry();
        },
        else => {
            // Non-retryable error
            return err;
        },
    }
};
```

**Mapping to Database Error Types**:
- Core Agent `HttpClientError.timeout` → Database `timeout_error` (504)
- Core Agent `HttpClientError.rate_limit` → Database `rate_limit_error` (429)
- Core Agent `HttpClientError.server_error` → Database `internal_error` (500)
- Core Agent `HttpClientError.network_error` → Database `service_unavailable` (503)

### Integration Best Practices

1. **Always Set Timeout**: Use `DEFAULT_API_TIMEOUT_MS` for API calls
2. **Handle Errors Properly**: Use structured error unions, not generic `anyerror`
3. **Check Retryability**: Use `is_http_error_retryable()` before retrying
4. **Respect Rate Limits**: Parse `Retry-After` header for 429 responses
5. **Use Circuit Breaker**: Monitor health endpoint for fault tolerance

**Key Resources**:
- Core Agent HTTP Client: `src/grain_core/http_client.zig`
- Core Agent Error Types: `src/grain_core/http_errors.zig`
- Core Agent WebSocket: `src/grain_core/websocket.zig`
- Core Agent WebSocket Errors: `src/grain_core/websocket_errors.zig`

---

## Next Steps

1. **Carry Agent**: Review API contracts and confirm endpoint paths match your expectations
2. **Silo Agent**: Implement endpoint handlers when API Server integration is ready
3. **Core Agent**: Coordinate on async HTTP response handling pattern
4. **Both Agents**: Test end-to-end flow with actual database connection

---

## Questions or Coordination Needed?

If you have questions about:
- Endpoint paths or formats
- Request/response schemas
- Error handling
- Data constraints
- Integration patterns

Please coordinate via Core Agent or update your coordination file (`docs/core-coordination/core-coordination_carry.md`).

---

**Date**: 2025-12-21-143409-pst (Updated: 2025-12-29-002000-pst)  
**Agent**: Grain Silo Agent  
**Status**: API Contracts Documented — HTTP/WebSocket Timeout/Error Handling Ready for Integration ✅
