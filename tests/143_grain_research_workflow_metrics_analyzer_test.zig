//! Tests for Grain Research Workflow Metrics Analyzer.
//!
//! Why: Verify metrics analysis capabilities for Flow Agent Phase 3 collaboration.
//! Architecture: Comprehensive test coverage for metrics parsing and analysis.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-094200-pst: Flow Agent Phase 3 Collaboration

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const WorkflowMetricsAnalyzer = grain_research.WorkflowMetricsAnalyzer;

test "workflow metrics analyzer initialization" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    try testing.expect(analyzer.workflow_executions.items.len == 0);
    try testing.expect(analyzer.coordination_metrics.items.len == 0);
    try testing.expect(analyzer.failure_metrics.items.len == 0);
    try testing.expect(analyzer.performance_metrics.items.len == 0);
}

test "parse workflow metrics json" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Flow Agent's actual JSON format (nested structure).
    const json_data =
        \\{"workflow":{"total_executions":1,"success_rate_percent":100,"failure_rate_percent":0,"avg_execution_time_ms":100,"executions":[{"workflow_id":1,"execution_time_ms":100,"status":0,"timestamp":1000}]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    try testing.expect(analyzer.get_workflow_execution_count() == 1);
    try testing.expect(analyzer.get_average_execution_time_ms() == 100);
    try testing.expect(analyzer.get_success_rate_percent() == 100);
}

test "parse coordination metrics json" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Flow Agent's actual JSON format (nested structure).
    const json_data =
        \\{"coordination":{"total_coordinations":1,"success_rate_percent":100,"avg_coordination_latency_ms":50,"coordination_patterns":[{"source_agent_id":1,"target_agent_id":2,"coordination_latency_ms":50,"count":1}]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    try testing.expect(analyzer.get_coordination_metric_count() == 1);
    try testing.expect(analyzer.get_average_coordination_latency_ms() == 50);
}

test "parse failure metrics json" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Flow Agent's actual JSON format (nested structure).
    const json_data =
        \\{"failure":{"total_failures":7,"recovery_success_rate_percent":80,"failure_type_distribution":{"transient":5,"permanent":2}}}
    ;

    try analyzer.parse_json_metrics(json_data);

    try testing.expect(analyzer.get_failure_metric_count() == 7);
}

test "parse performance metrics json" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Flow Agent's actual JSON format (nested structure).
    const json_data =
        \\{"performance":{"avg_queue_depth":3,"avg_wait_time_ms":200,"avg_cpu_percent":50,"avg_memory_bytes":1048576}}
    ;

    try analyzer.parse_json_metrics(json_data);

    try testing.expect(analyzer.get_performance_metric_count() == 1);
}

test "calculate average execution time" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Flow Agent's actual JSON format.
    const json_data =
        \\{"workflow":{"total_executions":3,"success_rate_percent":100,"failure_rate_percent":0,"avg_execution_time_ms":200,"executions":[
        \\{"workflow_id":1,"execution_time_ms":100,"status":0,"timestamp":1000},
        \\{"workflow_id":2,"execution_time_ms":200,"status":0,"timestamp":2000},
        \\{"workflow_id":3,"execution_time_ms":300,"status":0,"timestamp":3000}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    const avg_time = analyzer.get_average_execution_time_ms();
    try testing.expect(avg_time == 200);
}

test "calculate success rate" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"workflow":{"executions":[
        \\{"workflow_id":1,"execution_time_ms":100,"status":0,"timestamp":1000},
        \\{"workflow_id":2,"execution_time_ms":200,"status":1,"timestamp":2000},
        \\{"workflow_id":3,"execution_time_ms":300,"status":0,"timestamp":3000}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    const success_rate = analyzer.get_success_rate_percent();
    try testing.expect(success_rate == 66);
}

test "calculate coordination success rate" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Flow Agent's actual JSON format.
    const json_data =
        \\{"coordination":{"total_coordinations":2,"success_rate_percent":50,"avg_coordination_latency_ms":62,"coordination_patterns":[
        \\{"source_agent_id":1,"target_agent_id":2,"coordination_latency_ms":50,"status":0,"count":1},
        \\{"source_agent_id":2,"target_agent_id":3,"coordination_latency_ms":75,"status":1,"count":1}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    const success_rate = analyzer.get_coordination_success_rate_percent();
    try testing.expect(success_rate == 50);
}

test "parse empty json" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data = "{}";

    try analyzer.parse_json_metrics(json_data);

    try testing.expect(analyzer.get_workflow_execution_count() == 0);
    try testing.expect(analyzer.get_coordination_metric_count() == 0);
}

test "parse complete metrics json" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"workflow":{"executions":[{"workflow_id":1,"execution_time_ms":100,"status":0,"timestamp":1000}]},
        \\"coordination":{"coordination_patterns":[{"source_agent_id":1,"target_agent_id":2,"coordination_latency_ms":50}]},
        \\"failure":{"failure_type_distribution":{"transient":2}},
        \\"performance":{"avg_queue_depth":3,"avg_wait_time_ms":200,"avg_cpu_percent":50}}
    ;

    try analyzer.parse_json_metrics(json_data);

    try testing.expect(analyzer.get_workflow_execution_count() == 1);
    try testing.expect(analyzer.get_coordination_metric_count() == 1);
    try testing.expect(analyzer.get_failure_metric_count() == 2);
    try testing.expect(analyzer.get_performance_metric_count() == 1);
}
