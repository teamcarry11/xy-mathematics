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
    try testing.expect(analyzer.failure_data_entries.items.len == 0);
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
    // Patterns only include source_agent_id, target_agent_id, count (no latency_ms).
    const json_data =
        \\{"coordination":{"total_coordinations":1,"success_rate_percent":100,"avg_coordination_latency_ms":50,"coordination_patterns":[{"source_agent_id":1,"target_agent_id":2,"count":1}]}}
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

test "analyze failure patterns" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Flow Agent's actual JSON format with mixed failure types.
    const json_data =
        \\{"failure":{"total_failures":10,"recovery_success_rate_percent":70,"failure_type_distribution":{"transient":5,"permanent":2,"timeout":2,"unknown":1}}}
    ;

    try analyzer.parse_json_metrics(json_data);

    const analysis = analyzer.analyze_failure_patterns();
    try testing.expect(analysis.total_failures == 10);
    try testing.expect(analysis.transient_failure_rate_percent == 50);
    try testing.expect(analysis.permanent_failure_rate_percent == 20);
    try testing.expect(analysis.timeout_failure_rate_percent == 20);
    try testing.expect(analysis.unknown_failure_rate_percent == 10);
}

test "get failure count by type" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"failure":{"total_failures":6,"recovery_success_rate_percent":80,"failure_type_distribution":{"transient":3,"permanent":2,"timeout":1}}}
    ;

    try analyzer.parse_json_metrics(json_data);

    const FailureType = grain_research.FailureType;
    try testing.expect(analyzer.get_failure_count_by_type(.transient) == 3);
    try testing.expect(analyzer.get_failure_count_by_type(.permanent) == 2);
    try testing.expect(analyzer.get_failure_count_by_type(.timeout) == 1);
    try testing.expect(analyzer.get_failure_count_by_type(.unknown) == 0);
}

test "get recovered and unrecovered failure counts" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"failure":{"total_failures":5,"recovery_success_rate_percent":60,"failure_type_distribution":{"transient":3,"permanent":2}}}
    ;

    try analyzer.parse_json_metrics(json_data);

    // Note: Current parser doesn't set recovered flag from JSON.
    // This test verifies the function works with existing data.
    const recovered = analyzer.get_recovered_failure_count();
    const unrecovered = analyzer.get_unrecovered_failure_count();
    const total = analyzer.get_failure_metric_count();

    try testing.expect(recovered + unrecovered == total);
}

test "analyze failure patterns with zero failures" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const analysis = analyzer.analyze_failure_patterns();
    try testing.expect(analysis.total_failures == 0);
    try testing.expect(analysis.transient_failure_rate_percent == 0);
    try testing.expect(analysis.permanent_failure_rate_percent == 0);
    try testing.expect(analysis.timeout_failure_rate_percent == 0);
    try testing.expect(analysis.unknown_failure_rate_percent == 0);
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
    // Patterns only include source_agent_id, target_agent_id, count (no latency_ms, status).
    const json_data =
        \\{"coordination":{"total_coordinations":2,"success_rate_percent":50,"avg_coordination_latency_ms":62,"coordination_patterns":[
        \\{"source_agent_id":1,"target_agent_id":2,"count":1},
        \\{"source_agent_id":2,"target_agent_id":3,"count":1}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    // Success rate comes from top-level field, not patterns.
    const success_rate = analyzer.get_coordination_success_rate_percent();
    try testing.expect(success_rate == 50);
    // Note: Parser uses avg latency from top level for all patterns.
    try testing.expect(analyzer.get_coordination_metric_count() == 2);
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

    // Flow Agent's actual JSON format (nested structure from export_all_metrics_json).
    const json_data =
        \\{"workflow":{"total_executions":1,"success_rate_percent":100,"failure_rate_percent":0,"avg_execution_time_ms":100,"executions":[{"workflow_id":1,"execution_time_ms":100,"status":0,"timestamp":1000}]},
        \\"coordination":{"total_coordinations":1,"success_rate_percent":100,"avg_coordination_latency_ms":50,"coordination_patterns":[{"source_agent_id":1,"target_agent_id":2,"count":1}]},
        \\"failure":{"total_failures":2,"recovery_success_rate_percent":80,"failure_type_distribution":{"transient":2}},
        \\"performance":{"avg_queue_depth":3,"avg_wait_time_ms":200,"avg_cpu_percent":50,"avg_memory_bytes":1048576}}
    ;

    try analyzer.parse_json_metrics(json_data);

    try testing.expect(analyzer.get_workflow_execution_count() == 1);
    try testing.expect(analyzer.get_coordination_metric_count() == 1);
    try testing.expect(analyzer.get_failure_metric_count() == 2);
    try testing.expect(analyzer.get_performance_metric_count() == 1);
}

test "parse extended failure metrics with failures array" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Flow Agent's extended JSON format with failures array.
    const json_data =
        \\{"failure":{"total_failures":2,"recovery_success_rate_percent":80,"failure_type_distribution":{"transient":2},"failures":[
        \\{"failure_id":1,"workflow_id":10,"agent_id":5,"failure_type":"transient","timestamp":1234567890,"recovery_status":"succeeded","recovery_time_ms":500,"error_message":"Network timeout after 30s","context_data":"{\"workflow_step\":3,\"retry_count\":2}"},
        \\{"failure_id":2,"workflow_id":11,"agent_id":3,"failure_type":"transient","timestamp":1234567891,"recovery_status":"not_attempted","recovery_time_ms":0,"error_message":"Connection refused","context_data":"{\"endpoint\":\"/api/v1/process\"}"}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    try testing.expect(analyzer.get_failure_metric_count() == 2);
    try testing.expect(analyzer.get_failure_data_entry_count() == 2);

    // Verify first failure entry.
    const entry1 = analyzer.failure_data_entries.items[0];
    try testing.expect(entry1.failure_id == 1);
    try testing.expect(entry1.workflow_id == 10);
    try testing.expect(entry1.agent_id == 5);
    try testing.expect(entry1.failure_type == .transient);
    try testing.expect(entry1.timestamp == 1234567890);
    try testing.expect(entry1.recovery_status == .succeeded);
    try testing.expect(entry1.recovery_time_ms == 500);
    try testing.expect(entry1.error_message_len > 0);
    try testing.expect(entry1.context_data_len > 0);

    // Verify second failure entry.
    const entry2 = analyzer.failure_data_entries.items[1];
    try testing.expect(entry2.failure_id == 2);
    try testing.expect(entry2.workflow_id == 11);
    try testing.expect(entry2.agent_id == 3);
    try testing.expect(entry2.failure_type == .transient);
    try testing.expect(entry2.recovery_status == .not_attempted);
    try testing.expect(entry2.recovery_time_ms == 0);
}

test "parse extended failure metrics with all recovery statuses" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data =
        \\{"failure":{"total_failures":5,"recovery_success_rate_percent":60,"failure_type_distribution":{"transient":5},"failures":[
        \\{"failure_id":1,"workflow_id":1,"agent_id":1,"failure_type":"transient","timestamp":1000,"recovery_status":"succeeded","recovery_time_ms":100,"error_message":"Error 1","context_data":"{}"},
        \\{"failure_id":2,"workflow_id":2,"agent_id":2,"failure_type":"transient","timestamp":2000,"recovery_status":"failed","recovery_time_ms":200,"error_message":"Error 2","context_data":"{}"},
        \\{"failure_id":3,"workflow_id":3,"agent_id":3,"failure_type":"transient","timestamp":3000,"recovery_status":"in_progress","recovery_time_ms":0,"error_message":"Error 3","context_data":"{}"},
        \\{"failure_id":4,"workflow_id":4,"agent_id":4,"failure_type":"permanent","timestamp":4000,"recovery_status":"not_applicable","recovery_time_ms":0,"error_message":"Error 4","context_data":"{}"},
        \\{"failure_id":5,"workflow_id":5,"agent_id":5,"failure_type":"transient","timestamp":5000,"recovery_status":"not_attempted","recovery_time_ms":0,"error_message":"Error 5","context_data":"{}"}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    try testing.expect(analyzer.get_failure_data_entry_count() == 5);

    const RecoveryStatus = grain_research.RecoveryStatus;
    try testing.expect(analyzer.failure_data_entries.items[0].recovery_status == .succeeded);
    try testing.expect(analyzer.failure_data_entries.items[1].recovery_status == .failed);
    try testing.expect(analyzer.failure_data_entries.items[2].recovery_status == .in_progress);
    try testing.expect(analyzer.failure_data_entries.items[3].recovery_status == .not_applicable);
    try testing.expect(analyzer.failure_data_entries.items[4].recovery_status == .not_attempted);
}

test "parse extended failure metrics with bounds checking" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Test with error_message and context_data near max length.
    // Using shorter strings to avoid JSON escaping complexity in test.
    const json_data =
        \\{"failure":{"total_failures":1,"recovery_success_rate_percent":0,"failure_type_distribution":{"transient":1},"failures":[
        \\{"failure_id":1,"workflow_id":1,"agent_id":1,"failure_type":"transient","timestamp":1000,"recovery_status":"not_attempted","recovery_time_ms":0,"error_message":"This is a test error message that is reasonably long but not at max length","context_data":"{\"test\":\"data\"}"}
        \\]}}
    ;

    try analyzer.parse_json_metrics(json_data);

    try testing.expect(analyzer.get_failure_data_entry_count() == 1);
    const entry = analyzer.failure_data_entries.items[0];
    try testing.expect(entry.error_message_len > 0);
    try testing.expect(entry.context_data_len > 0);
    try testing.expect(entry.error_message_len <= 1024);
    try testing.expect(entry.context_data_len <= 10240);
}

test "parse extended failure metrics backward compatibility" {
    const allocator = testing.allocator;
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Test backward compatibility: format without failures array.
    const json_data =
        \\{"failure":{"total_failures":2,"recovery_success_rate_percent":80,"failure_type_distribution":{"transient":2}}}
    ;

    try analyzer.parse_json_metrics(json_data);

    // Should still parse failure_type_distribution.
    try testing.expect(analyzer.get_failure_metric_count() == 2);
    // Should have no failure_data_entries (failures array not present).
    try testing.expect(analyzer.get_failure_data_entry_count() == 0);
}
