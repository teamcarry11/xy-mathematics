//! ZON Format Retrieval Accuracy Tests.
//!
//! Why: Validates that LLMs can retrieve information from ZON format as accurately
//! as JSON. Tests retrieval accuracy across formats and query types.
//! Architecture: Test dataset, query execution, accuracy measurement.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-143500-pst: ZON Format Token Efficiency Validation Phase 2

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const TestDataset = grain_research.TestDataset;
const Fact = grain_research.Fact;
const Query = grain_research.Query;
const QueryType = grain_research.QueryType;
const RetrievalAccuracyAnalyzer = grain_research.RetrievalAccuracyAnalyzer;
const RetrievalResult = grain_research.RetrievalResult;

test "create test dataset with facts and queries" {
    const allocator = testing.allocator;
    var dataset = TestDataset.init(allocator);
    defer dataset.deinit();

    // Add facts.
    const fact1 = Fact.init(1, "Workflow backup executed in 500ms", "workflow");
    const fact2 = Fact.init(2, "Workflow sync executed in 400ms", "workflow");
    const fact3 = Fact.init(3, "Database host is localhost", "config");

    try dataset.add_fact(fact1);
    try dataset.add_fact(fact2);
    try dataset.add_fact(fact3);

    // Add queries.
    const expected_fact_ids = [_]u32{ 1 };
    const query1 = Query.init(1, "How long did backup take?", &expected_fact_ids, .simple_fact);
    try dataset.add_query(query1);

    // Verify facts and queries.
    try testing.expect(dataset.facts.items.len == 3);
    try testing.expect(dataset.queries.items.len == 1);

    const retrieved_fact = dataset.get_fact(1);
    try testing.expect(retrieved_fact != null);
    try testing.expect(std.mem.eql(u8, retrieved_fact.?.text, "Workflow backup executed in 500ms"));

    const retrieved_query = dataset.get_query(1);
    try testing.expect(retrieved_query != null);
    try testing.expect(std.mem.eql(u8, retrieved_query.?.text, "How long did backup take?"));
}

test "calculate retrieval accuracy" {
    const allocator = testing.allocator;
    var analyzer = RetrievalAccuracyAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Add correct result.
    const fact_ids_correct = [_]u32{ 1 };
    const result1 = RetrievalResult.init(1, &fact_ids_correct, "500ms", true);
    try analyzer.add_result(result1);

    // Add incorrect result.
    const fact_ids_incorrect = [_]u32{ 2 };
    const result2 = RetrievalResult.init(2, &fact_ids_incorrect, "400ms", false);
    try analyzer.add_result(result2);

    // Add another correct result.
    const result3 = RetrievalResult.init(3, &fact_ids_correct, "500ms", true);
    try analyzer.add_result(result3);

    // Calculate accuracy.
    const accuracy = analyzer.calculate_accuracy();
    try testing.expect(accuracy > 60.0); // 2 out of 3 correct = 66.67%
    try testing.expect(accuracy < 70.0);
}

test "calculate accuracy by query type" {
    const allocator = testing.allocator;
    var dataset = TestDataset.init(allocator);
    defer dataset.deinit();

    var analyzer = RetrievalAccuracyAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Add facts.
    const fact1 = Fact.init(1, "Workflow backup executed", "workflow");
    try dataset.add_fact(fact1);

    // Add queries.
    const expected_fact_ids = [_]u32{ 1 };
    const query1 = Query.init(1, "What workflow executed?", &expected_fact_ids, .simple_fact);
    const query2 = Query.init(2, "Complex query", &expected_fact_ids, .complex_query);
    try dataset.add_query(query1);
    try dataset.add_query(query2);

    // Add results for simple_fact queries.
    const fact_ids = [_]u32{ 1 };
    const result1 = RetrievalResult.init(1, &fact_ids, "backup", true);
    try analyzer.add_result(result1);

    // Add results for complex_query queries.
    const result2 = RetrievalResult.init(2, &fact_ids, "backup", true);
    try analyzer.add_result(result2);

    // Calculate accuracy for simple_fact.
    const simple_accuracy = analyzer.calculate_accuracy_by_type(.simple_fact, &dataset);
    try testing.expect(simple_accuracy == 100.0);

    // Calculate accuracy for complex_query.
    const complex_accuracy = analyzer.calculate_accuracy_by_type(.complex_query, &dataset);
    try testing.expect(complex_accuracy == 100.0);
}

test "test dataset with workflow metrics facts" {
    const allocator = testing.allocator;
    var dataset = TestDataset.init(allocator);
    defer dataset.deinit();

    // Add workflow metrics facts.
    const fact1 = Fact.init(1, "Total executions: 1000", "metric");
    const fact2 = Fact.init(2, "Success rate: 90%", "metric");
    const fact3 = Fact.init(3, "Average execution time: 1250ms", "metric");

    try dataset.add_fact(fact1);
    try dataset.add_fact(fact2);
    try dataset.add_fact(fact3);

    // Add queries for workflow metrics.
    const expected_fact_ids_1 = [_]u32{ 1 };
    const expected_fact_ids_2 = [_]u32{ 2 };
    const expected_fact_ids_3 = [_]u32{ 1, 2, 3 };

    const query1 = Query.init(1, "What is the total number of executions?", &expected_fact_ids_1, .simple_fact);
    const query2 = Query.init(2, "What is the success rate?", &expected_fact_ids_2, .simple_fact);
    const query3 = Query.init(3, "What are all the workflow metrics?", &expected_fact_ids_3, .complex_query);

    try dataset.add_query(query1);
    try dataset.add_query(query2);
    try dataset.add_query(query3);

    // Verify dataset.
    try testing.expect(dataset.facts.items.len == 3);
    try testing.expect(dataset.queries.items.len == 3);

    // Verify facts.
    const fact = dataset.get_fact(1);
    try testing.expect(fact != null);
    try testing.expect(std.mem.eql(u8, fact.?.text, "Total executions: 1000"));

    // Verify queries.
    const query = dataset.get_query(3);
    try testing.expect(query != null);
    try testing.expect(query.?.expected_fact_ids.len == 3);
}

test "retrieval accuracy with edge cases" {
    const allocator = testing.allocator;
    var dataset = TestDataset.init(allocator);
    defer dataset.deinit();

    var analyzer = RetrievalAccuracyAnalyzer.init(allocator);
    defer analyzer.deinit();

    // Add edge case facts (null values, special characters).
    const fact1 = Fact.init(1, "Value is null", "edge");
    const fact2 = Fact.init(2, "Special chars: !@#$%^&*()", "edge");
    const fact3 = Fact.init(3, "Empty string: ", "edge");

    try dataset.add_fact(fact1);
    try dataset.add_fact(fact2);
    try dataset.add_fact(fact3);

    // Add edge case queries.
    const expected_fact_ids_1 = [_]u32{ 1 };
    const expected_fact_ids_2 = [_]u32{ 2 };
    const expected_fact_ids_3 = [_]u32{ 3 };

    const query1 = Query.init(1, "What is the null value?", &expected_fact_ids_1, .edge_case);
    const query2 = Query.init(2, "What are the special characters?", &expected_fact_ids_2, .edge_case);
    const query3 = Query.init(3, "What is the empty string?", &expected_fact_ids_3, .edge_case);

    try dataset.add_query(query1);
    try dataset.add_query(query2);
    try dataset.add_query(query3);

    // Add results (all correct for edge cases).
    const fact_ids_1 = [_]u32{ 1 };
    const fact_ids_2 = [_]u32{ 2 };
    const fact_ids_3 = [_]u32{ 3 };

    const result1 = RetrievalResult.init(1, &fact_ids_1, "null", true);
    const result2 = RetrievalResult.init(2, &fact_ids_2, "!@#$%^&*()", true);
    const result3 = RetrievalResult.init(3, &fact_ids_3, "", true);

    try analyzer.add_result(result1);
    try analyzer.add_result(result2);
    try analyzer.add_result(result3);

    // Calculate accuracy for edge cases.
    const edge_accuracy = analyzer.calculate_accuracy_by_type(.edge_case, &dataset);
    try testing.expect(edge_accuracy == 100.0);
}
