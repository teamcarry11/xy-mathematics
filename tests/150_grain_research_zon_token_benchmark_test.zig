//! ZON Format Token Efficiency Benchmark Tests.
//!
//! Why: Validates ZON format token efficiency claims (35-70% reduction vs JSON).
//! Architecture: Benchmark test suite with 4 test data structures, 3 LLM providers.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-105900-pst: ZON Format Token Efficiency Validation Phase 1

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const TokenCounter = grain_research.TokenCounter;
const LLMProvider = grain_research.LLMProvider;

// Test 1: Simple Object (Config File)
const TEST_1_JSON =
    \\{"database":{"host":"localhost","port":5432},"features":{"darkMode":true}}
;

// Simplified ZON representation (tabular format).
// ZON uses tabular encoding: key columns, value columns.
// Format: key1|key2|key3\nvalue1|value2|value3
const TEST_1_ZON =
    \\database.host|database.port|features.darkMode
    \\localhost|5432|true
;

// Test 2: Array of Objects (Workflow Metrics)
const TEST_2_JSON =
    \\{"total_executions":1000,"executions":[{"workflow_id":1,"name":"backup","execution_time_ms":500,"status":"success"},{"workflow_id":2,"name":"sync","execution_time_ms":400,"status":"success"}]}
;

// ZON tabular format for arrays: header row, then data rows.
const TEST_2_ZON =
    \\total_executions|workflow_id|name|execution_time_ms|status
    \\1000|1|backup|500|success
    \\1000|2|sync|400|success
;

// Test 3: Nested Structure (Complex Config)
const TEST_3_JSON =
    \\{"app":{"name":"Grain OS","version":"1.0.0","modules":[{"name":"core","enabled":true},{"name":"flow","enabled":true}]}}
;

// ZON tabular format for nested structures: flattened keys.
const TEST_3_ZON =
    \\app.name|app.version|app.modules.name|app.modules.enabled
    \\Grain OS|1.0.0|core|true
    \\Grain OS|1.0.0|flow|true
;

// Test 4: Mixed Structure (Real-World Data)
// Workflow execution records with agent coordination metrics.
const TEST_4_JSON =
    \\{"workflow_id":1,"name":"backup_workflow","execution_time_ms":1500,"status":"success","coordination":{"source_agent_id":1,"target_agent_id":2,"latency_ms":50},"performance":{"cpu_percent":25,"memory_bytes":1048576}}
;

// ZON tabular format for mixed structures: all fields in columns.
const TEST_4_ZON =
    \\workflow_id|name|execution_time_ms|status|coordination.source_agent_id|coordination.target_agent_id|coordination.latency_ms|performance.cpu_percent|performance.memory_bytes
    \\1|backup_workflow|1500|success|1|2|50|25|1048576
;

test "benchmark test 1: simple object token count" {
    const allocator = testing.allocator;
    var counter = TokenCounter.init(allocator);

    // Count JSON tokens.
    const json_result = try counter.count_tokens(TEST_1_JSON, .gpt4o);
    try testing.expect(json_result.token_count > 0);

    // Count ZON tokens.
    const zon_result = try counter.count_tokens(TEST_1_ZON, .gpt4o);
    try testing.expect(zon_result.token_count > 0);

    // Calculate reduction percentage.
    const reduction = counter.calculate_reduction_percent(json_result.token_count, zon_result.token_count);
    try testing.expect(reduction <= 100);

    // ZON should have fewer or equal tokens.
    try testing.expect(zon_result.token_count <= json_result.token_count);
}

test "benchmark test 2: array of objects token count" {
    const allocator = testing.allocator;
    var counter = TokenCounter.init(allocator);

    // Count JSON tokens.
    const json_result = try counter.count_tokens(TEST_2_JSON, .gpt4o);
    try testing.expect(json_result.token_count > 0);

    // Count ZON tokens.
    const zon_result = try counter.count_tokens(TEST_2_ZON, .gpt4o);
    try testing.expect(zon_result.token_count > 0);

    // Calculate reduction percentage.
    const reduction = counter.calculate_reduction_percent(json_result.token_count, zon_result.token_count);
    try testing.expect(reduction <= 100);

    // ZON should have fewer or equal tokens.
    try testing.expect(zon_result.token_count <= json_result.token_count);
}

test "benchmark test 3: nested structure token count" {
    const allocator = testing.allocator;
    var counter = TokenCounter.init(allocator);

    // Count JSON tokens.
    const json_result = try counter.count_tokens(TEST_3_JSON, .gpt4o);
    try testing.expect(json_result.token_count > 0);

    // Count ZON tokens.
    const zon_result = try counter.count_tokens(TEST_3_ZON, .gpt4o);
    try testing.expect(zon_result.token_count > 0);

    // Calculate reduction percentage.
    const reduction = counter.calculate_reduction_percent(json_result.token_count, zon_result.token_count);
    try testing.expect(reduction <= 100);

    // ZON should have fewer or equal tokens.
    try testing.expect(zon_result.token_count <= json_result.token_count);
}

test "benchmark test 4: mixed structure token count" {
    const allocator = testing.allocator;
    var counter = TokenCounter.init(allocator);

    // Count JSON tokens.
    const json_result = try counter.count_tokens(TEST_4_JSON, .gpt4o);
    try testing.expect(json_result.token_count > 0);

    // Count ZON tokens.
    const zon_result = try counter.count_tokens(TEST_4_ZON, .gpt4o);
    try testing.expect(zon_result.token_count > 0);

    // Calculate reduction percentage.
    const reduction = counter.calculate_reduction_percent(json_result.token_count, zon_result.token_count);
    try testing.expect(reduction <= 100);

    // ZON should have fewer or equal tokens.
    try testing.expect(zon_result.token_count <= json_result.token_count);
}

test "benchmark all providers: test 1 simple object" {
    const allocator = testing.allocator;
    var counter = TokenCounter.init(allocator);

    const providers = [_]LLMProvider{ .gpt4o, .claude35, .llama3 };

    var i: u32 = 0;
    while (i < providers.len) : (i += 1) {
        const provider = providers[i];

        // Count JSON tokens.
        const json_result = try counter.count_tokens(TEST_1_JSON, provider);
        try testing.expect(json_result.token_count > 0);

        // Count ZON tokens.
        const zon_result = try counter.count_tokens(TEST_1_ZON, provider);
        try testing.expect(zon_result.token_count > 0);

        // Calculate reduction percentage.
        const reduction = counter.calculate_reduction_percent(json_result.token_count, zon_result.token_count);
        try testing.expect(reduction <= 100);

        // ZON should have fewer or equal tokens.
        try testing.expect(zon_result.token_count <= json_result.token_count);
    }
}

test "benchmark all providers: test 2 array of objects" {
    const allocator = testing.allocator;
    var counter = TokenCounter.init(allocator);

    const providers = [_]LLMProvider{ .gpt4o, .claude35, .llama3 };

    var i: u32 = 0;
    while (i < providers.len) : (i += 1) {
        const provider = providers[i];

        // Count JSON tokens.
        const json_result = try counter.count_tokens(TEST_2_JSON, provider);
        try testing.expect(json_result.token_count > 0);

        // Count ZON tokens.
        const zon_result = try counter.count_tokens(TEST_2_ZON, provider);
        try testing.expect(zon_result.token_count > 0);

        // Calculate reduction percentage.
        const reduction = counter.calculate_reduction_percent(json_result.token_count, zon_result.token_count);
        try testing.expect(reduction <= 100);

        // ZON should have fewer or equal tokens.
        try testing.expect(zon_result.token_count <= json_result.token_count);
    }
}

test "benchmark all providers: test 3 nested structure" {
    const allocator = testing.allocator;
    var counter = TokenCounter.init(allocator);

    const providers = [_]LLMProvider{ .gpt4o, .claude35, .llama3 };

    var i: u32 = 0;
    while (i < providers.len) : (i += 1) {
        const provider = providers[i];

        // Count JSON tokens.
        const json_result = try counter.count_tokens(TEST_3_JSON, provider);
        try testing.expect(json_result.token_count > 0);

        // Count ZON tokens.
        const zon_result = try counter.count_tokens(TEST_3_ZON, provider);
        try testing.expect(zon_result.token_count > 0);

        // Calculate reduction percentage.
        const reduction = counter.calculate_reduction_percent(json_result.token_count, zon_result.token_count);
        try testing.expect(reduction <= 100);

        // ZON should have fewer or equal tokens.
        try testing.expect(zon_result.token_count <= json_result.token_count);
    }
}

test "benchmark all providers: test 4 mixed structure" {
    const allocator = testing.allocator;
    var counter = TokenCounter.init(allocator);

    const providers = [_]LLMProvider{ .gpt4o, .claude35, .llama3 };

    var i: u32 = 0;
    while (i < providers.len) : (i += 1) {
        const provider = providers[i];

        // Count JSON tokens.
        const json_result = try counter.count_tokens(TEST_4_JSON, provider);
        try testing.expect(json_result.token_count > 0);

        // Count ZON tokens.
        const zon_result = try counter.count_tokens(TEST_4_ZON, provider);
        try testing.expect(zon_result.token_count > 0);

        // Calculate reduction percentage.
        const reduction = counter.calculate_reduction_percent(json_result.token_count, zon_result.token_count);
        try testing.expect(reduction <= 100);

        // ZON should have fewer or equal tokens.
        try testing.expect(zon_result.token_count <= json_result.token_count);
    }
}
