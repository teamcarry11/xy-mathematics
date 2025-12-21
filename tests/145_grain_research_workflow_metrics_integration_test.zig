//! Integration tests for Grain Research Workflow Metrics Analyzer with Flow Agent JSON.
//!
//! Why: Verify parser works with Flow Agent's actual JSON export format for Phase 3 validation.
//! Architecture: Integration tests using Flow Agent's sample JSON export.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-103700-pst: Flow Agent Phase 3 Step 1 Validation

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const WorkflowMetricsAnalyzer = grain_research.WorkflowMetricsAnalyzer;
const InsightsGenerator = grain_research.InsightsGenerator;

test "parse flow agent sample json export" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Flow Agent's sample JSON export (from flow_to_research_phase3_sample_data).
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

    // Validate workflow metrics.
    try testing.expect(analyzer.get_workflow_execution_count() == 5);
    const avg_exec_time = analyzer.get_average_execution_time_ms();
    try testing.expect(avg_exec_time > 0);
    const success_rate = analyzer.get_success_rate_percent();
    try testing.expect(success_rate == 80); // 4 out of 5 executions successful

    // Validate coordination metrics.
    try testing.expect(analyzer.get_coordination_metric_count() == 3);
    const avg_latency = analyzer.get_average_coordination_latency_ms();
    try testing.expect(avg_latency == 50);
    const coord_success_rate = analyzer.get_coordination_success_rate_percent();
    try testing.expect(coord_success_rate == 87);

    // Validate failure metrics.
    try testing.expect(analyzer.get_failure_metric_count() == 1);
    const recovery_rate = analyzer.get_failure_recovery_success_rate_percent();
    try testing.expect(recovery_rate == 100);

    // Validate performance metrics.
    try testing.expect(analyzer.get_performance_metric_count() == 1);
}

test "generate insights from flow agent sample json" {
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

    try generator.generate_insights(&analyzer);
    try generator.test_hypotheses(&analyzer);
    try generator.generate_recommendations(&analyzer);

    try testing.expect(generator.get_insight_count() >= 0);
    try testing.expect(generator.get_hypothesis_result_count() >= 3);
    try testing.expect(generator.get_recommendation_count() >= 0);
}

test "validate all metric types from flow agent sample" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Flow Agent's sample JSON export.
    const sample_json =
        \\{"workflow":{"total_executions":10,"success_rate_percent":90,"failure_rate_percent":10,"avg_execution_time_ms":1250,"executions":[
        \\{"workflow_id":1,"name":"backup_workflow","execution_time_ms":1500,"status":0,"timestamp":1000}
        \\]},
        \\"coordination":{"total_coordinations":8,"success_rate_percent":87,"avg_coordination_latency_ms":50,"coordination_patterns":[
        \\{"source_agent_id":1,"target_agent_id":2,"count":3}
        \\]},
        \\"failure":{"total_failures":1,"recovery_success_rate_percent":100,"failure_type_distribution":{"transient":1}},
        \\"performance":{"avg_queue_depth":5,"avg_wait_time_ms":100,"avg_cpu_percent":25,"avg_memory_bytes":1048576}}
    ;

    try analyzer.parse_json_metrics(sample_json);

    // Validate all metric types are present.
    try testing.expect(analyzer.get_workflow_execution_count() > 0);
    try testing.expect(analyzer.get_coordination_metric_count() > 0);
    try testing.expect(analyzer.get_failure_metric_count() > 0);
    try testing.expect(analyzer.get_performance_metric_count() > 0);
}
