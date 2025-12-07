//! Grain Flow: Workflow orchestration, agent coordination, and automation flows.
//!
//! Why: Provides the orchestration layer that coordinates multiple agents using
//! Core's system services. Flow Agent integrates seamlessly with Grain Core
//! orchestration, enabling event-driven workflows and agent-to-agent coordination.
//!
//! Architecture: Flow depends on Core (API Server, WebSocket, Auth) and
//! coordinates all other agents via event bus and workflows. Flow provides:
//! - Event Bus: Centralized event routing for agent communication
//! - Agent Coordinator: Agent registry, health monitoring, RPC
//! - Workflow Engine: DAG-based workflow execution
//! - Workflow Visualizer: Visual workflow representation
//!
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-040000-pst: Initial module structure

const std = @import("std");

// Event bus for agent-to-agent communication.
pub const event_bus = @import("event_bus.zig");

// Agent coordinator for agent registry and coordination.
pub const agent_coordinator = @import("agent_coordinator.zig");

// Workflow engine for DAG-based workflow execution.
pub const workflow_engine = @import("workflow_engine.zig");

// Workflow visualizer for visual workflow representation.
// pub const workflow_visualizer = @import("workflow_visualizer.zig");

// Module exports.
pub const EventBus = event_bus.EventBus;
pub const EventType = event_bus.EventType;
pub const Event = event_bus.Event;

pub const AgentCoordinator = agent_coordinator.AgentCoordinator;
pub const Agent = agent_coordinator.Agent;
pub const AgentStatus = agent_coordinator.AgentStatus;
pub const AgentCapability = agent_coordinator.AgentCapability;
pub const RpcRequest = agent_coordinator.RpcRequest;
pub const WorkflowEngine = workflow_engine.WorkflowEngine;
pub const Workflow = workflow_engine.Workflow;
pub const WorkflowNode = workflow_engine.WorkflowNode;
pub const WorkflowEdge = workflow_engine.WorkflowEdge;
pub const WorkflowStatus = workflow_engine.WorkflowStatus;
pub const NodeStatus = workflow_engine.NodeStatus;
pub const EdgeType = workflow_engine.EdgeType;
// pub const WorkflowVisualizer = workflow_visualizer.WorkflowVisualizer;
