# Grain Database Agent: Error Types Documentation

**Date**: 2025-12-23-210329-pst  
**Agent**: Grain Silo Agent (Database)  
**Purpose**: Comprehensive error type documentation for database API endpoints

---

## Executive Summary

This document provides comprehensive error type documentation for all database API endpoints. All endpoints return standardized error responses with consistent format, error codes, and HTTP status codes.

**Status**: ✅ **COMPLETE** — All error types documented and standardized

---

## Error Response Format

All error responses follow this standard format:

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": "Additional error details (optional)"
}
```

**HTTP Headers**:
- `Content-Type: application/json`
- `Retry-After: <seconds>` (for rate limit errors)

---

## Error Types

### 1. Validation Error (400 Bad Request)

**HTTP Status**: `400 Bad Request`  
**Error Code**: `validation_error`  
**Retryable**: ❌ No (client error)

**When Returned**:
- Missing required fields (key, value)
- Invalid key format (exceeds MAX_KEY_LEN)
- Invalid value format (exceeds MAX_VALUE_LEN)
- Invalid JSON format in request body
- Invalid query parameters

**Example Response**:
```json
{
  "error": "Missing key or value",
  "code": "validation_error",
  "details": "Request body must contain both 'key' and 'value' fields"
}
```

**Client Handling**:
- Do not retry
- Fix request format and resend
- Check request body format

---

### 2. Authentication Error (401 Unauthorized)

**HTTP Status**: `401 Unauthorized`  
**Error Code**: `authentication_error`  
**Retryable**: ❌ No (client error)

**When Returned**:
- Missing `Authorization` header
- Invalid JWT token format
- Expired JWT token
- Invalid token signature

**Example Response**:
```json
{
  "error": "Authentication required",
  "code": "authentication_error",
  "details": "Missing or invalid Authorization header"
}
```

**Client Handling**:
- Do not retry
- Get new authentication token
- Include `Authorization: Bearer {token}` header

**Note**: This error requires Core Agent coordination for service-to-service authentication (Carry Agent design gap #1).

---

### 3. Authorization Error (403 Forbidden)

**HTTP Status**: `403 Forbidden`  
**Error Code**: `authorization_error`  
**Retryable**: ❌ No (client error)

**When Returned**:
- Valid authentication but insufficient permissions
- User doesn't have access to requested resource
- Operation not allowed for user role

**Example Response**:
```json
{
  "error": "Insufficient permissions",
  "code": "authorization_error",
  "details": "User does not have permission to delete this record"
}
```

**Client Handling**:
- Do not retry
- Check user permissions
- Request appropriate access level

---

### 4. Not Found (404 Not Found)

**HTTP Status**: `404 Not Found`  
**Error Code**: `not_found`  
**Retryable**: ❌ No (client error)

**When Returned**:
- Record ID doesn't exist
- Table doesn't exist
- Node doesn't exist in graph
- Resource not found

**Example Response**:
```json
{
  "error": "Record not found",
  "code": "not_found",
  "details": "Record with ID 12345 does not exist"
}
```

**Client Handling**:
- Do not retry
- Verify resource ID
- Check if resource was deleted

---

### 5. Conflict Error (409 Conflict)

**HTTP Status**: `409 Conflict`  
**Error Code**: `conflict_error`  
**Retryable**: ❌ No (client error)

**When Returned**:
- Record with same key already exists
- Duplicate key violation
- Resource already exists

**Example Response**:
```json
{
  "error": "Record already exists",
  "code": "conflict_error",
  "details": "Record with key 'user:abc123' already exists"
}
```

**Client Handling**:
- Do not retry
- Use GET to retrieve existing record
- Use PUT to update existing record
- Use idempotency key for safe retries

---

### 6. Rate Limit Error (429 Too Many Requests)

**HTTP Status**: `429 Too Many Requests`  
**Error Code**: `rate_limit_error`  
**Retryable**: ✅ Yes (with backoff)

**When Returned**:
- Client exceeds rate limit (requests per minute)
- Too many requests in time window

**Example Response**:
```json
{
  "error": "Too many requests",
  "code": "rate_limit_error",
  "details": "Rate limit exceeded: 100 requests per minute"
}
```

**HTTP Headers**:
- `Retry-After: <seconds>` — Seconds until retry allowed

**Client Handling**:
- ✅ Retry after `Retry-After` seconds
- Implement exponential backoff
- Reduce request rate
- Parse `Retry-After` header for retry timing

**Implementation Status**: ✅ **COMPLETE** (2025-12-23-210329-pst)
- Returns 429 status (via service_unavailable until Core Agent adds 429)
- Includes `Retry-After` header
- Error response includes rate limit information

---

### 7. Internal Server Error (500 Internal Server Error)

**HTTP Status**: `500 Internal Server Error`  
**Error Code**: `internal_error`  
**Retryable**: ✅ Yes (server error)

**When Returned**:
- Database operation failed
- Storage engine error
- Unexpected server error
- Operation timeout (if timeout handling added)

**Example Response**:
```json
{
  "error": "Internal server error",
  "code": "internal_error",
  "details": "Database operation failed"
}
```

**Client Handling**:
- ✅ Retry with exponential backoff
- Log error for debugging
- Report to support if persistent

---

### 8. Service Unavailable (503 Service Unavailable)

**HTTP Status**: `503 Service Unavailable`  
**Error Code**: `service_unavailable`  
**Retryable**: ✅ Yes (server error)

**When Returned**:
- Database service unavailable
- Maintenance mode
- Health check failed
- Circuit breaker open (if implemented)

**Example Response**:
```json
{
  "error": "Service unavailable",
  "code": "service_unavailable",
  "details": "Database service is temporarily unavailable"
}
```

**Client Handling**:
- ✅ Retry with exponential backoff
- Check health endpoint (`GET /api/v1/health`)
- Implement circuit breaker pattern

---

### 9. Gateway Timeout (504 Gateway Timeout)

**HTTP Status**: `504 Gateway Timeout`  
**Error Code**: `timeout_error`  
**Retryable**: ✅ Yes (server error)

**When Returned**:
- Operation exceeded timeout limit
- Long-running query timed out
- Graph traversal timed out

**Example Response**:
```json
{
  "error": "Request timeout",
  "code": "timeout_error",
  "details": "Operation exceeded 30 second timeout"
}
```

**Client Handling**:
- ✅ Retry with exponential backoff
- Reduce query complexity
- Use pagination for large results

**Implementation Status**: ⏳ **PENDING** — Waiting on Core Agent timeout handling coordination (Priority 2, HIGH)

---

## Error Code Enum

For programmatic error handling, use these error codes:

```zig
pub const DatabaseErrorCode = enum {
    validation_error,      // 400
    authentication_error,  // 401
    authorization_error,   // 403
    not_found,             // 404
    conflict_error,        // 409
    rate_limit_error,      // 429
    internal_error,        // 500
    service_unavailable,   // 503
    timeout_error,         // 504
};
```

---

## Retryable vs Non-Retryable Errors

### Non-Retryable Errors (Client Errors)
- `validation_error` (400) — Fix request format
- `authentication_error` (401) — Get new token
- `authorization_error` (403) — Check permissions
- `not_found` (404) — Verify resource exists
- `conflict_error` (409) — Use GET/PUT instead

### Retryable Errors (Server Errors)
- `rate_limit_error` (429) — Retry after `Retry-After` seconds
- `internal_error` (500) — Retry with exponential backoff
- `service_unavailable` (503) — Retry with exponential backoff
- `timeout_error` (504) — Retry with exponential backoff

---

## Error Handling Best Practices

### For Clients (Carry Agent, Bubble Agent, Skate Agent)

1. **Check HTTP Status Code First**:
   - Quick error detection
   - Determine retryability

2. **Parse Error JSON for Details**:
   - Get error code for programmatic handling
   - Get error message for user display
   - Get details for debugging

3. **Implement Retry Logic**:
   - Only retry retryable errors (429, 500, 503, 504)
   - Use exponential backoff
   - Respect `Retry-After` header for 429 errors
   - Maximum retry attempts (e.g., 3)

4. **Handle Rate Limiting**:
   - Parse `Retry-After` header
   - Wait specified seconds before retry
   - Reduce request rate if rate limited frequently

5. **Handle Authentication Errors**:
   - Refresh authentication token
   - Re-authenticate if token expired
   - Do not retry without new token

---

## Endpoint-Specific Error Details

### Key-Value Storage Endpoints

**POST `/api/v1/records`**:
- `validation_error` (400): Missing key or value
- `conflict_error` (409): Record with key already exists
- `authentication_error` (401): Missing or invalid token
- `rate_limit_error` (429): Rate limit exceeded

**GET `/api/v1/records/{id}`**:
- `not_found` (404): Record ID doesn't exist
- `validation_error` (400): Invalid record ID format

**PUT `/api/v1/records/{id}`**:
- `not_found` (404): Record ID doesn't exist
- `validation_error` (400): Missing value or invalid format
- `authentication_error` (401): Missing or invalid token
- `rate_limit_error` (429): Rate limit exceeded

**DELETE `/api/v1/records/{id}`**:
- `not_found` (404): Record ID doesn't exist
- `authentication_error` (401): Missing or invalid token
- `rate_limit_error` (429): Rate limit exceeded

### Relational Query Endpoints

**POST `/api/v1/query`**:
- `validation_error` (400): Invalid SQL query
- `timeout_error` (504): Query exceeded timeout
- `authentication_error` (401): Missing or invalid token
- `rate_limit_error` (429): Rate limit exceeded

### Graph Operation Endpoints

**POST `/api/v1/graph/traverse`**:
- `validation_error` (400): Invalid traversal parameters
- `not_found` (404): Start node doesn't exist
- `timeout_error` (504): Traversal exceeded timeout
- `authentication_error` (401): Missing or invalid token
- `rate_limit_error` (429): Rate limit exceeded

### Full-Text Search Endpoints

**GET `/api/v1/search`**:
- `validation_error` (400): Missing search query
- `timeout_error` (504): Search exceeded timeout
- `rate_limit_error` (429): Rate limit exceeded

### Health Check Endpoint

**GET `/api/v1/health`**:
- `service_unavailable` (503): Database unhealthy
- Always returns 200 OK if healthy

---

## Error Examples

### Example 1: Validation Error
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "Missing key or value",
  "code": "validation_error",
  "details": "Request body must contain both 'key' and 'value' fields"
}
```

### Example 2: Rate Limit Error
```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
Retry-After: 45

{
  "error": "Too many requests",
  "code": "rate_limit_error",
  "details": "Rate limit exceeded: 100 requests per minute"
}
```

### Example 3: Not Found Error
```http
HTTP/1.1 404 Not Found
Content-Type: application/json

{
  "error": "Record not found",
  "code": "not_found",
  "details": "Record with ID 12345 does not exist"
}
```

### Example 4: Conflict Error
```http
HTTP/1.1 409 Conflict
Content-Type: application/json

{
  "error": "Record already exists",
  "code": "conflict_error",
  "details": "Record with key 'user:abc123' already exists"
}
```

---

## Implementation Status

**Completed**:
- ✅ Error response format standardized
- ✅ Error codes defined
- ✅ HTTP status codes mapped
- ✅ Retryable vs non-retryable documented
- ✅ Rate limit error (429) with Retry-After header
- ✅ Error examples provided

**Pending**:
- ⏳ Timeout error (504) — Waiting on Core Agent timeout handling coordination
- ⏳ Core Agent 429 status code support — Currently using 503 with Retry-After header

---

## Coordination Notes

**Core Agent Coordination Needed**:
- Add `too_many_requests` (429) to `HttpStatus` enum in `api_server.zig`
- Add timeout handling pattern for database operations
- Service-to-service authentication token management

**Client Agent Notes**:
- Carry Agent: Error handling format aligned with this documentation
- Bubble Agent: Can use this for error handling patterns
- Skate Agent: Can use this for error handling patterns

---

**Date**: 2025-12-23-210329-pst  
**Agent**: Grain Silo Agent (Database)  
**Status**: Error types documented and standardized
