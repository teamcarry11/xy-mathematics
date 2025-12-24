//! Grain Research ZON Format Phase 4: Integration Validation Implementation.
//!
//! Why: Implements Phase 4 Integration Validation using Court Agent's ZON module.
//! Validates round-trip conversion, performance benchmarking, and integration with
//! Research Agent's Phase 4 framework.
//! Architecture: Integration with Court Agent ZON module, Research Agent framework.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-23-121000-pst: ZON Format Phase 4 Integration Validation

const std = @import("std");
const grain_court = @import("grain_court");
const ZonFormat = grain_court.ZonFormat;
const ZonValue = ZonFormat.ZonValue;
const RoundTripTestResult = ZonFormat.RoundTripTestResult;
const encode_zon = ZonFormat.encode_zon;
const decode_zon = ZonFormat.decode_zon;
const zon_integration_validation = @import("zon_integration_validation.zig");
const IntegrationValidationFramework = zon_integration_validation.IntegrationValidationFramework;
const RoundTripResult = zon_integration_validation.RoundTripResult;
const PerformanceBenchmarkResult = zon_integration_validation.PerformanceBenchmarkResult;
const IntegrationValidationResult = zon_integration_validation.IntegrationValidationResult;

// Bounded: Max test iterations for performance benchmarks.
pub const MAX_BENCHMARK_ITERATIONS: u32 = 10000;

// Bounded: Max test data size (10MB).
pub const MAX_TEST_DATA_SIZE: u32 = 10 * 1024 * 1024;

// Phase 4 integration validator.
pub const Phase4IntegrationValidator = struct {
    allocator: std.mem.Allocator,
    framework: IntegrationValidationFramework,

    // Initialize Phase 4 integration validator.
    pub fn init(allocator: std.mem.Allocator) Phase4IntegrationValidator {
        return Phase4IntegrationValidator{
            .allocator = allocator,
            .framework = IntegrationValidationFramework.init(allocator),
        };
    }

    // Deinitialize Phase 4 integration validator.
    pub fn deinit(self: *Phase4IntegrationValidator) void {
        self.framework.deinit();
    }

    // Perform round-trip test using Court Agent ZON module.
    pub fn perform_round_trip_test(
        self: *Phase4IntegrationValidator,
        test_name: []const u8,
        pairs: []const struct { key: []const u8, value: ZonValue },
    ) !void {
        std.debug.assert(test_name.len > 0);
        std.debug.assert(test_name.len <= 128);
        std.debug.assert(pairs.len > 0);
        std.debug.assert(pairs.len <= 1000);

        // Use Court Agent's round_trip_test function.
        const court_result = try ZonFormat.round_trip_test(pairs, self.allocator);
        defer court_result.deinit();

        // Convert decoded pairs to string for Research Agent format.
        var decoded_str = std.ArrayList(u8).init(self.allocator);
        defer decoded_str.deinit();

        var i: u32 = 0;
        while (i < court_result.decoded_pairs.len) : (i += 1) {
            if (i > 0) {
                try decoded_str.appendSlice(",");
            }
            try decoded_str.appendSlice(court_result.decoded_pairs[i].key);
            try decoded_str.appendSlice(":");
            switch (court_result.decoded_pairs[i].value.value_type) {
                .bool_value => {
                    if (court_result.decoded_pairs[i].value.bool_val) {
                        try decoded_str.appendSlice("T");
                    } else {
                        try decoded_str.appendSlice("F");
                    }
                },
                .u32_value => {
                    const num_str = try std.fmt.allocPrint(self.allocator, "{}", .{court_result.decoded_pairs[i].value.u32_val});
                    defer self.allocator.free(num_str);
                    try decoded_str.appendSlice(num_str);
                },
                .string_value => {
                    const str = court_result.decoded_pairs[i].value.string_val[0..court_result.decoded_pairs[i].value.string_val_len];
                    try decoded_str.appendSlice(str);
                },
                else => {
                    try decoded_str.appendSlice("null");
                },
            }
        }

        // Convert original pairs to string for Research Agent format.
        var original_str = std.ArrayList(u8).init(self.allocator);
        defer original_str.deinit();

        i = 0;
        while (i < pairs.len) : (i += 1) {
            if (i > 0) {
                try original_str.appendSlice(",");
            }
            try original_str.appendSlice(pairs[i].key);
            try original_str.appendSlice(":");
            switch (pairs[i].value.value_type) {
                .bool_value => {
                    if (pairs[i].value.bool_val) {
                        try original_str.appendSlice("T");
                    } else {
                        try original_str.appendSlice("F");
                    }
                },
                .u32_value => {
                    const num_str = try std.fmt.allocPrint(self.allocator, "{}", .{pairs[i].value.u32_val});
                    defer self.allocator.free(num_str);
                    try original_str.appendSlice(num_str);
                },
                .string_value => {
                    const str = pairs[i].value.string_val[0..pairs[i].value.string_val_len];
                    try original_str.appendSlice(str);
                },
                else => {
                    try original_str.appendSlice("null");
                },
            }
        }

        // Create Research Agent RoundTripResult.
        // Note: Framework will duplicate the data, so we can free after adding.
        const original_data = try original_str.toOwnedSlice();
        const encoded_data = try self.allocator.dupe(u8, court_result.encoded_data);
        const decoded_data = try decoded_str.toOwnedSlice();

        // Create empty error message for round-trip result.
        const empty_error = try self.allocator.dupe(u8, "");

        const research_result = RoundTripResult.init(
            original_data,
            encoded_data,
            decoded_data,
            court_result.success,
            court_result.data_integrity,
            empty_error,
        );

        // Add to framework (framework will own the data).
        try self.framework.add_round_trip_result(research_result);

        // Free original allocations (framework has duplicated them).
        self.allocator.free(original_data);
        self.allocator.free(encoded_data);
        self.allocator.free(decoded_data);
        self.allocator.free(empty_error);
    }

    // Perform performance benchmark using Court Agent ZON module.
    pub fn perform_performance_benchmark(
        self: *Phase4IntegrationValidator,
        operation_name: []const u8,
        pairs: []const struct { key: []const u8, value: ZonValue },
        iterations: u32,
    ) !void {
        std.debug.assert(operation_name.len > 0);
        std.debug.assert(operation_name.len <= 128);
        std.debug.assert(pairs.len > 0);
        std.debug.assert(iterations > 0);
        std.debug.assert(iterations <= MAX_BENCHMARK_ITERATIONS);

        // Benchmark encoding.
        const encode_ms = try ZonFormat.benchmark_encode(pairs, iterations, self.allocator);

        // Encode once to get data for decode benchmark.
        const encode_result = try ZonFormat.encode_zon(pairs, self.allocator);
        defer encode_result.deinit();
        const encoded_data = try self.allocator.dupe(u8, encode_result.data[0..encode_result.len]);
        defer self.allocator.free(encoded_data);

        // Benchmark decoding.
        const decode_ms = try ZonFormat.benchmark_decode(encoded_data, iterations, self.allocator);

        // Create performance benchmark results.
        const encode_result_perf = PerformanceBenchmarkResult.init(
            "encoding",
            iterations,
            encode_ms,
            encode_ms / iterations,
            encode_ms / iterations,
            encode_ms / iterations,
        );
        try self.framework.add_performance_result(encode_result_perf);

        const decode_result_perf = PerformanceBenchmarkResult.init(
            "decoding",
            iterations,
            decode_ms,
            decode_ms / iterations,
            decode_ms / iterations,
            decode_ms / iterations,
        );
        try self.framework.add_performance_result(decode_result_perf);
    }

    // Perform complete integration validation test.
    pub fn perform_integration_validation(
        self: *Phase4IntegrationValidator,
        test_name: []const u8,
        pairs: []const struct { key: []const u8, value: ZonValue },
        iterations: u32,
    ) !void {
        std.debug.assert(test_name.len > 0);
        std.debug.assert(test_name.len <= 128);
        std.debug.assert(pairs.len > 0);
        std.debug.assert(iterations > 0);
        std.debug.assert(iterations <= MAX_BENCHMARK_ITERATIONS);

        const start_time = std.time.timestamp();
        var error_message: []const u8 = "";

        // Perform round-trip test.
        try self.perform_round_trip_test(test_name, pairs);

        // Get round-trip results to check success.
        const round_trip_results = self.framework.get_round_trip_results();
        var round_trip_success: bool = false;
        if (round_trip_results.len > 0) {
            const last_result = round_trip_results[round_trip_results.len - 1];
            round_trip_success = last_result.success and last_result.data_integrity;
            if (!round_trip_success) {
                error_message = "Round-trip test failed";
            }
        }

        // Perform performance benchmarks.
        try self.perform_performance_benchmark(test_name, pairs, iterations);

        // Get performance results.
        const perf_results = self.framework.get_performance_results();
        var encoding_ms: u64 = 0;
        var decoding_ms: u64 = 0;
        if (perf_results.len >= 2) {
            encoding_ms = perf_results[perf_results.len - 2].average_time_ms;
            decoding_ms = perf_results[perf_results.len - 1].average_time_ms;
        }

        const end_time = std.time.timestamp();
        const total_ms = (@as(u64, @intCast(end_time)) - @as(u64, @intCast(start_time))) * 1000;

        // Create integration validation result.
        // Note: Framework will duplicate the data, so we can free after adding.
        const error_msg_copy = try self.allocator.dupe(u8, error_message);
        const test_name_copy = try self.allocator.dupe(u8, test_name);

        const validation_result = IntegrationValidationResult.init(
            test_name_copy,
            round_trip_success,
            round_trip_success,
            encoding_ms,
            decoding_ms,
            error_msg_copy,
        );

        try self.framework.add_test_result(validation_result);

        // Free original allocations (framework has duplicated them).
        self.allocator.free(test_name_copy);
        self.allocator.free(error_msg_copy);
    }

    // Get framework for analysis.
    pub fn get_framework(self: *const Phase4IntegrationValidator) *const IntegrationValidationFramework {
        return &self.framework;
    }
};
