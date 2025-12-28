const std = @import("std");
const testing = std.testing;
const grain_court = @import("grain_court");
const Compute = grain_court.Compute;

test "court compute init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sram_capacity: u64 = 47_185_920_000; // 44GB
    const core_count: u32 = 1000; // Smaller for testing
    var court = try Compute.CourtCompute.init(allocator, sram_capacity, core_count);
    defer court.deinit();

    try testing.expect(court.cores_len == core_count);
    try testing.expect(court.sram_capacity == sram_capacity);
    try testing.expect(court.sram_used == 0);
}

test "court sram allocation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sram_capacity: u64 = 1_073_741_824; // 1GB for testing
    const core_count: u32 = 100;
    var court = try Compute.CourtCompute.init(allocator, sram_capacity, core_count);
    defer court.deinit();

    const size: u64 = 1024 * 1024; // 1MB
    const offset = try court.allocate_sram(0, size);

    try testing.expect(offset == 0);
    try testing.expect(court.sram_used == size);

    const core = court.get_core(0);
    try testing.expect(core != null);
    try testing.expect(core.?.sram_offset == 0);
    try testing.expect(core.?.sram_size == size);
}

test "court parallel operation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sram_capacity: u64 = 1_073_741_824; // 1GB for testing
    const core_count: u32 = 100;
    var court = try Compute.CourtCompute.init(allocator, sram_capacity, core_count);
    defer court.deinit();

    const core_ids = [_]u32{ 0, 1, 2, 3 };
    const op_id = try court.execute_parallel(.vector_search, &core_ids, 0, 1024);

    try testing.expect(op_id == 0);
    try testing.expect(court.parallel_ops_len == 1);

    const status = court.get_op_status(op_id);
    try testing.expect(status != null);
    try testing.expect(status.? == .pending);
}

test "llm provider pool init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var pool = grain_court.LlmProvider.ProviderPool.init(allocator);
    try testing.expect(pool.providers_len == 0);
    try testing.expect(pool.default_provider == null);
}

test "llm provider pool add provider" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var pool = grain_court.LlmProvider.ProviderPool.init(allocator);
    const api_key = "test-api-key";
    var openai_provider = try grain_court.OpenAIProvider.init(
        allocator,
        api_key,
        null,
    );
    try pool.add_provider(&openai_provider.trait);
    try testing.expect(pool.providers_len == 1);
    try testing.expect(pool.default_provider != null);
}

test "llm provider pool get provider by type" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var pool = grain_court.LlmProvider.ProviderPool.init(allocator);
    const api_key = "test-api-key";
    var openai_provider = try grain_court.OpenAIProvider.init(
        allocator,
        api_key,
        null,
    );
    try pool.add_provider(&openai_provider.trait);
    const provider = pool.get_provider_by_type(.openai);
    try testing.expect(provider != null);
    try testing.expect(provider.?.provider_type == .openai);
}

test "openai provider init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = "test-api-key-12345";
    var provider = try grain_court.OpenAIProvider.init(
        allocator,
        api_key,
        null,
    );
    try testing.expect(provider.trait.provider_type == .openai);
    try testing.expect(provider.trait.state == .idle);
    try testing.expect(provider.trait.api_key_len > 0);
}

test "openai provider check health" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = "test-api-key";
    var provider = try grain_court.OpenAIProvider.init(
        allocator,
        api_key,
        null,
    );
    const is_healthy = provider.trait.check_health(&provider.trait);
    try testing.expect(is_healthy == false); // No HTTP client
}

test "openai provider get name" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = "test-api-key";
    var provider = try grain_court.OpenAIProvider.init(
        allocator,
        api_key,
        null,
    );
    const name = provider.trait.get_name(&provider.trait);
    try testing.expect(std.mem.eql(u8, name, "OpenAI"));
}

test "anthropic provider init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = "test-api-key-12345";
    var provider = try grain_court.AnthropicProvider.init(
        allocator,
        api_key,
        null,
    );
    try testing.expect(provider.trait.provider_type == .anthropic);
    try testing.expect(provider.trait.state == .idle);
    try testing.expect(provider.trait.api_key_len > 0);
}

test "anthropic provider check health" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = "test-api-key";
    var provider = try grain_court.AnthropicProvider.init(
        allocator,
        api_key,
        null,
    );
    const is_healthy = provider.trait.check_health(&provider.trait);
    try testing.expect(is_healthy == false); // No HTTP client
}

test "anthropic provider get name" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = "test-api-key";
    var provider = try grain_court.AnthropicProvider.init(
        allocator,
        api_key,
        null,
    );
    const name = provider.trait.get_name(&provider.trait);
    try testing.expect(std.mem.eql(u8, name, "Anthropic"));
}

test "mistral provider init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = "test-api-key-12345";
    var provider = try grain_court.MistralProvider.init(
        allocator,
        api_key,
        null,
    );
    try testing.expect(provider.trait.provider_type == .mistral);
    try testing.expect(provider.trait.state == .idle);
    try testing.expect(provider.trait.api_key_len > 0);
}

test "mistral provider check health" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = "test-api-key";
    var provider = try grain_court.MistralProvider.init(
        allocator,
        api_key,
        null,
    );
    const is_healthy = provider.trait.check_health(&provider.trait);
    try testing.expect(is_healthy == false); // No HTTP client
}

test "mistral provider get name" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = "test-api-key";
    var provider = try grain_court.MistralProvider.init(
        allocator,
        api_key,
        null,
    );
    const name = provider.trait.get_name(&provider.trait);
    try testing.expect(std.mem.eql(u8, name, "Mistral"));
}

test "self hosted provider init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = "test-api-key-12345";
    var provider = try grain_court.SelfHostedProvider.init(
        allocator,
        api_key,
        null,
        null,
    );
    try testing.expect(provider.trait.provider_type == .self_hosted);
    try testing.expect(provider.trait.state == .idle);
    try testing.expect(provider.trait.api_key_len > 0);
}

test "self hosted provider check health" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = "test-api-key";
    var provider = try grain_court.SelfHostedProvider.init(
        allocator,
        api_key,
        null,
        null,
    );
    const is_healthy = provider.trait.check_health(&provider.trait);
    try testing.expect(is_healthy == false); // No HTTP client
}

test "self hosted provider get name" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = "test-api-key";
    var provider = try grain_court.SelfHostedProvider.init(
        allocator,
        api_key,
        null,
        null,
    );
    const name = provider.trait.get_name(&provider.trait);
    try testing.expect(std.mem.eql(u8, name, "Cerebras GLM-4.6"));
}

test "provider pool multiple providers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var pool = grain_court.LlmProvider.ProviderPool.init(allocator);
    const api_key = "test-api-key";
    var openai_provider = try grain_court.OpenAIProvider.init(
        allocator,
        api_key,
        null,
    );
    var anthropic_provider = try grain_court.AnthropicProvider.init(
        allocator,
        api_key,
        null,
    );
    try pool.add_provider(&openai_provider.trait);
    try pool.add_provider(&anthropic_provider.trait);
    try testing.expect(pool.providers_len == 2);
    try testing.expect(pool.default_provider != null);
    try testing.expect(pool.default_provider.?.provider_type == .openai);
}

test "provider pool set default provider" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var pool = grain_court.LlmProvider.ProviderPool.init(allocator);
    const api_key = "test-api-key";
    var openai_provider = try grain_court.OpenAIProvider.init(
        allocator,
        api_key,
        null,
    );
    var anthropic_provider = try grain_court.AnthropicProvider.init(
        allocator,
        api_key,
        null,
    );
    try pool.add_provider(&openai_provider.trait);
    try pool.add_provider(&anthropic_provider.trait);
    const set = pool.set_default_provider(&anthropic_provider.trait);
    try testing.expect(set == true);
    try testing.expect(pool.default_provider != null);
    try testing.expect(pool.default_provider.?.provider_type == .anthropic);
}

test "provider pool get default provider" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var pool = grain_court.LlmProvider.ProviderPool.init(allocator);
    const api_key = "test-api-key";
    var openai_provider = try grain_court.OpenAIProvider.init(
        allocator,
        api_key,
        null,
    );
    try pool.add_provider(&openai_provider.trait);
    const default_provider = pool.get_default_provider();
    try testing.expect(default_provider != null);
    try testing.expect(default_provider.?.provider_type == .openai);
}

test "zon format encode simple key value" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const pairs = [_]struct {
        key: []const u8,
        value: grain_court.ZonFormat.ZonValue,
    }{
        .{
            .key = "total_executions",
            .value = grain_court.ZonFormat.ZonValue.from_u32(1000),
        },
    };
    const result = try grain_court.ZonFormat.encode_zon(&pairs, allocator);
    defer result.deinit();
    try testing.expect(result.len > 0);
    try testing.expect(std.mem.containsAtLeast(
        u8,
        result.data[0..result.len],
        1,
        "total_executions:1000",
    ));
}

test "zon format encode boolean" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const pairs = [_]struct {
        key: []const u8,
        value: grain_court.ZonFormat.ZonValue,
    }{
        .{
            .key = "active",
            .value = grain_court.ZonFormat.ZonValue.from_bool(true),
        },
    };
    const result = try grain_court.ZonFormat.encode_zon(&pairs, allocator);
    defer result.deinit();
    try testing.expect(result.len > 0);
    try testing.expect(std.mem.containsAtLeast(
        u8,
        result.data[0..result.len],
        1,
        "active:T",
    ));
}

test "zon format encode string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const pairs = [_]struct {
        key: []const u8,
        value: grain_court.ZonFormat.ZonValue,
    }{
        .{
            .key = "name",
            .value = grain_court.ZonFormat.ZonValue.from_string("backup"),
        },
    };
    const result = try grain_court.ZonFormat.encode_zon(&pairs, allocator);
    defer result.deinit();
    try testing.expect(result.len > 0);
    try testing.expect(std.mem.containsAtLeast(
        u8,
        result.data[0..result.len],
        1,
        "name:backup",
    ));
}

test "zon format encode tabular array" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const field_names = [_][]const u8{ "workflow_id", "name", "status" };
    const row1 = [_]grain_court.ZonFormat.ZonValue{
        grain_court.ZonFormat.ZonValue.from_u32(1),
        grain_court.ZonFormat.ZonValue.from_string("backup"),
        grain_court.ZonFormat.ZonValue.from_string("success"),
    };
    const row2 = [_]grain_court.ZonFormat.ZonValue{
        grain_court.ZonFormat.ZonValue.from_u32(2),
        grain_court.ZonFormat.ZonValue.from_string("sync"),
        grain_court.ZonFormat.ZonValue.from_string("success"),
    };
    const rows = [_][]const grain_court.ZonFormat.ZonValue{ &row1, &row2 };
    const result = try grain_court.ZonFormat.encode_tabular_array_zon(
        "executions",
        &field_names,
        &rows,
        allocator,
    );
    defer result.deinit();
    try testing.expect(result.len > 0);
    try testing.expect(std.mem.containsAtLeast(
        u8,
        result.data[0..result.len],
        1,
        "executions:@(2):workflow_id,name,status",
    ));
}

test "zon format encode nested object" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const fields = [_]grain_court.ZonFormat.ZonNestedField{
        .{
            .key = "host",
            .value = grain_court.ZonFormat.ZonValue.from_string("localhost"),
        },
        .{
            .key = "port",
            .value = grain_court.ZonFormat.ZonValue.from_u32(5432),
        },
    };
    const result = try grain_court.ZonFormat.encode_nested_object_zon(
        "config.database",
        &fields,
        allocator,
    );
    defer result.deinit();
    try testing.expect(result.len > 0);
    try testing.expect(std.mem.containsAtLeast(
        u8,
        result.data[0..result.len],
        1,
        "config.database{host:localhost,port:5432}",
    ));
}

test "zon format decode simple" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const zon_str = "total_executions:1000\nactive:T";
    const result = try grain_court.ZonFormat.decode_zon(zon_str, allocator);
    defer result.deinit();
    try testing.expect(result.pairs.len == 2);
    try testing.expect(std.mem.eql(u8, result.pairs[0].key, "total_executions"));
    try testing.expect(result.pairs[0].value.value_type == .u32_value);
    try testing.expect(result.pairs[0].value.u32_val == 1000);
    try testing.expect(std.mem.eql(u8, result.pairs[1].key, "active"));
    try testing.expect(result.pairs[1].value.value_type == .bool_value);
    try testing.expect(result.pairs[1].value.bool_val == true);
}

test "llm provider encode data to zon" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const data = [_]struct {
        key: []const u8,
        value: grain_court.ZonFormat.ZonValue,
    }{
        .{
            .key = "total_executions",
            .value = grain_court.ZonFormat.ZonValue.from_u32(1000),
        },
        .{
            .key = "active",
            .value = grain_court.ZonFormat.ZonValue.from_bool(true),
        },
    };
    const zon_result = try grain_court.LlmProvider.encode_data_to_zon(&data, allocator);
    defer allocator.free(zon_result);
    try testing.expect(zon_result.len > 0);
    try testing.expect(std.mem.containsAtLeast(
        u8,
        zon_result,
        1,
        "total_executions:1000",
    ));
}

test "llm provider provider supports zon" {
    try testing.expect(
        !grain_court.LlmProvider.provider_supports_zon(.openai),
    );
    try testing.expect(
        !grain_court.LlmProvider.provider_supports_zon(.anthropic),
    );
    try testing.expect(
        !grain_court.LlmProvider.provider_supports_zon(.mistral),
    );
    try testing.expect(
        grain_court.LlmProvider.provider_supports_zon(.self_hosted),
    );
}

test "llm provider error retryability" {
    try testing.expect(
        grain_court.LlmProvider.is_llm_error_retryable(.Timeout),
    );
    try testing.expect(
        grain_court.LlmProvider.is_llm_error_retryable(.RateLimit),
    );
    try testing.expect(
        grain_court.LlmProvider.is_llm_error_retryable(.NetworkError),
    );
    try testing.expect(
        !grain_court.LlmProvider.is_llm_error_retryable(.InvalidRequest),
    );
    try testing.expect(
        !grain_court.LlmProvider.is_llm_error_retryable(.AuthenticationError),
    );
}

test "llm provider parse retry after header" {
    const retry_after = grain_court.LlmProvider.parse_retry_after_header("60");
    try testing.expect(retry_after != null);
    try testing.expect(retry_after.? == 60000);
    const retry_after_invalid = grain_court.LlmProvider.parse_retry_after_header("");
    try testing.expect(retry_after_invalid == null);
}

test "zon format encode bounded simple key value" {
    var output: [1024]u8 = undefined;
    var output_pos: u32 = 0;
    const pairs = [_]struct { key: []const u8, value: grain_court.ZonFormat.ZonValue }{
        .{ .key = "test_key", .value = grain_court.ZonFormat.ZonValue.from_u32(42) },
    };
    const success = grain_court.ZonFormat.encode_zon_bounded(&pairs, &output, &output_pos);
    try testing.expect(success == true);
    try testing.expect(output_pos > 0);
    const result = output[0..output_pos];
    try testing.expect(std.mem.indexOf(u8, result, "test_key") != null);
    try testing.expect(std.mem.indexOf(u8, result, "42") != null);
}

test "zon format encode bounded tabular array" {
    var output: [1024]u8 = undefined;
    var output_pos: u32 = 0;
    const field_names = [_][]const u8{ "id", "name" };
    const rows = [_][]const grain_court.ZonFormat.ZonValue{
        &[_]grain_court.ZonFormat.ZonValue{
            grain_court.ZonFormat.ZonValue.from_u32(1),
            grain_court.ZonFormat.ZonValue.from_string("test"),
        },
    };
    const success = grain_court.ZonFormat.encode_tabular_array_zon_bounded(
        "test_table",
        &field_names,
        &rows,
        &output,
        &output_pos,
    );
    try testing.expect(success == true);
    try testing.expect(output_pos > 0);
    const result = output[0..output_pos];
    try testing.expect(std.mem.indexOf(u8, result, "test_table") != null);
    try testing.expect(std.mem.indexOf(u8, result, "@(1)") != null);
}

test "zon format encode bounded nested object" {
    var output: [1024]u8 = undefined;
    var output_pos: u32 = 0;
    const fields = [_]grain_court.ZonFormat.ZonNestedField{
        .{ .key = "host", .value = grain_court.ZonFormat.ZonValue.from_string("localhost") },
        .{ .key = "port", .value = grain_court.ZonFormat.ZonValue.from_u32(5432) },
    };
    const success = grain_court.ZonFormat.encode_nested_object_zon_bounded(
        "config.database",
        &fields,
        &output,
        &output_pos,
    );
    try testing.expect(success == true);
    try testing.expect(output_pos > 0);
    const result = output[0..output_pos];
    try testing.expect(std.mem.indexOf(u8, result, "config.database") != null);
    try testing.expect(std.mem.indexOf(u8, result, "localhost") != null);
}

test "llm provider error context init" {
    const ctx = grain_court.LlmProvider.LlmErrorContext.init(
        .Timeout,
        "send_request",
        0,
        null,
        "Request timed out",
    );
    try testing.expect(ctx.error_type == .Timeout);
    try testing.expect(ctx.operation_len > 0);
    try testing.expect(ctx.message_len > 0);
    try testing.expect(ctx.status_code == null);
    try testing.expect(ctx.retry_after_ms == null);
}

test "llm provider error context with status code" {
    const ctx = grain_court.LlmProvider.LlmErrorContext.init(
        .RateLimit,
        "send_request",
        429,
        60000,
        "Rate limit exceeded",
    );
    try testing.expect(ctx.error_type == .RateLimit);
    try testing.expect(ctx.status_code.? == 429);
    try testing.expect(ctx.retry_after_ms.? == 60000);
    try testing.expect(ctx.message_len > 0);
}

test "token efficiency estimate token count" {
    const text = "Hello, world! This is a test.";
    const count = grain_court.TokenEfficiency.estimate_token_count(text);
    try testing.expect(count > 0);
    try testing.expect(count <= grain_court.TokenEfficiency.MAX_TOKENS_PER_REQUEST);
    const empty_count = grain_court.TokenEfficiency.estimate_token_count("");
    try testing.expect(empty_count == 0);
}

test "token efficiency calculate openai cost" {
    const cost = grain_court.TokenEfficiency.calculate_openai_cost(1000, 500);
    try testing.expect(cost > 0.0);
    try testing.expect(cost < 100.0);
    const zero_cost = grain_court.TokenEfficiency.calculate_openai_cost(0, 0);
    try testing.expect(zero_cost == 0.0);
}

test "token efficiency calculate anthropic cost" {
    const cost = grain_court.TokenEfficiency.calculate_anthropic_cost(1000, 500);
    try testing.expect(cost > 0.0);
    try testing.expect(cost < 100.0);
    const zero_cost = grain_court.TokenEfficiency.calculate_anthropic_cost(0, 0);
    try testing.expect(zero_cost == 0.0);
}

test "token efficiency calculate mistral cost" {
    const cost = grain_court.TokenEfficiency.calculate_mistral_cost(1000, 500);
    try testing.expect(cost > 0.0);
    try testing.expect(cost < 100.0);
    const zero_cost = grain_court.TokenEfficiency.calculate_mistral_cost(0, 0);
    try testing.expect(zero_cost == 0.0);
}

test "token efficiency calculate cerebras cost" {
    const cost = grain_court.TokenEfficiency.calculate_cerebras_cost(1000, 500);
    try testing.expect(cost > 0.0);
    try testing.expect(cost < 100.0);
    const zero_cost = grain_court.TokenEfficiency.calculate_cerebras_cost(0, 0);
    try testing.expect(zero_cost == 0.0);
}

test "token efficiency calculate provider cost" {
    const openai_cost = grain_court.TokenEfficiency.calculate_provider_cost(.openai, 1000, 500);
    try testing.expect(openai_cost > 0.0);
    const anthropic_cost = grain_court.TokenEfficiency.calculate_provider_cost(.anthropic, 1000, 500);
    try testing.expect(anthropic_cost > 0.0);
    const mistral_cost = grain_court.TokenEfficiency.calculate_provider_cost(.mistral, 1000, 500);
    try testing.expect(mistral_cost > 0.0);
    const cerebras_cost = grain_court.TokenEfficiency.calculate_provider_cost(.self_hosted, 1000, 500);
    try testing.expect(cerebras_cost > 0.0);
}

test "token efficiency cost tracker init" {
    var tracker = grain_court.TokenEfficiency.CostTracker.init();
    try testing.expect(tracker.entries_len == 0);
    try testing.expect(tracker.total_cost_usd == 0.0);
    const total = tracker.get_total_cost();
    try testing.expect(total == 0.0);
}

test "token efficiency cost tracker add entry" {
    var tracker = grain_court.TokenEfficiency.CostTracker.init();
    const success = tracker.add_cost_entry(
        .openai,
        "gpt-4o",
        1000,
        500,
        5.0,
    );
    try testing.expect(success == true);
    try testing.expect(tracker.entries_len == 1);
    try testing.expect(tracker.total_cost_usd == 5.0);
    const total = tracker.get_total_cost();
    try testing.expect(total == 5.0);
    const provider_cost = tracker.get_cost_by_provider(.openai);
    try testing.expect(provider_cost == 5.0);
}

test "token efficiency calculate token efficiency" {
    const text = "Hello, world!";
    const token_count: u32 = 3;
    const efficiency = grain_court.TokenEfficiency.calculate_token_efficiency(text, token_count);
    try testing.expect(efficiency > 0.0);
    try testing.expect(efficiency < 1.0);
    const empty_efficiency = grain_court.TokenEfficiency.calculate_token_efficiency("", 0);
    try testing.expect(empty_efficiency == 0.0);
}

test "token efficiency calculate response cost" {
    var response = grain_court.LlmProvider.LlmResponse{
        .request_id = 1,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 1500,
        .input_tokens = 1000,
        .output_tokens = 500,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };
    const cost = grain_court.TokenEfficiency.calculate_response_cost(&response);
    try testing.expect(cost > 0.0);
    try testing.expect(cost < 100.0);
}

test "token efficiency track response cost" {
    var tracker = grain_court.TokenEfficiency.CostTracker.init();
    var response = grain_court.LlmProvider.LlmResponse{
        .request_id = 1,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 1500,
        .input_tokens = 1000,
        .output_tokens = 500,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };
    const success = grain_court.TokenEfficiency.track_response_cost(&tracker, &response, "gpt-4o");
    try testing.expect(success == true);
    try testing.expect(tracker.entries_len == 1);
    try testing.expect(tracker.total_cost_usd > 0.0);
}

test "token efficiency cost tracker request count" {
    var tracker = grain_court.TokenEfficiency.CostTracker.init();
    try testing.expect(tracker.get_request_count() == 0);
    _ = tracker.add_cost_entry(.openai, "gpt-4o", 1000, 500, 5.0);
    try testing.expect(tracker.get_request_count() == 1);
    const provider_count = tracker.get_request_count_by_provider(.openai);
    try testing.expect(provider_count == 1);
}

test "token efficiency cost tracker average cost" {
    var tracker = grain_court.TokenEfficiency.CostTracker.init();
    try testing.expect(tracker.get_average_cost_per_request() == 0.0);
    _ = tracker.add_cost_entry(.openai, "gpt-4o", 1000, 500, 5.0);
    _ = tracker.add_cost_entry(.openai, "gpt-4o", 1000, 500, 5.0);
    const avg = tracker.get_average_cost_per_request();
    try testing.expect(avg == 5.0);
}

test "token efficiency generate cost report" {
    var tracker = grain_court.TokenEfficiency.CostTracker.init();
    _ = tracker.add_cost_entry(.openai, "gpt-4o", 1000, 500, 5.0);
    _ = tracker.add_cost_entry(.anthropic, "claude-3.5", 1000, 500, 6.0);
    const report = grain_court.TokenEfficiency.generate_cost_report(&tracker);
    try testing.expect(report.total_cost_usd == 11.0);
    try testing.expect(report.total_requests == 2);
    try testing.expect(report.average_cost_per_request == 5.5);
    try testing.expect(report.cost_by_provider[0] == 5.0);
    try testing.expect(report.cost_by_provider[1] == 6.0);
}

test "llm provider auto encode request to zon" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var request = grain_court.LlmProvider.LlmRequest{
        .request_id = 1,
        .provider_type = .self_hosted,
        .model = undefined,
        .model_len = 0,
        .prompt = undefined,
        .prompt_len = 0,
        .max_tokens = 1000,
        .temperature = 0.7,
        .created_at = 0,
        .use_zon_format = false,
        .zon_data = null,
        .timeout_ms = null,
    };
    const data = [_]struct { key: []const u8, value: grain_court.ZonFormat.ZonValue }{
        .{ .key = "test_key", .value = grain_court.ZonFormat.ZonValue.from_u32(42) },
    };
    try grain_court.LlmProvider.auto_encode_request_to_zon(&request, &data, allocator);
    try testing.expect(request.use_zon_format == true);
    try testing.expect(request.zon_data != null);
    if (request.zon_data) |zon_data| {
        allocator.free(zon_data);
    }
}

test "llm provider auto encode request to zon fallback" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var request = grain_court.LlmProvider.LlmRequest{
        .request_id = 1,
        .provider_type = .openai,
        .model = undefined,
        .model_len = 0,
        .prompt = undefined,
        .prompt_len = 0,
        .max_tokens = 1000,
        .temperature = 0.7,
        .created_at = 0,
        .use_zon_format = false,
        .zon_data = null,
        .timeout_ms = null,
    };
    const data = [_]struct { key: []const u8, value: grain_court.ZonFormat.ZonValue }{
        .{ .key = "test_key", .value = grain_court.ZonFormat.ZonValue.from_u32(42) },
    };
    try grain_court.LlmProvider.auto_encode_request_to_zon(&request, &data, allocator);
    try testing.expect(request.use_zon_format == false);
    try testing.expect(request.zon_data == null);
}

test "zon format round trip test" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const pairs = [_]struct {
        key: []const u8,
        value: grain_court.ZonFormat.ZonValue,
    }{
        .{
            .key = "total_executions",
            .value = grain_court.ZonFormat.ZonValue.from_u32(1000),
        },
        .{
            .key = "active",
            .value = grain_court.ZonFormat.ZonValue.from_bool(true),
        },
        .{
            .key = "name",
            .value = grain_court.ZonFormat.ZonValue.from_string("backup"),
        },
    };
    const result = try grain_court.ZonFormat.round_trip_test(&pairs, allocator);
    defer result.deinit();
    try testing.expect(result.success);
    try testing.expect(result.data_integrity);
    try testing.expect(result.encoded_data.len > 0);
    try testing.expect(result.decoded_pairs.len == 3);
}

test "zon format benchmark encode" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const pairs = [_]struct {
        key: []const u8,
        value: grain_court.ZonFormat.ZonValue,
    }{
        .{
            .key = "total_executions",
            .value = grain_court.ZonFormat.ZonValue.from_u32(1000),
        },
    };
    const elapsed_ms = try grain_court.ZonFormat.benchmark_encode(&pairs, 100, allocator);
    try testing.expect(elapsed_ms >= 0);
}

test "zon format benchmark decode" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const zon_str = "total_executions:1000\nactive:T";
    const elapsed_ms = try grain_court.ZonFormat.benchmark_decode(zon_str, 100, allocator);
    try testing.expect(elapsed_ms >= 0);
}
