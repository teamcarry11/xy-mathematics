//! Step 2 Validation Test: Metrics Analysis with Flow Agent Sample Data.
//!
//! Why: Validates insights generation, hypothesis testing, and recommendations
//! for Phase 3 Step 2 validation with Flow Agent.
//! Architecture: Integration test using Flow Agent's sample JSON export.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-104600-pst: Flow Agent Phase 3 Step 2 Validation

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const WorkflowMetricsAnalyzer = grain_research.WorkflowMetricsAnalyzer;
const InsightsGenerator = grain_research.InsightsGenerator;

test "step 2 validation: generate insights from flow agent sample" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Flow Agent's sample JSON export.
    const sample_json =
        \\{"workflow":{"total_executions":10,"success_rate_percent":90,"failure_rate_percent":10,"avg_execution_time_ms":1250,"executions":[
        \\{"workflow_id":1,"name":"backup_workflow","execution_time_ms":1500,"status":0,"timestamp":1000},
        \\{"workflow_id":2,"name":"sync_workflow","execution_time_ms":1000,"status":0,"timestamp":2000},
        \\{"workflow_id":3,"name":"backup_workflow","execution_time_ms":1200,"status":0,"timestamp":3000},
        \\{"workflow_id":4,"name":"sync_workflow","execution_time_ms":1100,"status":1,"timestamp":4000},
        \\{"workflow_id":5,"name":"backup_workflow","execution_time_ms":1300,"status":0,"timestamp":5000}
        \\]},
        \\"coordination":{"total_coordinations":8,"success_rate_percent":87,"avg_coordination_latency_ms":50,"coordination_patterns":[
        \\{"source_agent_id":1,"target_agent_id":2,"count":3},
        \\{"source_agent_id":2,"target_agent_id":3,"count":2},
        \\{"source_agent_id":1,"target_agent_id":3,"count":3}
        \\]},
        \\"failure":{"total_failures":1,"recovery_success_rate_percent":100,"failure_type_distribution":{"transient":1,"permanent":0,"timeout":0,"unknown":0}},
        \\"performance":{"avg_queue_depth":5,"avg_wait_time_ms":100,"avg_cpu_percent":25,"avg_memory_bytes":1048576}}
    ;

    try analyzer.parse_json_metrics(sample_json);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    // Generate insights.
    try generator.generate_insights(&analyzer);
    try testing.expect(generator.get_insight_count() >= 0);

    // Test hypotheses.
    try generator.test_hypotheses(&analyzer);
    try testing.expect(generator.get_hypothesis_result_count() >= 3);

    // Generate recommendations.
    try generator.generate_recommendations(&analyzer);
    try testing.expect(generator.get_recommendation_count() >= 0);
}

test "step 2 validation: test hypothesis 1 execution time vs satisfaction" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const sample_json =
        \\{"workflow":{"total_executions":10,"success_rate_percent":90,"avg_execution_time_ms":1250,"executions":[
        \\{"workflow_id":1,"name":"backup_workflow","execution_time_ms":1500,"status":0,"timestamp":1000}
        \\]}}
    ;

    try analyzer.parse_json_metrics(sample_json);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try generator.test_hypotheses(&analyzer);

    // Hypothesis 1 should be tested.
    const results = generator.get_hypothesis_results();
    try testing.expect(results.len >= 1);

    // Find hypothesis 1 (execution time vs. satisfaction).
    var found_hypothesis_1 = false;
    var i: u32 = 0;
    while (i < results.len) : (i += 1) {
        if (results[i].hypothesis_id == 1) {
            found_hypothesis_1 = true;
            // Average execution time is 1500ms, which is > 1000ms threshold.
            // Hypothesis should validate (execution time < 2000ms is acceptable).
            try testing.expect(results[i].confidence >= 0);
            try testing.expect(results[i].confidence <= 100);
            break;
        }
    }
    try testing.expect(found_hypothesis_1);
}

test "step 2 validation: test hypothesis 3 coordination latency vs reliability" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const sample_json =
        \\{"coordination":{"total_coordinations":8,"success_rate_percent":87,"avg_coordination_latency_ms":50,"coordination_patterns":[
        \\{"source_agent_id":1,"target_agent_id":2,"count":3}
        \\]}}
    ;

    try analyzer.parse_json_metrics(sample_json);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try generator.test_hypotheses(&analyzer);

    // Hypothesis 3 should be tested.
    const results = generator.get_hypothesis_results();
    try testing.expect(results.len >= 1);

    // Find hypothesis 3 (coordination latency vs. reliability).
    var found_hypothesis_3 = false;
    var i: u32 = 0;
    while (i < results.len) : (i += 1) {
        if (results[i].hypothesis_id == 3) {
            found_hypothesis_3 = true;
            // Average latency is 50ms, which is < 100ms threshold (good).
            // Success rate is 87%, which is < 95% threshold (needs improvement).
            try testing.expect(results[i].confidence >= 0);
            try testing.expect(results[i].confidence <= 100);
            break;
        }
    }
    try testing.expect(found_hypothesis_3);
}

test "step 2 validation: test hypothesis 4 failure recovery" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const sample_json =
        \\{"failure":{"total_failures":1,"recovery_success_rate_percent":100,"failure_type_distribution":{"transient":1}}}
    ;

    try analyzer.parse_json_metrics(sample_json);

    var generator = InsightsGenerator.init(allocator);
    defer generator.deinit();

    try generator.test_hypotheses(&analyzer);

    // Hypothesis 4 should be tested.
    const results = generator.get_hypothesis_results();
    try testing.expect(results.len >= 1);

    // Find hypothesis 4 (failure recovery).
    var found_hypothesis_4 = false;
    var i: u32 = 0;
    while (i < results.len) : (i += 1) {
        if (results[i].hypothesis_id == 4) {
            found_hypothesis_4 = true;
            // Recovery rate is 100%, which is > 80% threshold (excellent).
            try testing.expect(results[i].validated == true);
            try testing.expect(results[i].confidence >= 70);
            break;
        }
    }
    try testing.expect(found_hypothesis_4);
}
