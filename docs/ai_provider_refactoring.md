# AI Provider Abstraction Refactoring

## Overview

This document describes the refactoring to generalize AI/LLM code assistance from GLM-4.6-specific code to a pluggable provider architecture.

## Architecture

### Abstraction Layer

**`src/aurora_ai_provider.zig`**: Unified AI provider interface
- Defines `AiProvider` struct with vtable-based polymorphism
- Provides common interfaces: `CompletionRequest`, `TransformRequest`, `ToolCallRequest`
- Supports multiple provider types: `.glm46` (future: `.claude`, `.gpt4`, etc.)
- Enforces bounded allocations and GrainStyle compliance

### Provider Implementations

**`src/aurora_glm46_provider.zig`**: GLM-4.6-specific implementation
- Implements `AiProvider.VTable` for GLM-4.6
- Wraps `Glm46Client` (existing low-level API client)
- Converts between `AiProvider` types and `Glm46Client` types
- Handles GLM-4.6-specific API details (Cerebras API, streaming, etc.)

### Legacy Code

**`src/aurora_glm46.zig`**: Low-level GLM-4.6 HTTP client
- Remains as-is (no changes needed)
- Used by `Glm46Provider` internally
- Handles HTTP requests, JSON serialization, SSE streaming

**`src/aurora_glm46_transforms.zig`**: GLM-4.6-specific transformations
- **TODO**: Refactor to use `AiProvider` instead of `Glm46Client` directly
- Should call `provider.request_transformation()` instead of `client.requestCompletion()`

**`src/aurora_editor.zig`**: Editor integration
- **TODO**: Replace `glm46: ?Glm46Client` with `ai_provider: ?AiProvider`
- Update `enableGlm46()` to `enableAiProvider(provider_type, config)`
- Update `requestCompletions()` to use `ai_provider.request_completion()`

## Benefits

1. **Pluggable Providers**: Easy to add new AI models (Claude, GPT-4, etc.)
2. **Unified Interface**: Editor code doesn't need to know which AI model is being used
3. **Testability**: Can mock `AiProvider` for testing
4. **Future-Proof**: Easy to switch providers or use multiple providers

## Migration Strategy

### Phase 1: Foundation (✅ Complete)
- [x] Create `aurora_ai_provider.zig` with unified interface
- [x] Create `aurora_glm46_provider.zig` with GLM-4.6 implementation
- [x] Add tests for provider initialization

### Phase 2: Editor Integration (📋 Pending)
- [ ] Update `aurora_editor.zig` to use `AiProvider` instead of `Glm46Client`
- [ ] Update `enableGlm46()` → `enableAiProvider(provider_type, config)`
- [ ] Update `requestCompletions()` to use `ai_provider.request_completion()`
- [ ] Add tests for editor with AI provider

### Phase 3: Transformations (📋 Pending)
- [ ] Refactor `aurora_glm46_transforms.zig` to use `AiProvider`
- [ ] Update transformation functions to call `provider.request_transformation()`
- [ ] Add tests for transformations with AI provider

### Phase 4: Build System (📋 Pending)
- [ ] Add `aurora_ai_provider` module to `build.zig`
- [ ] Add `aurora_glm46_provider` module to `build.zig`
- [ ] Update module dependencies

## Usage Example

```zig
// Initialize AI provider (GLM-4.6)
const config = AiProvider.ProviderConfig{
    .glm46 = .{
        .api_key = "your-api-key",
    },
};
var provider = try AiProvider.init(.glm46, allocator, config);
defer provider.deinit();

// Request completion (works with any provider)
const request = AiProvider.CompletionRequest{
    .messages = &.{
        .{ .role = "user", .content = "Complete this code..." },
    },
    .stream = true,
};
try provider.request_completion(request, struct {
    fn callback(chunk: AiProvider.CompletionChunk) void {
        // Handle streaming chunks
        _ = chunk;
    }
}.callback);

// Request transformation (works with any provider)
const transform_request = AiProvider.TransformRequest{
    .transform_type = .refactor_rename,
    .code = "pub fn old_name() void {}",
    .context = &.{},
    .parameters = .{
        .refactor_rename = .{
            .symbol_name = "old_name",
            .new_name = "new_name",
            .file_uri = "file:///test.zig",
            .line = 0,
            .char = 0,
        },
    },
};
const result = try provider.request_transformation(transform_request);
```

## Notes

- All providers must follow GrainStyle/TigerStyle rules
- All providers must use bounded allocations
- All providers must implement the full `VTable` interface
- Provider-specific details (API keys, URLs, etc.) are in `ProviderConfig`

