# Event-Driven Async Pattern Using Flow Agent Event Bus

**Date**: 2025-12-28-173000-pst  
**Agent**: Grain Flow Agent (9th Agent)  
**Purpose**: Documentation for using Flow Agent Event Bus for async operations

---

## Overview

The Event-Driven Async Pattern uses Flow Agent's Event Bus (`grain_flow.event_bus.EventBus`) for asynchronous operation completion. This is a **userspace pattern** (no kernel syscall changes needed) that enables agents to handle async HTTP requests, WebSocket operations, and file I/O without blocking.

---

## Event Types

Flow Agent Event Bus provides the following event types for async operations:

### HTTP Operation Events

- `http_request_completed`: HTTP request completed successfully
- `http_request_failed`: HTTP request failed

### WebSocket Operation Events

- `websocket_connected`: WebSocket connection established
- `websocket_message_received`: WebSocket message received

### File I/O Operation Events

- `file_io_completed`: File I/O operation completed successfully
- `file_io_failed`: File I/O operation failed

---

## Usage Pattern

### 1. Subscribe to Events

Agents subscribe to event types they want to handle:

```zig
const grain_flow = @import("grain_flow");

// Subscribe to HTTP request completion events
const http_completed = grain_flow.event_bus.EventBus.subscribe(
    &event_bus,
    grain_flow.event_bus.EventType.http_request_completed,
    my_agent_id,
    handle_http_completed,
    @as(?*anyopaque, @ptrCast(&my_context)),
);

// Subscribe to HTTP request failure events
const http_failed = grain_flow.event_bus.EventBus.subscribe(
    &event_bus,
    grain_flow.event_bus.EventType.http_request_failed,
    my_agent_id,
    handle_http_failed,
    @as(?*anyopaque, @ptrCast(&my_context)),
);
```

### 2. Event Handler Functions

Event handlers receive events with payload data:

```zig
fn handle_http_completed(event: *const grain_flow.event_bus.Event, user_data: ?*anyopaque) void {
    _ = user_data;
    // Extract response data from event.payload
    const response_data = event.payload[0..event.payload_len];
    // Process response...
}

fn handle_http_failed(event: *const grain_flow.event_bus.Event, user_data: ?*anyopaque) void {
    _ = user_data;
    // Extract error data from event.payload
    const error_data = event.payload[0..event.payload_len];
    // Handle error...
}
```

### 3. Publish Events (Core Agent Implementation)

Core Agent publishes events when async operations complete:

```zig
// Publish HTTP request completed event
event_bus.publish_event_with_payload(
    grain_flow.event_bus.EventType.http_request_completed,
    core_agent_id,
    target_agent_id, // or 0 for broadcast
    current_timestamp,
    response_data,
);

// Publish HTTP request failed event
event_bus.publish_event_with_payload(
    grain_flow.event_bus.EventType.http_request_failed,
    core_agent_id,
    target_agent_id, // or 0 for broadcast
    current_timestamp,
    error_data,
);
```

---

## Event Payload Format

### HTTP Request Completed Event

**Payload**: HTTP response data (JSON, binary, etc.)

Example payload structure:
- Response status code
- Response headers
- Response body
- Request ID (for correlation)

### HTTP Request Failed Event

**Payload**: Error information

Example payload structure:
- Error type (timeout, network_error, dns_error, etc.)
- Error message
- Request ID (for correlation)
- Retry information (if applicable)

### WebSocket Connected Event

**Payload**: Connection information

Example payload structure:
- Connection ID
- WebSocket URL
- Connection metadata

### WebSocket Message Received Event

**Payload**: Message data

Example payload structure:
- Message type
- Message content
- Connection ID
- Timestamp

### File I/O Completed Event

**Payload**: Operation result

Example payload structure:
- File path
- Operation type (read, write, etc.)
- Bytes read/written
- Operation result

### File I/O Failed Event

**Payload**: Error information

Example payload structure:
- File path
- Operation type
- Error type (not_found, permission_denied, etc.)
- Error message

---

## Source Filtering

Agents can filter events by source agent ID:

```zig
// Subscribe to events only from Core Agent (agent ID 1)
grain_flow.event_bus.EventBus.subscribe_with_source_filter(
    &event_bus,
    grain_flow.event_bus.EventType.http_request_completed,
    my_agent_id,
    handle_http_completed,
    @as(?*anyopaque, @ptrCast(&my_context)),
    core_agent_id, // Filter by source agent ID
);
```

---

## Request Tracking

To correlate events with requests, agents should:

1. **Include Request ID in Event Payload**: Core Agent includes request ID in event payload
2. **Store Request Context**: Agents store request context (using `user_data` or internal tracking)
3. **Match Events to Requests**: Agents match event payload (request ID) to stored request context

---

## Best Practices

### 1. Event Subscription Lifecycle

- Subscribe to events when agent starts
- Unsubscribe when agent stops or no longer needs events
- Use `user_data` to pass context to event handlers

### 2. Event Processing

- Process events promptly (don't block in event handlers)
- Use event payload for operation results
- Handle both success and failure events

### 3. Error Handling

- Subscribe to failure events (`http_request_failed`, `file_io_failed`)
- Check error types in event payload
- Implement retry logic for retryable errors (if needed)

### 4. Request Correlation

- Include request ID in async operation initiation
- Store request context with request ID
- Match event payload (request ID) to request context in event handler

---

## Integration with Core Agent

Core Agent implements async pattern by:

1. **Tracking Request State**: HTTP client tracks request state and completion
2. **Publishing Events**: Core Agent publishes events when operations complete
3. **Event Payload**: Core Agent includes operation results/errors in event payload

Agents use the Event Bus to:
1. **Subscribe to Events**: Subscribe to relevant event types
2. **Handle Completion**: Process events in event handlers
3. **Continue Operations**: Use event payload to continue agent operations

---

## Example: Async HTTP Request

```zig
// 1. Subscribe to HTTP request events
event_bus.subscribe(
    EventType.http_request_completed,
    my_agent_id,
    handle_http_response,
    @as(?*anyopaque, @ptrCast(&request_context)),
);

// 2. Initiate async HTTP request (Core Agent will publish event when complete)
// Core Agent HTTP client handles the request asynchronously

// 3. Event handler receives completion event
fn handle_http_response(event: *const Event, user_data: ?*anyopaque) void {
    const context = @as(*RequestContext, @ptrCast(@alignCast(user_data.?.?)));
    // Extract response from event.payload
    const response_data = event.payload[0..event.payload_len];
    // Process response...
}
```

---

## References

- **Event Bus Module**: `src/grain_flow/event_bus.zig`
- **Event Types**: `grain_flow.event_bus.EventType` enum
- **Event Bus API**: `grain_flow.event_bus.EventBus` struct
- **Source Filtering**: `subscribe_with_source_filter()` function
- **Core Agent Coordination Plan**: `docs/agent-communications/core_agent_coordination_plan_2025-12-28-125036-pst.md`

---

**Date**: 2025-12-28-173000-pst  
**Agent**: Grain Flow Agent (9th Agent)  
**Status**: Async Pattern Documentation Complete
