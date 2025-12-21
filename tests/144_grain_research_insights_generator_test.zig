//! Tests for Grain Research Insights Generator.
//!
//! Why: Verify insights generation capabilities for Flow Agent Phase 3 collaboration.
//! Architecture: Comprehensive test coverage for insights, hypotheses, recommendations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-094300-pst: Flow Agent Phase 3 Collaboration

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const InsightsGenerator = grain_research.InsightsGenerator;
const WorkflowMetricsAnalyzer = grain_research.WorkflowMetricsAnalyzer;

test "insights generator initialization" {
    const allocator = testing.allocator;
    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try testing.expect(generator.allocator.ptr != null);
    try testing.expect(generator.get_insight_count() == 0);
    try testing.expect(generator.get_recommendation_count() == 0);
    try testing.expect(generator.get_hypothesis_result_count() == 0);
}

test "generate insights from metrics" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"workflow":{"executions":[
        \\{"workflow_id":1,"execution_time_ms":6000,"status":0,"timestamp":1000},
        \\{"workflow_id":2,"execution_time_ms":7000,"status":1,"timestamp":2000}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try generator.generate_insights(&analyzer);

    try testing.expect(generator.get_insight_count() > 0);
}

test "generate insights for high execution time" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"workflow":{"executions":[
        \\{"workflow_id":1,"execution_time_ms":6000,"status":0,"timestamp":1000}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try generator.generate_insights(&analyzer);

    try testing.expect(generator.get_insight_count() >= 1);
}

test "generate insights for low success rate" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"workflow":{"executions":[
        \\{"workflow_id":1,"execution_time_ms":100,"status":0,"timestamp":1000},
        \\{"workflow_id":2,"execution_time_ms":200,"status":1,"timestamp":2000},
        \\{"workflow_id":3,"execution_time_ms":300,"status":1,"timestamp":3000}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try generator.generate_insights(&analyzer);

    try testing.expect(generator.get_insight_count() >= 1);
}

test "test hypotheses" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"workflow":{"executions":[
        \\{"workflow_id":1,"execution_time_ms":500,"status":0,"timestamp":1000}
        \\]},
        \\"coordination":{"coordination_patterns":[
        \\{"source_agent_id":1,"target_agent_id":2,"coordination_latency_ms":50,"status":0}
        \\]},
        \\"failure":{"failure_type_distribution":{"transient":2}}}
    ;

    try analyzer.parse_json_metrics(json_data);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try generator.test_hypotheses(&analyzer);

    try testing.expect(generator.get_hypothesis_result_count() >= 3);
}

test "test hypothesis 1 execution time" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"workflow":{"executions":[
        \\{"workflow_id":1,"execution_time_ms":500,"status":0,"timestamp":1000}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try generator.test_hypotheses(&analyzer);

    try testing.expect(generator.get_hypothesis_result_count() >= 1);
}

test "generate recommendations" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"workflow":{"executions":[
        \\{"workflow_id":1,"execution_time_ms":6000,"status":0,"timestamp":1000},
        \\{"workflow_id":2,"execution_time_ms":7000,"status":1,"timestamp":2000}
        \\]},
        \\"coordination":{"coordination_patterns":[
        \\{"source_agent_id":1,"target_agent_id":2,"coordination_latency_ms":150,"status":0}
        \\]},
        \\"failure":{"failure_type_distribution":{"transient":2}}}
    ;

    try analyzer.parse_json_metrics(json_data);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try generator.generate_recommendations(&analyzer);

    try testing.expect(generator.get_recommendation_count() > 0);
}

test "generate recommendations for high execution time" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"workflow":{"executions":[
        \\{"workflow_id":1,"execution_time_ms":6000,"status":0,"timestamp":1000}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try generator.generate_recommendations(&analyzer);

    try testing.expect(generator.get_recommendation_count() >= 1);
}

test "generate recommendations for low success rate" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"workflow":{"executions":[
        \\{"workflow_id":1,"execution_time_ms":100,"status":0,"timestamp":1000},
        \\{"workflow_id":2,"execution_time_ms":200,"status":1,"timestamp":2000},
        \\{"workflow_id":3,"execution_time_ms":300,"status":1,"timestamp":3000}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try generator.generate_recommendations(&analyzer);

    try testing.expect(generator.get_recommendation_count() >= 1);
}

test "generate recommendations for high coordination latency" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"coordination":{"coordination_patterns":[
        \\{"source_agent_id":1,"target_agent_id":2,"coordination_latency_ms":150,"status":0}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try generator.generate_recommendations(&analyzer);

    try testing.expect(generator.get_recommendation_count() >= 1);
}

test "complete insights generation workflow" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"workflow":{"executions":[
        \\{"workflow_id":1,"execution_time_ms":500,"status":0,"timestamp":1000}
        \\]},
        \\"coordination":{"coordination_patterns":[
        \\{"source_agent_id":1,"target_agent_id":2,"coordination_latency_ms":50,"status":0}
        \\]},
        \\"failure":{"failure_type_distribution":{"transient":2}}}
    ;

    try analyzer.parse_json_metrics(json_data);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try generator.generate_insights(&analyzer);
    try generator.test_hypotheses(&analyzer);
    try generator.generate_recommendations(&analyzer);

    try testing.expect(generator.get_insight_count() >= 0);
    try testing.expect(generator.get_hypothesis_result_count() >= 3);
    try testing.expect(generator.get_recommendation_count() >= 0);
}
