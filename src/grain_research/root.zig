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

// Insights generator for recommendations and reports.
// pub const insights_generator = @import("insights_generator.zig");

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
// pub const InsightsGenerator = insights_generator.InsightsGenerator;
