//! Grain Research Insights Generator: Generate insights from workflow metrics.
//!
//! Why: Provides insights generation capabilities for Workflow Observatory Phase 3
//! collaboration. Generates insights, tests hypotheses, and provides recommendations
//! based on analyzed workflow metrics.
//! Architecture: Bounded insight buffers, iterative algorithms, hypothesis testing.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-21-094300-pst: Grain Research Agent Phase 3 (Flow Agent Collaboration)

const std = @import("std");
const workflow_metrics_analyzer = @import("workflow_metrics_analyzer.zig");
const WorkflowMetricsAnalyzer = workflow_metrics_analyzer.WorkflowMetricsAnalyzer;

// Bounded: Max insights to generate.
pub const MAX_INSIGHTS: u32 = 1_000;

// Bounded: Max insight message length.
pub const MAX_INSIGHT_MESSAGE_LEN: u32 = 512;

// Bounded: Max recommendations to generate.
pub const MAX_RECOMMENDATIONS: u32 = 100;

// Bounded: Max recommendation message length.
pub const MAX_RECOMMENDATION_MESSAGE_LEN: u32 = 512;

// Insight type.
pub const InsightType = enum(u8) {
    performance = 0,
    reliability = 1,
    coordination = 2,
    failure = 3,
    recommendation = 4,
};

// Insight: Represents a single insight.
pub const Insight = struct {
    insight_type: InsightType,
    message: []const u8,
    severity: InsightSeverity,
    metric_value: u64,
    threshold: u64,
};

// Insight severity.
pub const InsightSeverity = enum(u8) {
    low = 0,
    medium = 1,
    high = 2,
    critical = 3,
};

// Recommendation: Represents a single recommendation.
pub const Recommendation = struct {
    category: RecommendationCategory,
    message: []const u8,
    priority: RecommendationPriority,
};

// Recommendation category.
pub const RecommendationCategory = enum(u8) {
    performance = 0,
    reliability = 1,
    coordination = 2,
    failure_recovery = 3,
    optimization = 4,
};

// Recommendation priority.
pub const RecommendationPriority = enum(u8) {
    low = 0,
    medium = 1,
    high = 2,
    urgent = 3,
};

// Hypothesis test result.
pub const HypothesisTestResult = struct {
    hypothesis_id: u32,
    hypothesis_name: []const u8,
    validated: bool,
    confidence: u32, // 0-100
    evidence: []const u8,
};

// Insights generator.
pub const InsightsGenerator = struct {
    allocator: std.mem.Allocator,
    insights: std.ArrayListUnmanaged(Insight),
    recommendations: std.ArrayListUnmanaged(Recommendation),
    hypothesis_results: std.ArrayListUnmanaged(HypothesisTestResult),

    // Initialize insights generator.
    pub fn init(allocator: std.mem.Allocator) InsightsGenerator {
        std.debug.assert(allocator.ptr != null);

        return InsightsGenerator{
            .allocator = allocator,
            .insights = .{},
            .recommendations = .{},
            .hypothesis_results = .{},
        };
    }

    // Deinitialize and free memory.
    pub fn deinit(self: *InsightsGenerator) void {
        var i: u32 = 0;
        while (i < self.insights.items.len) : (i += 1) {
            self.allocator.free(self.insights.items[i].message);
        }
        self.insights.deinit(self.allocator);

        i = 0;
        while (i < self.recommendations.items.len) : (i += 1) {
            self.allocator.free(self.recommendations.items[i].message);
        }
        self.recommendations.deinit(self.allocator);

        i = 0;
        while (i < self.hypothesis_results.items.len) : (i += 1) {
            self.allocator.free(self.hypothesis_results.items[i].hypothesis_name);
            self.allocator.free(self.hypothesis_results.items[i].evidence);
        }
        self.hypothesis_results.deinit(self.allocator);

        self.* = undefined;
    }

    // Generate insights from workflow metrics analyzer.
    pub fn generate_insights(
        self: *InsightsGenerator,
        analyzer: *const WorkflowMetricsAnalyzer,
    ) !void {
        std.debug.assert(analyzer.allocator.ptr != null);

        // Generate workflow performance insights.
        try self.generate_workflow_insights(analyzer);

        // Generate coordination insights.
        try self.generate_coordination_insights(analyzer);

        // Generate failure insights.
        try self.generate_failure_insights(analyzer);

        // Generate performance insights.
        try self.generate_performance_insights(analyzer);
    }

    // Generate workflow performance insights.
    fn generate_workflow_insights(
        self: *InsightsGenerator,
        analyzer: *const WorkflowMetricsAnalyzer,
    ) !void {
        const avg_execution_time = analyzer.get_average_execution_time_ms();
        const success_rate = analyzer.get_success_rate_percent();

        // Check execution time threshold (1000ms for simple, 5000ms for complex).
        if (avg_execution_time > 5000) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "High execution time: {d}ms (threshold: 5000ms)",
                .{avg_execution_time},
            );
            errdefer self.allocator.free(message);

            const insight = Insight{
                .insight_type = .performance,
                .message = message,
                .severity = .high,
                .metric_value = avg_execution_time,
                .threshold = 5000,
            };

            try self.insights.append(self.allocator, insight);
        }

        // Check success rate threshold (95%).
        if (success_rate < 95) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "Low success rate: {d}% (threshold: 95%)",
                .{success_rate},
            );
            errdefer self.allocator.free(message);

            const insight = Insight{
                .insight_type = .reliability,
                .message = message,
                .severity = if (success_rate < 80) .critical else .medium,
                .metric_value = success_rate,
                .threshold = 95,
            };

            try self.insights.append(self.allocator, insight);
        }
    }

    // Generate coordination insights.
    fn generate_coordination_insights(
        self: *InsightsGenerator,
        analyzer: *const WorkflowMetricsAnalyzer,
    ) !void {
        const avg_latency = analyzer.get_average_coordination_latency_ms();
        const success_rate = analyzer.get_coordination_success_rate_percent();

        // Check coordination latency threshold (100ms).
        if (avg_latency > 100) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "High coordination latency: {d}ms (threshold: 100ms)",
                .{avg_latency},
            );
            errdefer self.allocator.free(message);

            const insight = Insight{
                .insight_type = .coordination,
                .message = message,
                .severity = .medium,
                .metric_value = avg_latency,
                .threshold = 100,
            };

            try self.insights.append(self.allocator, insight);
        }

        // Check coordination success rate threshold (95%).
        if (success_rate < 95) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "Low coordination success rate: {d}% (threshold: 95%)",
                .{success_rate},
            );
            errdefer self.allocator.free(message);

            const insight = Insight{
                .insight_type = .coordination,
                .message = message,
                .severity = .high,
                .metric_value = success_rate,
                .threshold = 95,
            };

            try self.insights.append(self.allocator, insight);
        }
    }

    // Generate failure insights.
    fn generate_failure_insights(
        self: *InsightsGenerator,
        analyzer: *const WorkflowMetricsAnalyzer,
    ) !void {
        const recovery_rate = analyzer.get_failure_recovery_success_rate_percent();
        const failure_count = analyzer.get_failure_metric_count();

        // Check recovery success rate threshold (80%).
        if (recovery_rate < 80 and failure_count > 0) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "Low recovery success rate: {d}% (threshold: 80%)",
                .{recovery_rate},
            );
            errdefer self.allocator.free(message);

            const insight = Insight{
                .insight_type = .failure,
                .message = message,
                .severity = .medium,
                .metric_value = recovery_rate,
                .threshold = 80,
            };

            try self.insights.append(self.allocator, insight);
        }
    }

    // Generate performance insights.
    fn generate_performance_insights(
        self: *InsightsGenerator,
        analyzer: *const WorkflowMetricsAnalyzer,
    ) !void {
        _ = analyzer;
        // Performance insights would require performance metrics.
        // For now, this is a placeholder.
    }

    // Test hypotheses from research document.
    pub fn test_hypotheses(
        self: *InsightsGenerator,
        analyzer: *const WorkflowMetricsAnalyzer,
    ) !void {
        // Hypothesis 1: Workflow execution time correlates with user satisfaction.
        try self.test_hypothesis_1(analyzer);

        // Hypothesis 3: Agent coordination latency affects workflow reliability.
        try self.test_hypothesis_3(analyzer);

        // Hypothesis 4: Most failures are transient and recoverable.
        try self.test_hypothesis_4(analyzer);
    }

    // Test Hypothesis 1: Execution time vs. satisfaction.
    fn test_hypothesis_1(
        self: *InsightsGenerator,
        analyzer: *const WorkflowMetricsAnalyzer,
    ) !void {
        const avg_time = analyzer.get_average_execution_time_ms();
        const success_rate = analyzer.get_success_rate_percent();

        // Lower execution time should correlate with higher success rate.
        const validated = avg_time < 1000 and success_rate >= 95;
        const confidence = if (validated) 80 else 40;

        const hypothesis_name = try std.fmt.allocPrint(
            self.allocator,
            "Workflow execution time correlates with user satisfaction",
            .{},
        );
        errdefer self.allocator.free(hypothesis_name);

        const evidence = try std.fmt.allocPrint(
            self.allocator,
            "Avg execution time: {d}ms, Success rate: {d}%",
            .{ avg_time, success_rate },
        );
        errdefer self.allocator.free(evidence);

        const result = HypothesisTestResult{
            .hypothesis_id = 1,
            .hypothesis_name = hypothesis_name,
            .validated = validated,
            .confidence = confidence,
            .evidence = evidence,
        };

        try self.hypothesis_results.append(self.allocator, result);
    }

    // Test Hypothesis 3: Coordination latency vs. reliability.
    fn test_hypothesis_3(
        self: *InsightsGenerator,
        analyzer: *const WorkflowMetricsAnalyzer,
    ) !void {
        const avg_latency = analyzer.get_average_coordination_latency_ms();
        const success_rate = analyzer.get_coordination_success_rate_percent();

        // Lower coordination latency should correlate with higher success rate.
        const validated = avg_latency < 100 and success_rate >= 95;
        const confidence = if (validated) 75 else 35;

        const hypothesis_name = try std.fmt.allocPrint(
            self.allocator,
            "Agent coordination latency affects workflow reliability",
            .{},
        );
        errdefer self.allocator.free(hypothesis_name);

        const evidence = try std.fmt.allocPrint(
            self.allocator,
            "Avg latency: {d}ms, Success rate: {d}%",
            .{ avg_latency, success_rate },
        );
        errdefer self.allocator.free(evidence);

        const result = HypothesisTestResult{
            .hypothesis_id = 3,
            .hypothesis_name = hypothesis_name,
            .validated = validated,
            .confidence = confidence,
            .evidence = evidence,
        };

        try self.hypothesis_results.append(self.allocator, result);
    }

    // Test Hypothesis 4: Transient failures and recovery.
    fn test_hypothesis_4(
        self: *InsightsGenerator,
        analyzer: *const WorkflowMetricsAnalyzer,
    ) !void {
        const recovery_rate = analyzer.get_failure_recovery_success_rate_percent();
        const failure_count = analyzer.get_failure_metric_count();

        // Most failures should be recoverable (recovery rate > 80%).
        const validated = recovery_rate >= 80 or failure_count == 0;
        const confidence = if (validated) 70 else 30;

        const hypothesis_name = try std.fmt.allocPrint(
            self.allocator,
            "Most failures are transient and recoverable",
            .{},
        );
        errdefer self.allocator.free(hypothesis_name);

        const evidence = try std.fmt.allocPrint(
            self.allocator,
            "Recovery rate: {d}%, Failure count: {d}",
            .{ recovery_rate, failure_count },
        );
        errdefer self.allocator.free(evidence);

        const result = HypothesisTestResult{
            .hypothesis_id = 4,
            .hypothesis_name = hypothesis_name,
            .validated = validated,
            .confidence = confidence,
            .evidence = evidence,
        };

        try self.hypothesis_results.append(self.allocator, result);
    }

    // Generate recommendations based on insights.
    pub fn generate_recommendations(
        self: *InsightsGenerator,
        analyzer: *const WorkflowMetricsAnalyzer,
    ) !void {
        std.debug.assert(analyzer.allocator.ptr != null);

        const avg_execution_time = analyzer.get_average_execution_time_ms();
        const success_rate = analyzer.get_success_rate_percent();
        const avg_latency = analyzer.get_average_coordination_latency_ms();
        const recovery_rate = analyzer.get_failure_recovery_success_rate_percent();

        // Performance recommendations.
        if (avg_execution_time > 5000) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "Optimize workflow execution: Consider parallelization or caching",
                .{},
            );
            errdefer self.allocator.free(message);

            const rec = Recommendation{
                .category = .performance,
                .message = message,
                .priority = .high,
            };

            try self.recommendations.append(self.allocator, rec);
        }

        // Reliability recommendations.
        if (success_rate < 95) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "Improve workflow reliability: Investigate failure patterns",
                .{},
            );
            errdefer self.allocator.free(message);

            const rec = Recommendation{
                .category = .reliability,
                .message = message,
                .priority = if (success_rate < 80) .urgent else .high,
            };

            try self.recommendations.append(self.allocator, rec);
        }

        // Coordination recommendations.
        if (avg_latency > 100) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "Reduce coordination latency: Optimize agent communication",
                .{},
            );
            errdefer self.allocator.free(message);

            const rec = Recommendation{
                .category = .coordination,
                .message = message,
                .priority = .medium,
            };

            try self.recommendations.append(self.allocator, rec);
        }

        // Failure recovery recommendations.
        if (recovery_rate < 80) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "Improve failure recovery: Implement retry with backoff",
                .{},
            );
            errdefer self.allocator.free(message);

            const rec = Recommendation{
                .category = .failure_recovery,
                .message = message,
                .priority = .high,
            };

            try self.recommendations.append(self.allocator, rec);
        }
    }

    // Get insight count.
    pub fn get_insight_count(self: *const InsightsGenerator) u32 {
        std.debug.assert(self.insights.items.len <= MAX_INSIGHTS);

        return @intCast(self.insights.items.len);
    }

    // Get recommendation count.
    pub fn get_recommendation_count(self: *const InsightsGenerator) u32 {
        std.debug.assert(self.recommendations.items.len <= MAX_RECOMMENDATIONS);

        return @intCast(self.recommendations.items.len);
    }

    // Get hypothesis result count.
    pub fn get_hypothesis_result_count(self: *const InsightsGenerator) u32 {
        std.debug.assert(self.hypothesis_results.items.len <= MAX_INSIGHTS);

        return @intCast(self.hypothesis_results.items.len);
    }
};
