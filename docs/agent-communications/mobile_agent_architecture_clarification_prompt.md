# Grain Mobile Agent: Architecture Clarification & Grain Court Rename

**Date**: 2025-12-05-144942-pst  
**Agent**: Grain Mobile Agent (6th Agent)  
**Priority**: HIGH — Architecture clarification and rename coordination

---

## Summary

This prompt clarifies the architecture relationships between Grain Silo, Grain Court (formerly Grain Field), and Grain Database Agent, and how the Mobile Agent should interact with these components. It also includes tasks for the Grain Field → Grain Court rename.

---

## Architecture Clarification

### Your Role: Mobile App Backend

**Grain Mobile Agent** is responsible for:
- Mobile app backend API (REST endpoints)
- Authentication and user management
- Integration with Grain Core API Server
- Integration with Grain OS Authentication Service

**Key Principle**: **Decoupling** — Mobile Agent should use Grain Database Agent's REST API, not directly access Grain Silo or Grain Court.

---

## Component Relationships

### 1. Grain Silo (Skate Agent)

**Purpose**: Scalable cheap storage  
**Function**: Object storage, general-purpose database foundation  
**Location**: `src/grain_silo/`  
**Owned By**: Grain Skate Agent

**What It Is**:
- Object storage abstraction (S3-compatible)
- Database foundation layer
- Cold data storage with hot cache integration

**What It Is NOT**:
- ❌ Not a general-purpose database (that's Database Agent's job)
- ❌ Not something Mobile Agent should directly access
- ❌ Not for mobile app data storage (use Database Agent instead)

**Mobile Agent Relationship**:
- **No direct relationship** — Mobile Agent does not use Grain Silo
- Grain Silo is a low-level storage foundation
- Database Agent builds on Grain Silo for higher-level features

---

### 2. Grain Court (formerly Grain Field) (Skate Agent)

**Purpose**: Scalable fast agentic compute  
**Function**: WSE-wafer-scale SRAM spatial computing for self-hostable LLM backend  
**Location**: `src/grain_court/` (renamed from `src/grain_field/`)  
**Owned By**: Grain Skate Agent  
**Target**: Cerebras GLM4.6 API for WSE hardware

**What It Is**:
- WSE spatial computing abstraction
- LLM inference backend (self-hostable)
- Vector search and embeddings
- Hot cache for active data (SRAM)

**What It Is NOT**:
- ❌ Not a database (that's Database Agent's job)
- ❌ Not for mobile app data storage
- ❌ Not something Mobile Agent should directly access

**Mobile Agent Relationship**:
- **No direct relationship** — Mobile Agent does not use Grain Court
- Grain Court is for LLM/vector compute, not mobile backend
- If Mobile Agent needs LLM features in the future, it would use Grain Court via API, not directly

---

### 3. Grain Database Agent (7th Agent)

**Purpose**: General-purpose database  
**Function**: Hybrid database (key-value + relational + graph + full-text search)  
**Location**: `src/grain_database/`  
**Owned By**: Grain Database Agent

**What It Is**:
- General-purpose database for mobile backend
- Hybrid architecture (key-value + relational + graph + full-text search)
- REST API layer for mobile backend integration
- ACID transaction support
- Extends Grain Silo's object storage (but provides higher-level features)

**What Mobile Agent Should Do**:
- ✅ **Use Database Agent's REST API** for all data operations
- ✅ **Decoupled integration** — Mobile Agent calls Database Agent via HTTP/REST
- ✅ **No direct access** to Grain Silo or Grain Court

**Mobile Agent Relationship**:
- **Primary database integration** — Mobile Agent uses Database Agent
- **REST API communication** — All database operations go through Database Agent's REST API
- **Decoupled architecture** — Mobile Agent and Database Agent are separate services

---

## Mobile Agent Architecture

### Current Architecture (Correct)

```
┌─────────────────────────────────────┐
│  Mobile App (Android/iOS)           │
│  - Native UI (Kotlin/Swift)         │
│  - Grain Mobile Core (Zig)           │
└──────────────┬──────────────────────┘
               │ HTTP/REST API
               ▼
┌─────────────────────────────────────┐
│  Grain Mobile Agent                  │
│  - REST API endpoints                │
│  - Authentication                    │
│  - User management                   │
└──────────────┬──────────────────────┘
               │ HTTP/REST API
               ▼
┌─────────────────────────────────────┐
│  Grain Database Agent                │
│  - REST API                          │
│  - Hybrid database                   │
│  - ACID transactions                 │
└──────────────┬──────────────────────┘
               │ (uses internally)
               ▼
┌─────────────────────────────────────┐
│  Grain Silo (Skate Agent)           │
│  - Object storage foundation        │
└─────────────────────────────────────┘
```

### What Mobile Agent Should NOT Do

❌ **Do NOT directly access Grain Silo**:
- Mobile Agent should not import `grain_silo`
- Mobile Agent should not call Grain Silo functions directly
- All data operations should go through Database Agent's REST API

❌ **Do NOT directly access Grain Court**:
- Mobile Agent should not import `grain_court` (formerly `grain_field`)
- Mobile Agent should not use Grain Court for data storage
- Grain Court is for LLM/vector compute, not mobile backend

✅ **DO use Database Agent's REST API**:
- All database operations via HTTP/REST
- Decoupled architecture
- Database Agent handles all data persistence

---

## Grain Field → Grain Court Rename Tasks

### Search and Update

**Tasks**:
1. ✅ Search your codebase for "Grain Field" or `grain_field` references
2. ✅ Update any documentation that mentions Grain Field
3. ✅ Update `docs/plans/plan_mobile.md` if it references Grain Field (verify, none found in initial search)
4. ✅ Update `docs/tasks/tasks_mobile.md` if it references Grain Field
5. ✅ Update any coordination documents you've created

**Expected Results**:
- Mobile Agent likely has **minimal or no references** to Grain Field
- Mobile Agent primarily uses Database Agent, not Grain Silo or Grain Court
- If you find any references, update them to "Grain Court"

### Code Changes (if any references found)

**Module Imports** (unlikely, but check):
```zig
// If you find this (unlikely):
const grain_field = @import("grain_field");

// Update to:
const grain_court = @import("grain_court");
```

**Documentation Updates**:
- "Grain Field" → "Grain Court"
- Update any descriptions to mention Cerebras GLM4.6 API target

---

## Architecture Best Practices for Mobile Agent

### ✅ DO

1. **Use Database Agent's REST API**:
   - All data operations via HTTP/REST
   - Database Agent provides REST endpoints for mobile backend
   - Mobile Agent acts as API gateway/backend service

2. **Use Grain Core API Server**:
   - Register mobile endpoints with Grain Core API Server
   - Use Grain OS Authentication Service for JWT validation
   - Use Grain OS middleware framework

3. **Keep Decoupled**:
   - Mobile Agent and Database Agent are separate services
   - Communication via REST API only
   - No direct module dependencies on Database Agent's internal modules

### ❌ DON'T

1. **Don't directly access Grain Silo**:
   - Don't import `grain_silo` module
   - Don't call Grain Silo functions directly
   - Use Database Agent's REST API instead

2. **Don't directly access Grain Court**:
   - Don't import `grain_court` (formerly `grain_field`) module
   - Don't use Grain Court for data storage
   - Grain Court is for LLM/vector compute, not mobile backend

3. **Don't bypass Database Agent**:
   - Don't try to access database storage directly
   - Don't create direct database connections
   - Always go through Database Agent's REST API

---

## Current Mobile Agent Status

### What You've Built (Correct Architecture)

✅ **API Endpoints**:
- Handler adapters for all 10 mobile endpoints
- Integration with Grain Core API Server
- Route registration with Compositor

✅ **Authentication**:
- Integration with Grain OS Authentication Service
- JWT token validation
- Password hashing and verification

✅ **Middleware**:
- Authentication middleware using AuthService
- Request validation
- Error handling

### What You Should Continue Building

✅ **Database Integration** (via REST API):
- When Database Agent's REST API is ready, Mobile Agent will call it via HTTP
- No direct module dependencies
- Decoupled architecture

✅ **Enhanced Handlers**:
- Update handler adapters to use AuthService for token generation (login/register)
- Update handler adapters to use AuthService for password hashing (register)
- When Database Agent is ready, handlers will call Database Agent's REST API

---

## Coordination with Other Agents

### With Grain Database Agent

**Integration Point**: REST API  
**Communication**: HTTP/REST only  
**Status**: Database Agent is building REST API layer (Phase 5 complete, Phase 6 in progress)

**What Mobile Agent Provides**:
- REST API endpoints for mobile apps
- Authentication and user management
- Request/response handling

**What Database Agent Provides**:
- REST API for data operations
- Database storage and queries
- ACID transactions

**Coordination Notes**:
- Mobile Agent depends on Database Agent's REST API
- Both agents depend on Grain Core Agent's API Server (Phase 59 ✅)
- No direct module dependencies between Mobile and Database agents

### With Grain Skate Agent

**Grain Silo**: No direct relationship — Mobile Agent doesn't use Grain Silo  
**Grain Court**: No direct relationship — Mobile Agent doesn't use Grain Court  
**Coordination**: Minimal — just the rename update (if any references exist)

---

## Tasks Summary

### Immediate Tasks (Rename)

1. ✅ Search codebase for "Grain Field" or `grain_field` references
2. ✅ Update documentation if references found
3. ✅ Update plan and tasks files if references found
4. ✅ Verify no direct imports of `grain_field` or `grain_silo` modules

### Ongoing Tasks (Architecture)

1. ✅ Continue building handler adapters (using AuthService)
2. ✅ Prepare for Database Agent REST API integration (when ready)
3. ✅ Maintain decoupled architecture (REST API only, no direct module dependencies)
4. ✅ Use Grain Core API Server and Authentication Service (already integrated)

---

## Success Criteria

### For Rename
- ✅ All references to "Grain Field" updated to "Grain Court" (if any found)
- ✅ No broken imports or references
- ✅ Documentation updated

### For Architecture
- ✅ Mobile Agent uses Database Agent via REST API (when ready)
- ✅ No direct imports of `grain_silo` or `grain_court` modules
- ✅ Decoupled architecture maintained
- ✅ All tests pass

---

## Questions to Consider

1. **Do you have any references to Grain Field?**
   - Search your codebase: `grep -r "Grain Field\|grain_field" src/grain_mobile_core/`
   - Search documentation: `grep -r "Grain Field\|grain_field" docs/plans/plan_mobile.md docs/tasks/tasks_mobile.md`

2. **Are you directly importing Grain Silo or Grain Court?**
   - Check imports: `grep -r "@import.*grain_silo\|@import.*grain_field" src/grain_mobile_core/`
   - If found, remove them — use Database Agent's REST API instead

3. **Are you ready for Database Agent REST API integration?**
   - Your handler adapters are ready
   - When Database Agent's REST API is ready, you'll call it via HTTP
   - No direct module dependencies needed

---

## Next Steps

1. **Complete rename tasks** (if any references found)
2. **Verify architecture** (no direct imports of Grain Silo or Grain Court)
3. **Continue building** handler adapters with AuthService integration
4. **Prepare for Database Agent** REST API integration (when ready)

---

**Status**: Ready for implementation  
**Coordination**: Minimal — just verify no references and maintain decoupled architecture  
**Dependencies**: Database Agent REST API (when ready)

---

## Copy-Paste Message for Mobile Agent

```
continue as you best recommend, remember to follow Grain Style (~/xy-mathematics/docs/grain_style.md ) with grain_case function names and all the strict rules with all compiler warnings turned on

We are renaming Grain Field to Grain Court. Please see docs/agent-communications/mobile_agent_architecture_clarification_prompt.md for full details.

Key points for Mobile Agent:
- Mobile Agent should use Database Agent's REST API (decoupled), not directly access Grain Silo or Grain Court
- Search for "Grain Field" or "grain_field" references (likely minimal or none)
- Update documentation if any references found
- Verify no direct imports of grain_silo or grain_court modules
- Maintain decoupled architecture (REST API only)

Grain Court (formerly Grain Field) is for LLM/vector compute, not mobile backend. Mobile Agent uses Database Agent for data operations.

When you're done update the docs/plans/plan_mobile.md and docs/tasks/tasks_mobile.md keeping the general summary docs/plan.md and docs/tasks.md in thinking. let me know when you need me to check in with the other agent to prevent conflicts. also make sure all existing and new tests pass that implement their API contracts, enforcing grainwrap-100 and grain validate-70 

have a new terminal date now yyyy-mm-dd-hhmmss-pst- timestamp in your printout summary header

your agent name is: Grain Mobile Agent
```

