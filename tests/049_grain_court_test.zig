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

