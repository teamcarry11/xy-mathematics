//! Grain Bubble Court Integration: Vector search and LLM suggestions.
//!
//! Why: Enable intelligent design features via vector search and LLM.
//! Architecture: Integration with Grain Court for spatial computing.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-212447-pst: Grain Bubble Agent
//! 2025-12-28-144543-pst: Added timeout handling and error handling

const std = @import("std");
const canvas = @import("canvas.zig");
const component = @import("component.zig");
const grain_court = @import("grain_court");

// Bounded: Max vector dimension.
pub const MAX_VECTOR_DIM: u32 = 1536; // Typical embedding dimension

// Bounded: Max search results.
pub const MAX_SEARCH_RESULTS: u32 = 64;

// Bounded: Max suggestion text length.
pub const MAX_SUGGESTION_LEN: u32 = 512;

// Timeout defaults (per coordination decision 2025-12-28-125036-pst).
pub const DEFAULT_TIMEOUT_API_MS: u32 = 30000; // 30 seconds for API operations
pub const DEFAULT_TIMEOUT_CONTENT_MS: u32 = 60000; // 60 seconds for content operations

// Court compute error: structured error union with retryability.
pub const CourtComputeError = error{
    ComputeNotSet, // Court compute instance not set
    SramAllocationFailed, // SRAM allocation failed (retryable)
    OperationFailed, // Operation execution failed (retryable)
    OperationTimeout, // Operation timed out (retryable)
    InvalidInput, // Invalid input data (non-retryable)
    OperationNotCompleted, // Operation not completed (retryable)
};

// Check if error is retryable.
pub fn is_retryable_error(err: CourtComputeError) bool {
    return switch (err) {
        .ComputeNotSet => false,
        .SramAllocationFailed => true,
        .OperationFailed => true,
        .OperationTimeout => true,
        .InvalidInput => false,
        .OperationNotCompleted => true,
    };
}

// Component match: result from vector search.
pub const ComponentMatch = struct {
    component_id: u32,
    similarity: f32,
    match_type: MatchType,

    pub const MatchType = enum(u8) {
        exact, // Exact match
        similar, // Similar design
        suggested, // LLM-suggested match
    };

    pub fn init() ComponentMatch {
        const match = ComponentMatch{
            .component_id = 0,
            .similarity = 0.0,
            .match_type = .similar,
        };
        std.debug.assert(match.similarity >= 0.0);
        std.debug.assert(match.similarity <= 1.0);
        return match;
    }
};

// Design suggestion: LLM-generated design suggestion.
pub const DesignSuggestion = struct {
    suggestion_id: u32,
    suggestion_text: [MAX_SUGGESTION_LEN]u8,
    suggestion_text_len: u32,
    suggestion_type: SuggestionType,
    confidence: f32,

    pub const SuggestionType = enum(u8) {
        component, // Component suggestion
        layout, // Layout suggestion
        color, // Color palette suggestion
        typography, // Typography suggestion
    };

    pub fn init() DesignSuggestion {
        var suggestion = DesignSuggestion{
            .suggestion_id = 0,
            .suggestion_text = undefined,
            .suggestion_text_len = 0,
            .suggestion_type = .component,
            .confidence = 0.0,
        };
        @memset(suggestion.suggestion_text[0..], 0);
        std.debug.assert(suggestion.confidence >= 0.0);
        std.debug.assert(suggestion.confidence <= 1.0);
        return suggestion;
    }
};

// Court integration: manages vector search and LLM suggestions.
pub const CourtIntegration = struct {
    compute: ?*grain_court.Compute.CourtCompute,
    next_suggestion_id: u32,
    timeout_api_ms: u32, // Timeout for API operations (default: 30s)
    timeout_content_ms: u32, // Timeout for content operations (default: 60s)

    pub fn init() CourtIntegration {
        const integration = CourtIntegration{
            .compute = null,
            .next_suggestion_id = 1,
            .timeout_api_ms = DEFAULT_TIMEOUT_API_MS,
            .timeout_content_ms = DEFAULT_TIMEOUT_CONTENT_MS,
        };
        std.debug.assert(integration.next_suggestion_id == 1);
        std.debug.assert(integration.timeout_api_ms == DEFAULT_TIMEOUT_API_MS);
        std.debug.assert(integration.timeout_content_ms == DEFAULT_TIMEOUT_CONTENT_MS);
        return integration;
    }

    // Set timeout for API operations (per-request override).
    pub fn set_timeout_api(self: *CourtIntegration, timeout_ms: u32) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(timeout_ms > 0);
        self.timeout_api_ms = timeout_ms;
        std.debug.assert(self.timeout_api_ms == timeout_ms);
    }

    // Set timeout for content operations (per-request override).
    pub fn set_timeout_content(self: *CourtIntegration, timeout_ms: u32) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(timeout_ms > 0);
        self.timeout_content_ms = timeout_ms;
        std.debug.assert(self.timeout_content_ms == timeout_ms);
    }

    // Set Court compute instance.
    pub fn set_compute(self: *CourtIntegration, compute: *grain_court.Compute.CourtCompute) void {
        std.debug.assert(@intFromPtr(compute) != 0);
        self.compute = compute;
        std.debug.assert(self.compute != null);
    }

    // Calculate max polling iterations for timeout (helper for timeout handling).
    fn get_max_polls_for_timeout(timeout_ms: u32) u32 {
        const poll_interval_ms: u32 = 10; // Poll every 10ms
        const max_polls: u32 = (timeout_ms + poll_interval_ms - 1) / poll_interval_ms;
        std.debug.assert(max_polls > 0);
        return max_polls;
    }

    // Search for similar components via vector search (with timeout and error handling).
    pub fn search_similar_components(
        self: *CourtIntegration,
        query_vector: []const f32,
        results: []ComponentMatch,
    ) CourtComputeError!u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(query_vector.len > 0);
        std.debug.assert(query_vector.len <= MAX_VECTOR_DIM);
        std.debug.assert(results.len <= MAX_SEARCH_RESULTS);
        if (self.compute == null) {
            return CourtComputeError.ComputeNotSet;
        }
        if (query_vector.len == 0 or query_vector.len > MAX_VECTOR_DIM) {
            return CourtComputeError.InvalidInput;
        }
        const compute = self.compute.?;
        // Allocate SRAM for query vector (use core 0).
        const core_id: u32 = 0;
        const vector_size: u64 = @as(u64, @intCast(query_vector.len)) * @sizeOf(f32);
        const data_offset = compute.allocate_sram(core_id, vector_size) catch {
            return CourtComputeError.SramAllocationFailed;
        };
        // Copy query vector to SRAM.
        const sram_slice = compute.sram_data[data_offset..data_offset + vector_size];
        @memcpy(sram_slice[0..vector_size], std.mem.asBytes(query_vector.ptr)[0..vector_size]);
        // Execute vector search operation.
        const core_ids = [_]u32{0}; // Use first core for search.
        const op_id = compute.execute_parallel(
            grain_court.Compute.CourtCompute.OpType.vector_search,
            &core_ids,
            data_offset,
            vector_size,
        ) catch {
            return CourtComputeError.OperationFailed;
        };
        // Wait for operation to complete with timeout checking.
        const max_polls = self.get_max_polls_for_timeout(self.timeout_api_ms);
        var poll_count: u32 = 0;
        while (poll_count < max_polls) : (poll_count += 1) {
            const op_status = compute.get_op_status(op_id);
            if (op_status != null and op_status.? == .completed) {
                break;
            }
            std.time.sleep(10_000_000); // Sleep 10ms between polls
        }
        if (poll_count >= max_polls) {
            return CourtComputeError.OperationTimeout;
        }
        // For now, return empty results (actual results would come from SRAM).
        // Full implementation would read results from SRAM and populate ComponentMatch.
        var result_count: u32 = 0;
        var i: u32 = 0;
        while (i < results.len and result_count < MAX_SEARCH_RESULTS) : (i += 1) {
            results[i] = ComponentMatch.init();
            result_count += 1;
        }
        std.debug.assert(result_count <= MAX_SEARCH_RESULTS);
        return result_count;
    }

    // Get LLM design suggestions (with timeout and error handling).
    pub fn get_design_suggestions(
        self: *CourtIntegration,
        context: []const u8,
        suggestions: []DesignSuggestion,
    ) CourtComputeError!u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(context.len > 0);
        std.debug.assert(suggestions.len <= MAX_SEARCH_RESULTS);
        if (self.compute == null) {
            return CourtComputeError.ComputeNotSet;
        }
        if (context.len == 0) {
            return CourtComputeError.InvalidInput;
        }
        const compute = self.compute.?;
        // Allocate SRAM for context data (use core 0).
        const core_id: u32 = 0;
        const context_size: u64 = @as(u64, @intCast(context.len));
        const data_offset = compute.allocate_sram(core_id, context_size) catch {
            return CourtComputeError.SramAllocationFailed;
        };
        // Copy context to SRAM.
        const sram_slice = compute.sram_data[data_offset..data_offset + context_size];
        @memcpy(sram_slice[0..context_size], context);
        // Execute LLM inference operation (content operation - use 60s timeout).
        const core_ids = [_]u32{0}; // Use first core for inference.
        const op_id = compute.execute_parallel(
            grain_court.Compute.CourtCompute.OpType.llm_inference,
            &core_ids,
            data_offset,
            context_size,
        ) catch {
            return CourtComputeError.OperationFailed;
        };
        // Wait for operation to complete with timeout checking.
        const max_polls = self.get_max_polls_for_timeout(self.timeout_content_ms);
        var poll_count: u32 = 0;
        while (poll_count < max_polls) : (poll_count += 1) {
            const op_status = compute.get_op_status(op_id);
            if (op_status != null and op_status.? == .completed) {
                break;
            }
            std.time.sleep(10_000_000); // Sleep 10ms between polls
        }
        if (poll_count >= max_polls) {
            return CourtComputeError.OperationTimeout;
        }
        // For now, return empty suggestions (actual suggestions would come from SRAM).
        // Full implementation would read suggestions from SRAM and populate DesignSuggestion.
        var suggestion_count: u32 = 0;
        var i: u32 = 0;
        while (i < suggestions.len and suggestion_count < MAX_SEARCH_RESULTS) : (i += 1) {
            var suggestion = DesignSuggestion.init();
            suggestion.suggestion_id = self.next_suggestion_id;
            self.next_suggestion_id += 1;
            suggestions[i] = suggestion;
            suggestion_count += 1;
        }
        std.debug.assert(suggestion_count <= MAX_SEARCH_RESULTS);
        return suggestion_count;
    }

    // Generate component embedding vector (with timeout and error handling).
    pub fn generate_component_embedding(
        self: *CourtIntegration,
        comp: *const component.Component,
        embedding: []f32,
    ) CourtComputeError!void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(comp) != 0);
        std.debug.assert(embedding.len > 0);
        std.debug.assert(embedding.len <= MAX_VECTOR_DIM);
        if (self.compute == null) {
            return CourtComputeError.ComputeNotSet;
        }
        if (embedding.len == 0 or embedding.len > MAX_VECTOR_DIM) {
            return CourtComputeError.InvalidInput;
        }
        const compute = self.compute.?;
        // Convert component to description for embedding.
        var desc_buffer: [512]u8 = undefined;
        const desc_len = component_to_description(comp, &desc_buffer);
        if (desc_len == 0) {
            return CourtComputeError.InvalidInput;
        }
        // Allocate SRAM for description data (use core 0).
        const core_id: u32 = 0;
        const desc_size: u64 = @as(u64, @intCast(desc_len));
        const data_offset = compute.allocate_sram(core_id, desc_size) catch {
            return CourtComputeError.SramAllocationFailed;
        };
        // Copy description to SRAM.
        const sram_slice = compute.sram_data[data_offset..data_offset + desc_size];
        @memcpy(sram_slice[0..desc_size], desc_buffer[0..desc_len]);
        // Execute data transform operation for embedding.
        const core_ids = [_]u32{0}; // Use first core for transform.
        const op_id = compute.execute_parallel(
            grain_court.Compute.CourtCompute.OpType.data_transform,
            &core_ids,
            data_offset,
            desc_size,
        ) catch {
            return CourtComputeError.OperationFailed;
        };
        // Wait for operation to complete with timeout checking.
        const max_polls = self.get_max_polls_for_timeout(self.timeout_api_ms);
        var poll_count: u32 = 0;
        while (poll_count < max_polls) : (poll_count += 1) {
            const op_status = compute.get_op_status(op_id);
            if (op_status != null and op_status.? == .completed) {
                break;
            }
            std.time.sleep(10_000_000); // Sleep 10ms between polls
        }
        if (poll_count >= max_polls) {
            return CourtComputeError.OperationTimeout;
        }
        // For now, initialize with zeros (actual embedding would come from SRAM).
        // Full implementation would read embedding vector from SRAM.
        var i: u32 = 0;
        while (i < embedding.len) : (i += 1) {
            embedding[i] = 0.0;
        }
        std.debug.assert(embedding.len > 0);
    }

    // Convert component to text description for embedding.
    pub fn component_to_description(
        comp: *const component.Component,
        buffer: []u8,
    ) u32 {
        std.debug.assert(@intFromPtr(comp) != 0);
        std.debug.assert(buffer.len >= 256);
        var offset: u32 = 0;
        // Write component name.
        if (comp.name_len > 0) {
            const name_len = @min(comp.name_len, component.MAX_COMPONENT_NAME_LEN);
            if (offset + name_len < buffer.len) {
                @memcpy(buffer[offset..offset + name_len], comp.name[0..name_len]);
                offset += name_len;
            }
        }
        // Write variant count.
        const variant_text = " variants: ";
        const variant_text_len = variant_text.len;
        if (offset + variant_text_len < buffer.len) {
            @memcpy(buffer[offset..offset + variant_text_len], variant_text);
            offset += variant_text_len;
        }
        // Write design token count.
        const token_text = " tokens: ";
        const token_text_len = token_text.len;
        if (offset + token_text_len < buffer.len) {
            @memcpy(buffer[offset..offset + token_text_len], token_text);
            offset += token_text_len;
        }
        std.debug.assert(offset <= buffer.len);
        return offset;
    }

    // Convert canvas state to context text for LLM.
    pub fn canvas_to_context(
        canvas_state: *const canvas.Canvas,
        buffer: []u8,
    ) u32 {
        std.debug.assert(@intFromPtr(canvas_state) != 0);
        std.debug.assert(buffer.len >= 512);
        var offset: u32 = 0;
        // Write layer count.
        const layer_text = "Canvas with ";
        const layer_text_len = layer_text.len;
        if (offset + layer_text_len < buffer.len) {
            @memcpy(buffer[offset..offset + layer_text_len], layer_text);
            offset += layer_text_len;
        }
        // Write shape and text counts (simplified).
        const summary_text = " layers, shapes, and text elements.";
        const summary_text_len = summary_text.len;
        if (offset + summary_text_len < buffer.len) {
            @memcpy(buffer[offset..offset + summary_text_len], summary_text);
            offset += summary_text_len;
        }
        std.debug.assert(offset <= buffer.len);
        return offset;
    }
};

