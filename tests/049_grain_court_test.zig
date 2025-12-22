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

