//! Grain Research: Research, analysis, and data insights for the Grain OS ecosystem.
//!
//! Why: Provides research capabilities, data analysis tools, and insights that
//! support the development and optimization of the Grain OS system and its
//! components. Research Agent is mostly independent but may integrate with
//! Core Agent for data access (HTTP Client, File System, API Server).
//!
//! Architecture: Research is mostly independent, may use Core (HTTP Client,
//! File System, API Server) for optional integration. Research provides:
//! - Research Engine: Data collection, storage, query
//! - Data Analysis: Performance, usage patterns, metrics
//! - Research Tools: Code analysis, profiling, system behavior
//! - Insights Generator: Recommendations, reports
//!
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-041522-pst: Initial module structure

const std = @import("std");

// Research engine for data collection and storage.
pub const research_engine = @import("research_engine.zig");

// Data analysis for performance and usage patterns.
// pub const data_analysis = @import("data_analysis.zig");

// Code analysis for Grain Style compliance.
pub const code_analysis = @import("code_analysis.zig");
// Codebase analyzer for analyzing entire codebase.
pub const codebase_analyzer = @import("codebase_analyzer.zig");
// Token counter for LLM provider token counting.
pub const token_counter = @import("token_counter.zig");
// Workflow metrics analyzer for Flow Agent collaboration.
pub const workflow_metrics_analyzer = @import("workflow_metrics_analyzer.zig");

// Insights generator for recommendations and reports.
pub const insights_generator = @import("insights_generator.zig");
// Retrieval accuracy analyzer for ZON format validation.
pub const retrieval_accuracy = @import("retrieval_accuracy.zig");
// Retrieval serialization for JSON and ZON formats.
pub const retrieval_serialization = @import("retrieval_serialization.zig");
// Cost savings calculator for ZON format validation.
pub const cost_savings = @import("cost_savings.zig");
// Integration test harness for multi-agent testing.
pub const integration_test_harness = @import("integration_test_harness.zig");
// Integration test scenarios for reusable test patterns.
pub const integration_test_scenarios = @import("integration_test_scenarios.zig");
// ZON format Phase 4 integration validation framework.
pub const zon_integration_validation = @import("zon_integration_validation.zig");
// ZON format Phase 4 integration validation implementation.
pub const zon_phase4_integration = @import("zon_phase4_integration.zig");
// ZON format Phase 4 validation runner.
pub const zon_phase4_validation_runner = @import("zon_phase4_validation_runner.zig");

// Module exports.
pub const ResearchEngine = research_engine.ResearchEngine;
pub const ResearchEntry = research_engine.ResearchEntry;
pub const QueryFilter = research_engine.QueryFilter;
pub const QueryResult = research_engine.QueryResult;
// pub const DataAnalysis = data_analysis.DataAnalysis;
pub const CodeAnalyzer = code_analysis.CodeAnalyzer;
pub const Violation = code_analysis.Violation;
pub const ViolationType = code_analysis.ViolationType;
pub const AnalysisResult = code_analysis.AnalysisResult;
pub const CodebaseAnalyzer = codebase_analyzer.CodebaseAnalyzer;
pub const FileAnalysisResult = codebase_analyzer.FileAnalysisResult;
pub const TokenCounter = token_counter.TokenCounter;
pub const TokenCountResult = token_counter.TokenCountResult;
pub const LLMProvider = token_counter.LLMProvider;
pub const WorkflowMetricsAnalyzer = workflow_metrics_analyzer.WorkflowMetricsAnalyzer;
pub const WorkflowExecutionMetric = workflow_metrics_analyzer.WorkflowExecutionMetric;
pub const WorkflowStatus = workflow_metrics_analyzer.WorkflowStatus;
pub const AgentCoordinationMetric = workflow_metrics_analyzer.AgentCoordinationMetric;
pub const CoordinationStatus = workflow_metrics_analyzer.CoordinationStatus;
pub const FailurePatternMetric = workflow_metrics_analyzer.FailurePatternMetric;
pub const FailureType = workflow_metrics_analyzer.FailureType;
pub const PerformanceMetric = workflow_metrics_analyzer.PerformanceMetric;
pub const InsightsGenerator = insights_generator.InsightsGenerator;
pub const Insight = insights_generator.Insight;
pub const InsightType = insights_generator.InsightType;
pub const InsightSeverity = insights_generator.InsightSeverity;
pub const Recommendation = insights_generator.Recommendation;
pub const RecommendationCategory = insights_generator.RecommendationCategory;
pub const RecommendationPriority = insights_generator.RecommendationPriority;
pub const HypothesisTestResult = insights_generator.HypothesisTestResult;
pub const RetrievalAccuracyAnalyzer = retrieval_accuracy.RetrievalAccuracyAnalyzer;
pub const TestDataset = retrieval_accuracy.TestDataset;
pub const Fact = retrieval_accuracy.Fact;
pub const Query = retrieval_accuracy.Query;
pub const QueryType = retrieval_accuracy.Query.QueryType;
pub const RetrievalResult = retrieval_accuracy.RetrievalResult;
pub const Serializer = retrieval_serialization.Serializer;
pub const SerializationResult = retrieval_serialization.SerializationResult;
pub const SerializationFormat = retrieval_serialization.SerializationResult.SerializationFormat;
pub const CostSavingsCalculator = cost_savings.CostSavingsCalculator;
pub const UseCase = cost_savings.UseCase;
pub const Pricing = cost_savings.Pricing;
pub const CostResult = cost_savings.CostResult;
pub const IntegrationTestHarness = integration_test_harness.IntegrationTestHarness;
pub const MockLLMProvider = integration_test_harness.MockLLMProvider;
pub const MockDatabase = integration_test_harness.MockDatabase;
pub const TestDataGenerator = integration_test_harness.TestDataGenerator;
pub const TestScenarioResult = integration_test_scenarios.TestScenarioResult;
pub const scenario_agent_registration = integration_test_scenarios.scenario_agent_registration;
pub const scenario_event_driven_coordination = integration_test_scenarios.scenario_event_driven_coordination;
pub const scenario_data_export_import = integration_test_scenarios.scenario_data_export_import;
pub const scenario_error_handling = integration_test_scenarios.scenario_error_handling;
pub const scenario_workflow_execution = integration_test_scenarios.scenario_workflow_execution;
pub const IntegrationValidationFramework = zon_integration_validation.IntegrationValidationFramework;
pub const IntegrationValidationResult = zon_integration_validation.IntegrationValidationResult;
pub const RoundTripResult = zon_integration_validation.RoundTripResult;
pub const PerformanceBenchmarkResult = zon_integration_validation.PerformanceBenchmarkResult;
pub const Phase4IntegrationValidator = zon_phase4_integration.Phase4IntegrationValidator;
pub const Phase4ValidationRunner = zon_phase4_validation_runner.Phase4ValidationRunner;
