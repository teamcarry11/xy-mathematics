# Core Coordination Files

This directory contains agent-specific coordination files that provide granular insights for synchronizing cross-agent progress and collaboration.

## Purpose

Each agent maintains a dedicated coordination file (`core-coordination_{agent_name}.md`) that it can continually overwrite to communicate:
- Current work status and progress
- Integration points with other agents
- Blockers or dependencies
- Upcoming coordination needs
- Cross-agent collaboration details

## File Structure

Each agent has a dedicated file:
- `core-coordination_core.md` - Grain Core Agent
- `core-coordination_silo.md` - Grain Silo Agent
- `core-coordination_vantage.md` - Grain Vantage Agent
- `core-coordination_skate.md` - Grain Skate Agent
- `core-coordination_bubble.md` - Grain Bubble Agent
- `core-coordination_carry.md` - Grain Carry Agent
- `core-coordination_aurora.md` - Grain Aurora Agent
- `core-coordination_workspace.md` - Grain Workspace Agent
- `core-coordination_flow.md` - Grain Flow Agent
- `core-coordination_research.md` - Grain Research Agent

## Usage

**For Agents:**
- Update your coordination file as you work
- Overwrite it completely each time (no need to preserve history)
- Focus on current status, next steps, and coordination needs
- Keep it concise but informative

**For Core Agent:**
- Read all coordination files when creating coordination plans
- Use insights to identify conflicts, dependencies, and collaboration opportunities
- Reference these files in coordination plans and summaries

## Benefits

1. **Granular Insights**: More detailed status than plan/task files
2. **Real-time Updates**: Agents can update frequently without formal plan changes
3. **Cross-Agent Visibility**: All agents can see what others are working on
4. **Conflict Prevention**: Early identification of integration needs
5. **Collaboration**: Clear communication channels for agent-to-agent coordination

---

**Note**: These files are meant to be overwritten frequently. They provide a lightweight way to communicate current status without the overhead of formal plan/task updates.
