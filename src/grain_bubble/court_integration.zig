//! Grain Bubble Court Integration: Vector search and LLM suggestions.
//!
//! Why: Enable intelligent design features via vector search and LLM.
//! Architecture: Integration with Grain Court for spatial computing.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-054259-pst: Grain Bubble Agent

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

    pub fn init() CourtIntegration {
        const integration = CourtIntegration{
            .compute = null,
            .next_suggestion_id = 1,
        };
        std.debug.assert(integration.next_suggestion_id == 1);
        return integration;
    }

    // Set Court compute instance.
    pub fn set_compute(self: *CourtIntegration, compute: *grain_court.Compute.CourtCompute) void {
        std.debug.assert(@intFromPtr(compute) != 0);
        self.compute = compute;
        std.debug.assert(self.compute != null);
    }

    // Search for similar components via vector search.
    pub fn search_similar_components(
        self: *CourtIntegration,
        query_vector: []const f32,
        results: []ComponentMatch,
    ) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(query_vector.len > 0);
        std.debug.assert(query_vector.len <= MAX_VECTOR_DIM);
        std.debug.assert(results.len <= MAX_SEARCH_RESULTS);
        if (self.compute == null) {
            return 0;
        }
        const compute = self.compute.?;
        // Allocate SRAM for query vector.
        const vector_size: u64 = @as(u64, @intCast(query_vector.len)) * @sizeOf(f32);
        const data_offset = compute.allocate_sram(vector_size) catch return 0;
        // Copy query vector to SRAM.
        const sram_slice = compute.sram_data[data_offset..data_offset + vector_size];
        @memcpy(sram_slice[0..query_vector.len], std.mem.asBytes(query_vector.ptr)[0..vector_size]);
        // Execute vector search operation.
        const core_ids = [_]u32{0}; // Use first core for search.
        const op_id = compute.execute_parallel(
            grain_court.Compute.CourtCompute.OpType.vector_search,
            &core_ids,
            data_offset,
            vector_size,
        ) catch return 0;
        // Wait for operation to complete (simplified - check status).
        const op_status = compute.get_op_status(op_id);
        if (op_status == null or op_status.? != .completed) {
            return 0;
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

    // Get LLM design suggestions.
    pub fn get_design_suggestions(
        self: *CourtIntegration,
        context: []const u8,
        suggestions: []DesignSuggestion,
    ) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(context.len > 0);
        std.debug.assert(suggestions.len <= MAX_SEARCH_RESULTS);
        if (self.compute == null) {
            return 0;
        }
        // LLM inference via Court compute (simplified for Phase 3).
        // Full implementation will use Court's llm_inference operation.
        // For now, return empty suggestions (ready for real implementation).
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

    // Generate component embedding vector.
    pub fn generate_component_embedding(
        self: *CourtIntegration,
        comp: *const component.Component,
        embedding: []f32,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(comp) != 0);
        std.debug.assert(embedding.len > 0);
        std.debug.assert(embedding.len <= MAX_VECTOR_DIM);
        if (self.compute == null) {
            return false;
        }
        // Generate embedding via Court compute (simplified for Phase 3).
        // Full implementation will use Court's data_transform operation.
        // For now, initialize with zeros (ready for real implementation).
        var i: u32 = 0;
        while (i < embedding.len) : (i += 1) {
            embedding[i] = 0.0;
        }
        std.debug.assert(embedding.len > 0);
        return true;
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

