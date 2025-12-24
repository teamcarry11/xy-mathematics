# Grain Database Agent: Circuit Breaker Pattern Usage

**Date**: 2025-12-23-220000-pst  
**Agent**: Grain Silo Agent (Database)  
**Purpose**: Document how client agents (Carry, Bubble, Skate) can implement circuit breaker pattern using the database health check endpoint

---

## Overview

The circuit breaker pattern prevents cascading failures when the database is overloaded or unavailable. Client agents can use the health check endpoint (`GET /api/v1/health`) to implement circuit breaker logic.

**Benefits**:
- Prevents cascading failures when database is down
- Reduces resource waste from repeated failed requests
- Automatic recovery when database becomes healthy
- Better user experience with graceful degradation

---

## Health Check Endpoint

**Endpoint**: `GET /api/v1/health`  
**Method**: GET  
**Authentication**: Not required (public endpoint)

### Response Format

**Healthy Response** (200 OK):
```json
{
  "status": "healthy",
  "record_count": 12345
}
```

**Unhealthy Response** (503 Service Unavailable):
```json
{
  "status": "unhealthy",
  "message": "Database context not initialized"
}
```

### Response Fields

- `status` (string): `"healthy"` or `"unhealthy"`
- `record_count` (number, optional): Number of records in database (only present when healthy)
- `message` (string, optional): Error message (only present when unhealthy)

---

## Circuit Breaker States

### 1. **Closed State** (Normal Operation)
- All requests proceed normally
- Health check passes
- Monitor failure rate

### 2. **Open State** (Circuit Open)
- All requests fail immediately (no database calls)
- Health check fails or failure threshold exceeded
- Return cached responses or error immediately
- Wait for recovery timeout before attempting to close

### 3. **Half-Open State** (Testing Recovery)
- Allow limited requests to test if database recovered
- If health check passes, transition to Closed
- If health check fails, transition back to Open

---

## Implementation Recommendations

### Thresholds

**Failure Threshold**: 5 consecutive failures  
- After 5 consecutive failures, open circuit

**Recovery Timeout**: 30 seconds  
- Wait 30 seconds before attempting half-open state

**Success Threshold**: 2 consecutive successes  
- After 2 consecutive successful health checks, close circuit

**Health Check Interval**: 5 seconds  
- Check health every 5 seconds when circuit is open

### State Machine

```
Closed → (5 failures) → Open → (30s timeout) → Half-Open → (2 successes) → Closed
                                                      ↓
                                              (1 failure) → Open
```

---

## Example Implementation Pattern

### Pseudocode

```zig
const CircuitBreaker = struct {
    state: State,
    failure_count: u32,
    success_count: u32,
    last_failure_time: u64,
    recovery_timeout: u64,
    
    const State = enum {
        closed,
        open,
        half_open,
    };
    
    fn check_health(self: *CircuitBreaker) bool {
        // Call GET /api/v1/health
        // Return true if healthy, false if unhealthy
    }
    
    fn should_allow_request(self: *CircuitBreaker) bool {
        switch (self.state) {
            .closed => return true,
            .open => {
                const now = get_current_time();
                if (now - self.last_failure_time > self.recovery_timeout) {
                    self.state = .half_open;
                    self.success_count = 0;
                    return true; // Allow one test request
                }
                return false; // Block requests
            },
            .half_open => return true, // Allow limited requests
        }
    }
    
    fn record_success(self: *CircuitBreaker) void {
        switch (self.state) {
            .closed => {
                self.failure_count = 0;
            },
            .half_open => {
                self.success_count += 1;
                if (self.success_count >= 2) {
                    self.state = .closed;
                    self.failure_count = 0;
                }
            },
            .open => {}, // Should not happen
        }
    }
    
    fn record_failure(self: *CircuitBreaker) void {
        switch (self.state) {
            .closed => {
                self.failure_count += 1;
                if (self.failure_count >= 5) {
                    self.state = .open;
                    self.last_failure_time = get_current_time();
                }
            },
            .half_open => {
                self.state = .open;
                self.last_failure_time = get_current_time();
                self.success_count = 0;
            },
            .open => {}, // Already open
        }
    }
};
```

---

## Integration with Database Requests

### Request Flow

1. **Check Circuit State**:
   - If `open`: Return error immediately (no database call)
   - If `closed` or `half_open`: Proceed to step 2

2. **Make Database Request**:
   - Call database endpoint
   - Record success or failure

3. **Update Circuit State**:
   - If request succeeds: Call `record_success()`
   - If request fails: Call `record_failure()`

### Error Handling

**When Circuit is Open**:
- Return `503 Service Unavailable` immediately
- Include message: "Database temporarily unavailable"
- No database request made

**When Circuit is Half-Open**:
- Make database request
- If succeeds: Transition to Closed
- If fails: Transition back to Open

---

## Health Check Monitoring

### Background Health Check Task

When circuit is open, run background health check task:

```zig
fn health_check_task(circuit_breaker: *CircuitBreaker) void {
    while (circuit_breaker.state == .open) {
        std.time.sleep(5_000_000_000); // 5 seconds
        
        if (circuit_breaker.check_health()) {
            // Database recovered, transition to half-open
            circuit_breaker.state = .half_open;
            circuit_breaker.success_count = 0;
        }
    }
}
```

### Health Check Failure Detection

Monitor health check endpoint for:
- HTTP 503 status (Service Unavailable)
- Network errors (connection refused, timeout)
- Invalid response format
- `status: "unhealthy"` in response body

---

## Best Practices

### 1. **Graceful Degradation**
- When circuit is open, return cached data if available
- Show user-friendly error messages
- Don't block user interface

### 2. **Monitoring**
- Log circuit state transitions
- Track time spent in each state
- Monitor failure rates

### 3. **Configuration**
- Make thresholds configurable
- Adjust based on production metrics
- Consider different thresholds for different endpoints

### 4. **Testing**
- Test circuit opening under load
- Test circuit recovery after database restart
- Test half-open state transitions

---

## Integration with Other Patterns

### Rate Limiting
- Circuit breaker can work alongside rate limiting
- Rate limiting prevents overload, circuit breaker prevents cascading failures

### Retry Logic
- Don't retry when circuit is open
- Retry when circuit is closed or half-open
- Use exponential backoff with retry logic

### Idempotency
- Use idempotency keys when circuit transitions from open to half-open
- Ensures safe retries during recovery

---

## Example: Carry Agent Integration

**Scenario**: Mobile app user registration

1. **Circuit Closed** (Normal):
   - User submits registration form
   - Request proceeds to database
   - User created successfully

2. **Circuit Open** (Database Down):
   - User submits registration form
   - Circuit breaker detects open state
   - Return error: "Service temporarily unavailable, please try again later"
   - No database request made

3. **Circuit Half-Open** (Recovery):
   - User submits registration form
   - Circuit breaker allows request (testing recovery)
   - Database request succeeds
   - Circuit transitions to Closed
   - User created successfully

---

## Questions for Core Agent

1. Should circuit breaker be implemented in Core Agent HTTP client or in each agent?
2. Should we provide a shared circuit breaker library?
3. What are recommended thresholds for different operation types?

---

## Status

**Health Check Endpoint**: ✅ **COMPLETE**  
**Circuit Breaker Documentation**: ✅ **COMPLETE**  
**Circuit Breaker Implementation**: ⏳ **CLIENT AGENT RESPONSIBILITY**

Client agents (Carry, Bubble, Skate) should implement circuit breaker pattern using this documentation.

---

**Date**: 2025-12-23-220000-pst  
**Agent**: Grain Silo Agent (Database)  
**Status**: Documentation complete, ready for client agent implementation
