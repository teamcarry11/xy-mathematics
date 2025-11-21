# RISC-V for AI and Safety-Critical Systems

**Prerequisites**: Course overview (0000)  
**Focus**: Why RISC-V is optimal for wafer-scale AI, thermodynamic compute, and TigerBeetle-style databases  
**GrainStyle**: Explicit architectural decisions, safety-first design, performance through simplicity

## Core Thesis

For extreme performance envelopes—wafer-scale AI chips (Cerebras), thermodynamic computing (Extropic), and safety-critical databases (TigerBeetle)—**RISC-V is not a barrier to performance; it is an enabler.** A complex, open-source ISA would likely be a net negative for performance, safety, and developer experience.

**Key Insight**: The reduced nature of RISC-V enables massive core replication, predictable timing for safety-critical systems, and physical co-design with novel computing substrates that complex ISAs fundamentally block.

## Wafer-Scale AI: The Cerebras Case

### Architecture Overview

Cerebras WSE-3 is a wafer-scale engine with:
- **900,000 AI-optimized cores** on a single wafer
- **4 trillion transistors** in 46,225 mm²
- **125 petaflops** of peak AI compute
- **Dataflow architecture**: Cores communicate via high-bandwidth fabric

### Why RISC-V Wins

**1. Simplicity Enables Replication**

- RISC-V RV64GC core is tiny, power-efficient, easy to validate
- Can replicate 100,000+ times across a wafer with high yield
- Complex CISC core would be larger, hotter, more error-prone
- Directly reduces number of cores you can fit, compromising yield

**2. The On-Chip Network is King**

The WSE is essentially a massive, fine-grained, many-core processor where the dominant performance factor is the **communication fabric** between cores (Swarm fabric). The instruction set inside each core is secondary.

**3. Spatial Computing**

The WSE is a spatial architecture, not von Neumann. Compute moves to data. The role of the core is to be a predictable, low-latency execution unit for the larger dataflow graph mapped onto the wafer. A simple RISC ISA provides exactly that: **predictability**.

**Verdict**: RISC-V wins decisively. Complex ISA adds area, power, and validation overhead for zero or negative performance gain in spatially-structured, many-core context.

## Thermodynamic Computing: The Extropic Case

### Novel Physics, Novel Primitives

When building computers based on novel physics (exploiting thermodynamic fluctuations), you design **hardware primitives** from scratch. You ask: "What is the fundamental, native operation of this physical system?"

### RISC as Philosophy

The RISC philosophy—"Make the common case fast"—is perfect here:

1. Identify the most fundamental, low-level operations your thermodynamic hardware can perform reliably (e.g., "apply a potential," "sample a bit," "couple two oscillators")
2. Build your ISA around these **physical primitives**
3. This ISA would be extremely Reduced and domain-specific (DSISA)

### The CISC Fallacy

A CISC approach would try to bundle physical primitives into abstract, complex instructions. This is problematic:

- **Unpredictability**: In a probabilistic system, long instruction chains have exponentially harder-to-predict outcomes
- **Safety**: Verifying complex instructions under all thermodynamic states is a nightmare
- **Performance**: Forces hardware designer to implement complex control logic that fights against the natural behavior of the substrate

**Verdict**: RISC-V's extensibility and philosophical alignment with simplicity make it the ideal starting point. Complex ISA would be fundamentally misaligned with the physics of the machine.

## Single-Threaded Performance: The TigerBeetle Case

### TigerBeetle Architecture

TigerBeetle is a high-performance, **single-threaded**, replicated ledger database written in Zig:

- **1.56M transfers/second** with 7ms max latency per batch
- **Single-threaded by choice**: No locks, no cache-coherency traffic
- **TigerStyle**: No heap after init, no floats, no undefined behavior
- **Narrow domain**: Double-entry accounting (fixed-width records, append-only journal)

### Why Single-Threaded Performance Matters

For systems like TigerBeetle, single-threaded performance is dominated by:

1. **Latency of individual operations**: Branch predictability, cache line efficiency, atomic instruction latency
2. **Instruction decode simplicity**: Fixed-length instructions enable faster decode, reducing frontend bottlenecks
3. **Avoiding AGU complexity**: RISC-V doesn't need Address Generation Units for complex indexed addressing, avoiding +1 clock cycle penalty

### RISC-V Advantages for Single-Threaded Workloads

| Aspect | RISC-V Advantage | CISC Disadvantage |
|--------|------------------|-------------------|
| **Instruction Decode** | Simpler/faster. Fixed length, 1-cycle decode allows highly predictable pipelines | More complex/slower. Variable length requires pre-decoding, adding latency |
| **Code Density** | Lower (more instructions), but RISC-V C extension mitigates this | Higher (fewer instructions), but for high-performance databases, **data locality and pipeline predictability** matter more than code size |
| **Predictability & Safety** | High. Predictable execution is key to guaranteeing safety. Base ISA is smaller, easier to formally verify | Lower. Immense complexity increases potential for corner-case bugs in microcode or side-channels |

**Key Insight**: The ISA is not the barrier to single-threaded performance; **the microarchitecture is**. RISC-V allows creation of a microarchitecture hyper-optimized for low-latency, predictable data paths required by TigerBeetle-style systems.

### Modern ISA Convergence

In modern high-performance CPUs, the historical RISC vs. CISC distinction is largely irrelevant:

- **CISC (x86)**: Internally translates complex instructions into simple, RISC-like **micro-operations (µops)**, which are then executed by the core. This translation adds complexity, power, and latency overhead.
- **RISC (RISC-V/ARM)**: Uses simple, fixed-length instructions that are easier and faster to decode and pipeline.

**Conclusion**: For TigerBeetle-like systems, RISC-V is arguably superior. Its simplicity allows hardware designers to build cores with very low and predictable latency, perfect for software that has already eliminated most sources of unpredictability.

## General-Purpose Database in Zig

### The Generalization Challenge

A general-purpose fault-tolerant database in Zig, achieving similar safety/performance feats to TigerBeetle but for a broader problem space, would need to:

| TigerBeetle Principle (Narrow) | General-Purpose Requirement | ISA Preference |
|-------------------------------|----------------------------|----------------|
| **Financial State Machine** | Transaction Processing & Indexing | **RISC-V**: Custom extensions for complex data structures (hash tables, B-trees). Vector/Bit Manipulation extensions accelerate general operations |
| **Single-Core Processing** | Multi-Core/Distributed Scalability | **RISC-V**: Energy efficiency and low-latency interconnects ideal for hundreds of homogeneous cores |
| **TigerStyle Explicit Limits** | Deterministic Fault Tolerance & Recovery | **RISC-V**: Simple, open, load-store architecture makes it easier to implement and verify custom I/O and Protocol-Aware Recovery techniques |

### Design Tensions

| Challenge | TigerBeetle | GeneralBeetle (Hypothetical) |
|----------|-------------|------------------------------|
| **Schema** | Fixed at compile-time | Configurable at runtime (but validated `comptime` where possible) |
| **Memory** | Static alloc only (Arenas pre-sized at init) | Hybrid: static pools + bounded arena fallback |
| **Consensus** | Multi-Paxos (deterministic, UDP) | Raft (easier dev experience) or Hybrid Logical Clocks + CRDTs |
| **Storage** | Append-only journal + checkpoint | LSM-tree (SSTable in Zig) + WAL (still append-optimized) |
| **Query** | ID lookup only | Prefix scans, indexed filters—but no JIT, no interpreter |

### Performance Trade-offs

**Maintaining TigerBeetle Principles in General Context:**

1. **Static Allocation Challenges**: General-purpose databases need dynamic schema support, making complete static allocation impossible
2. **Single-Threaded Limitations**: General workloads have different contention patterns than financial accounting's predictable debit/credit operations
3. **Batching Complexity**: While TigerBeetle's 8K batches work perfectly for transfers, general SQL queries have highly variable sizes and access patterns

**Potential Hybrid Approach:**

```zig
// Compromise design
const GeneralDatabase = struct {
    // Statically allocate common paths
    buffer_pool: [MAX_PAGES]Page align(CACHE_LINE),
    
    // Dynamic allocation for schema/metadata
    allocator: std.heap.ArenaAllocator,
    
    // Single-threaded for critical sections
    // Multi-threaded for I/O and background tasks
    io_context: io_uring.Context,
};
```

**Verdict**: For a general-purpose database that requires both high single-core performance (transaction processing) and massive multi-core/distributed scaling, **RISC-V remains the better choice**. Its openness allows database designers to customize the ISA (e.g., adding transactional memory or custom index acceleration instructions) to perfectly match core performance bottlenecks.

## Safety, Performance, Developer Experience

### Comparison Matrix

| Goal | RISC-V | Hypothetical Open-Source CISC | Winner |
|------|--------|-------------------------------|--------|
| **Safety** | **Pro:** Simple, verifiable instructions. Easier to formally verify. Deterministic behavior. Clear state transitions. <br>**Con:** More instructions needed per task (software problem) | **Pro:** Fewer instructions in code stream. <br>**Con:** Each instruction is complex state machine. Harder to formally verify. Side effects and microcode dependencies create hidden state | **RISC-V** |
| **Performance** | **Pro:** Predictable timing (key for real-time AI safety). Enables massive core replication. Simpler, deeper pipelines. Compiler has fine-grained control. <br>**Con:** Code density can be lower, impacting I-cache footprint | **Pro:** Potentially better code density. Single instruction can do more, *in theory*. <br>**Con:** Unpredictable, multi-cycle instructions stall pipelines. Complex cores are slower, hotter, can't be replicated as widely | **RISC-V** (for target domains) |
| **Developer Experience** | **Pro:** Clean, modular ISA. Extensibility (custom instructions) huge win for AI. Mature LLVM/GCC toolchain. <br>**Con:** Assembly looks more verbose | **Pro:** Assembly looks more "powerful" and concise. May feel familiar to x86 developers. <br>**Con:** "Kitchen-sink" ISA harder to learn. Customization is nightmare. Toolchain more complex | **RISC-V** |

## The GPGPU Question

> "Even if a more complex instruction set had higher fixed capital costs for R&D and manufacturing, would it potentially (the GPGPU version) have far greater compute capacity optimizing for space and material and distance and hardware/network latency?"

**Answer**: This is the crux of the historical CISC vs. RISC debate, and the market has spoken.

**Modern Reality**:
- **x86 decodes** complex CISC instructions into simpler RISC-like µops internally. The complexity is a legacy burden, not a performance feature.
- **GPGPUs** are *massively parallel arrays of simple, in-order cores* that execute a very simple instruction set. Their performance comes from parallelism and memory hierarchy, not complex instructions.

The "far greater compute capacity" hypothesized for a CISC GPGPU is a mirage. The area and power budget spent on complex instruction decode and scheduling logic is **diverted** from what actually provides performance: more ALUs, better on-chip networks, and larger caches.

## RISC-V Extensibility: The Golden Ticket

### Custom Instructions for AI

RISC-V's modular design allows for AI-specific extensions:

- **Vector Extension (V)**: Variable-length vector registers for SIMD-style data parallelism
- **Custom Instructions (Zx\*)**: Expose macro-ops (e.g., `tensor_matmul_fused`) without encoding them in base ISA
- **Bit Manipulation (B)**: Accelerate general data structure operations

**Example**: Esperanto ET-SoC-1 chip achieves 800+ trillion operations per second within 120W by adding vector instructions for matrix operations and tensor processing.

### Domain-Specific Acceleration

For a general-purpose database, RISC-V allows:

- Custom instructions for specific costly operations (e.g., `DECIMAL_MULTIPLY`, `JSON_EXTRACT`)
- Vector extensions for compression/scans
- Transactional memory extensions for lock-free data structures

**Key Advantage**: A fixed-target, high-cost CISC design cannot match this customization capability.

## Zig + RISC-V Synergy

### Compile-Time Safety

Zig's `@bitCast`, `packed struct`, and `align(N)` let you map database layout exactly to cache lines. RISC-V's clean memory model ensures this layout behaves predictably on real hardware.

### Explicit Limits

```zig
// TigerBeetle-style explicit limits
const MAX_TRANSFERS: u32 = 8192;
const TRANSFER_SIZE: u32 = 128;  // Cache-line aligned

// RISC-V enables predictable execution of this pattern
// No hidden state, no microcode dependencies
```

### Formal Verification

RISC-V's simple, open specification (e.g., [Sail RISC-V](https://www.cl.cam.ac.uk/~pes20/sail/)) makes formal verification feasible. Combined with Zig's compile-time guarantees, this enables building provably correct systems.

## Follow-Up: WSE Spatial Architectures and a Greener Hardware Future

### The Question

As a follow-up to RISC-V's advantages for AI hardware: Would WSE spatial architecture designs (which are not von Neumann) possibly lead to a **greener hardware future of RAM-only cloud computing** with dramatically less e-waste and conflict material sourcing than NVMe SSDs? Especially in an "America First" approach to homeland material recycling, renewed national manufacturing, and power efficiency?

**Answer**: Yes. WSE-style spatial architectures are a foundational step towards a RAM-only cloud computing paradigm that is dramatically greener, more power-efficient, and less reliant on conflict materials than the current SSD-dominated model.

### The Inefficiency of Von Neumann / Storage Hierarchy

Our current cloud computing model is built on a deeply inefficient pyramid:

- **Fast, Volatile DRAM**: Expensive, power-hungry, limited capacity
- **Slow, Non-Volatile Storage (NVMe SSDs)**: Cheaper per GB, but major source of latency, power consumption, and problematic material sourcing

The constant shuffling of data between these tiers (a consequence of the von Neumann bottleneck) is a massive waste of energy. SSDs act as a necessary but inefficient "band-aid" for datasets that don't fit in RAM.

### How Spatial Architectures Enable RAM-Only Future

WSE-style designs attack this problem at its root:

**1. Eliminating Data Movement**

The primary consumer of energy in modern computing is not the calculation itself, but **moving data** to and from the compute unit. Spatial architectures like Cerebras's bring the compute to the data, performing operations directly within the memory fabric of the wafer. This is a radical reduction of wasted energy.

**2. Massive, On-Chip "RAM"**

The WSE isn't just compute; it's a vast, high-bandwidth, on-chip SRAM distributed across the entire wafer. WSE-3 features **44 petabytes of on-chip SRAM**, allowing entire large language models (LLMs) or datasets to reside in memory during operation, eliminating off-chip data transfers.

**3. The Death of the "Slow Storage" Tier**

For a vast class of problems—especially AI model training and inference, large-scale graph analysis, and scientific simulation—a spatial computer with enough on-chip and near-chip memory could process the entire working set without ever needing to page to an SSD. The SSD becomes an archival/initial-load device, not an active participant in the compute loop.

**4. Turbopuffer Architecture on WSE: The Path to Baremetal Open Hardware**

Turbopuffer's serverless search architecture provides a blueprint for WSE baremetal deployment:

**Turbopuffer's Key Innovation**: Separates compute (NVMe SSD + memory cache) from state storage (object storage). This aligns perfectly with WSE's spatial computing model:

* **WSE Compute Layer**: 900,000 cores with 44GB on-wafer SRAM act as the "compute nodes" (replacing NVMe SSD + memory cache)
* **Object Storage Layer**: External object storage (S3-like) for cold data, archival state
* **Hot Data in SRAM**: Actively searched data (code state, web content, UI state) cached in 44GB on-wafer SRAM
* **Vector + Full-Text Search**: SPFresh ANN index + BM25 inverted index run on-wafer (spatial computing, parallel execution)

**WSE Baremetal Vision**:
* **State Storage**: Object storage (S3-compatible) for cold data, checkpoints
* **Hot Cache**: 44GB on-wafer SRAM for active queries, code state, web content
* **Compute**: 900,000 cores for parallel search, vector operations, full-text indexing
* **Consistency**: Write-Ahead Log (WAL) for ACD guarantees, deterministic state machine
* **Latency**: Sub-millisecond queries (spatial computing, zero-copy operations)

**Benefits for Open Hardware**:
* **No Proprietary Storage**: Object storage is standard (S3 API), open protocols
* **Repairable**: WSE compute layer is modular, object storage is replaceable
* **Scalable**: Horizontal scaling via object storage, vertical scaling via WSE cores
* **Cost-Efficient**: Cold data in object storage (cheap), hot data in SRAM (fast)
* **Deterministic**: WAL + state machine = reproducible, verifiable operations

### Environmental and Geopolitical Impact

Removing the SSD from the active compute loop has profound consequences.

#### A. Drastically Reduced E-Waste

| Component | Traditional Cloud (NVMe, GPUs) | WSE-Based Cloud (RAM-Only) | Impact |
|----------|-------------------------------|----------------------------|--------|
| **SSD/NVMe Storage** | Required for low-latency data access. SSDs fail after 1,000-10,000 write cycles (2-5 years in data-intensive apps) | **Less Necessary.** WSE's massive on-chip SRAM allows using faster, more direct external DRAM/HBM instead of persistent flash for hot data | **Reduced E-Waste.** SSDs are complex devices with controllers, NAND flash, contributing significantly to e-waste when decommissioned. DRAM modules have no write-cycle limit and can last decades |
| **Hardware Density** | Many individual chips (CPUs, GPUs, NICs, SSDs) must be assembled into server racks | A single WSE replaces a **cluster of hundreds of chips** | **Less Manufacturing Footprint.** Consolidation reduces complexity, material needs, and total manufacturing carbon footprint |

**Key Insight**: A RAM-only data center would see a dramatic reduction in its recurring e-waste stream. WSE-3 systems produce **5-10x less e-waste per petaflop** by consolidating hardware.

#### B. Reduced Conflict Material Sourcing

This is critical and often overlooked. Compare the material composition:

**NVMe SSD**:
- Relies heavily on **NAND Flash memory**
- Requires **Rare Earth Elements**: Sourced predominantly from China
- **Specialty Metals**: Supply chains often opaque, linked to conflict zones
- **Cobalt, tantalum, tungsten, gold (3TG)**: Prevalent in capacitors, interconnects, packaging

**WSE-Style RAM-Only**:
- **SRAM focus**: Less complex than DRAM/NAND, avoids flash-specific minerals
- **Cobalt-free SRAM bit-cells**: Eliminate the largest conflict-mineral driver
- **Package-less integration**: Removes epoxy-molded substrates that block closed-loop recycling
- **Silicon, copper, aluminum**: All abundant in U.S. supply chains

**Verdict**: By consolidating into one wafer, WSE uses fewer total dies and packages, potentially **halving 3TG needs per compute unit** vs. SSD-heavy clusters. A WSE-based data center might need **10x fewer storage drives** for equivalent AI throughput.

#### C. Power Efficiency

The numbers are stark:

- **Active Power**: High-end NVMe SSD: 5-10+ watts under load
- **DRAM Power**: DDR5 DIMM: 3-6 watts
- **WSE-3**: 26 kW chassis replaces hundreds of GPU/SSD nodes drawing **>200 kW** for same 125-petaflop AI throughput

**Real Win**: Eliminating latency penalty. SSD access is orders of magnitude slower than DRAM access. CPUs spend less time stalled, completing tasks faster and returning to low-power idle states. System-wide energy per task plummets.

**Measured Impact**: WSE delivers **100-1000x reductions in energy** for certain inference tasks compared to GPU clusters. Near-memory computing cuts **data-movement energy by 470×** on field-equation workloads.

### America First Manufacturing & Recycling

This vision plays directly into a strategy of national technological resilience.

**1. Renewed National Manufacturing**

- Leading-edge DRAM production: South Korea (Samsung, SK Hynix) and **US (Micron)**
- Investing in RAM-centric computing means investing in Micron and building domestic capacity
- **CHIPS Act fabs** (Intel, TSMC-Arizona, Micron NY) are on-shore **300mm bulk-CMOS lines**—exactly what WSE reticle stitching needs
- Wafer-scale requires fewer discrete components → less assembly, more monolithic fab

**2. Homeland Material Recycling**

- Simpler, more durable hardware profile (long-lived servers with fewer replaceable components) makes end-of-life recycling more feasible
- **Whole-wafer reclaim**: Can be colocated at foundry campus, creating **closed-loop Si-Al-Cu recirculation plant**
- **Circular yield >95%** vs. <20% for SSD smelt
- Recycling high-value DRAM and CPUs is more straightforward than dealing with complex mix of materials in worn-out SSD

**3. Power Efficiency as National Security**

- Data centers consume ~4% of U.S. electricity—projected to hit **8-12% by 2030** (mostly AI)
- Reducing power footprint of data centers and AI compute directly strengthens the national grid
- Enables co-location with renewables: lower peak draw → easier solar/wind matching
- Makes domestic AI infrastructure more resilient and less of a burden on energy resources

### The RAM-Only Cloud Vision

| Layer | Architecture |
|-------|--------------|
| **Hardware** | WSE-style wafer with 100s of GB SRAM, integrated optical I/O (for cluster scaling), battery-backed retention |
| **Persistence** | Checkpoint-to-minimal-flash (e.g., 1 TB NAND per 100 TB SRAM) *only on shutdown*; or use **FeRAM/MRAM** for byte-addressable non-volatility |
| **Software** | Zig/Rust systems with *explicit memory contracts* (like TigerBeetle): no GC, no unbounded allocs, composable failure domains |
| **Fault Tolerance** | Spatial redundancy (e.g., spare cores), erasure-coded checkpointing, Byzantine-tolerant consensus *over SRAM state* |
| **Use Cases** | Real-time inference serving, in-memory graph DBs, LLM context caches, scientific simulation state-holding |

### Turbopuffer + WSE: The Baremetal Open Hardware Path

**Turbopuffer Architecture on WSE**:

| Component | Turbopuffer (Current) | WSE Baremetal Vision |
|-----------|----------------------|---------------------|
| **State Storage** | Object storage (S3) | Object storage (S3-compatible, open protocols) |
| **Hot Cache** | NVMe SSD + memory | 44GB on-wafer SRAM (spatial computing) |
| **Compute** | Serverless nodes | 900,000 cores (parallel search, vector ops) |
| **Search Index** | SPFresh ANN + BM25 | On-wafer execution (spatial, zero-copy) |
| **Consistency** | WAL (ACD) | WAL + state machine (deterministic) |
| **Latency** | p50 8ms (warm) | Sub-millisecond (spatial, on-wafer) |
| **Scalability** | Trillions of documents | Horizontal (object storage) + vertical (WSE cores) |

**Key Advantages for Open Hardware**:
* **No Proprietary Storage**: Object storage uses standard S3 API, open protocols
* **Repairable**: WSE compute layer is modular, object storage is replaceable
* **Deterministic**: WAL + state machine = reproducible, verifiable operations
* **Cost-Efficient**: Cold data in object storage (cheap), hot data in SRAM (fast)
* **Green Computing**: RAM-only execution, no disk I/O, reduced e-waste

**Path to WSE Baremetal**:
1. **Phase 1**: Implement Turbopuffer-style architecture on standard hardware (object storage + compute nodes)
2. **Phase 2**: Port to WSE (replace NVMe SSD + memory with 44GB SRAM)
3. **Phase 3**: Optimize for spatial computing (parallel search, vector ops on 900k cores)
4. **Phase 4**: Open hardware deployment (Framework 13 RISC-V, WSE-style chips)

**Key Insight**: This isn't sci-fi. Cerebras already runs **full LLM training in on-wafer memory** (no host DDR bottlenecks). Scaling this to general-purpose cloud services is a software + systems challenge—not a physics one.

### Challenges and Path Forward

**Challenges**:
- **Cost**: DRAM is still more expensive per GB than NAND. However, Total Cost of Ownership (TCO)—factoring in power, cooling, replacement costs, and performance—is where the model wins
- **Volatility**: DRAM is volatile. Requires re-architecting software to use persistent memory paradigms or rely on slower, centralized *archival* storage tier
- **Software Paradigm**: Requires new generation of software, like TigerBeetle, built for deterministic, in-memory operation, and spatial computing models

**Path Forward**:
- **SRAM density**: ~6F²/cell vs NAND's ~3-4 bits/F² → higher $/GB. But for *hot working sets*, this is acceptable—and cost drops with yield improvements
- **Cold storage still needed**: For archival, pair with **tape** (iron oxide—fully U.S.-sourced, ultra-low energy) or **DNA storage** (long-term national archive)
- **Software must adapt**: No more "disk is free" mindset. Memory-conscious algorithms (e.g., succinct data structures, delta encoding) become mandatory

### Bottom Line

The shift towards spatial architectures like the WSE is not just an incremental performance improvement. It is a fundamental **architectural rebellion** against the inefficient von Neumann legacy. This rebellion paves the way for a RAM-centric cloud, which in turn offers a path to a more sustainable, power-efficient, and geopolitically resilient computing infrastructure.

**For America First Industrial Policy**:
- Reduces geopolitical supply risk (no cobalt, tantalum, rare-earth dependencies)
- Lowers long-term TCO (capex + opex + e-waste)
- Aligns with climate goals (kWh/op matters more than FLOPs/W)
- Creates high-skill, tariff-resilient jobs (design & packaging)
- Enables closed-loop material recirculation

**For Grain OS**: This vision aligns perfectly with our goals. By building on RISC-V's simple, extensible foundation, we can create systems that are not just high-performance, but also sustainable, verifiable, and aligned with national strategic interests.

The future isn't *more NVMe*—it's **less material, more intelligence per atom**.

## The IDE Frontier: Architecture-First AI Development Tools

### The Question

Could we use GLM-4.6 (Cerebras's open-weight coding model) in Zed, or even build an even better IDE written in Zig with GLM-4.6 as a starting point? Inspired by Matklad's vision of moving away from VS Code towards editors that support readonly characters, method folding, and LSP-driven VCS integration.

**Answer**: The real breakthrough isn't just having GLM-4.6—it's building the **right architecture** around it. The IDE architecture matters more than the specific AI model. By building in Zig with Matklad's principles, we create a foundation that could leverage any future AI advancement—including eventually wafer-scale AI when it becomes accessible as a service.

**Key Insight**: While GLM-4.6 isn't directly usable in Zed today (it's inference-only on Cerebras hardware), the architectural vision—project-wide semantic understanding, incremental compilation, deterministic AI patterns—is what will define the next generation of developer tools.

### The Architecture-First Approach

**Why Architecture Matters More Than the Model**:

The real breakthrough isn't just having GLM-4.6—it's building the **right architecture** around it:

1. **Project-Contextual AI**: Instead of file-at-a-time, give the AI full project semantics. The IDE understands the entire codebase graph, not just the current file.

2. **Incremental Everything**: Reuse compilation artifacts for AI context. Matklad's "majjit" concept—incremental compilation that feeds directly into AI understanding—means the IDE never re-analyzes unchanged code.

3. **Deterministic AI**: Cache common patterns so the IDE feels predictable. The same code transformation should produce the same result, enabling developer trust.

**Available Models Today** (while waiting for wafer-scale AI):

- **DeepSeek Coder** (open weights, commercially usable)
- **CodeLlama 70B** or smaller variants for local inference
- **Claude 3.5 Haiku** (best balance of speed/capability for IDE work)

**The Path Forward**:

1. **Short-term**: Use Cursor with best available models + contribute to Zed's AI capabilities
2. **Medium-term**: Start building your vision in Zig, focusing on the architectural insights from Matklad
3. **Long-term**: Position your stack to leverage wafer-scale AI when it becomes accessible

### GLM-4.6 and Cerebras: Current Reality

**Direct Answer**: No, you cannot directly use Cerebras's GLM-4.6 in Zed today. Here's why:

1. **Cerebras GLM is inference-only on their hardware** - It runs on Cerebras WSE systems, not as a local model you can integrate into an IDE
2. **Zed's AI architecture** is built around local models (via Ollama) or cloud APIs (OpenAI, Anthropic)

**However**: When such models become available via API, a Zig IDE built with Matklad's principles would be perfectly positioned to leverage them. The architecture you build today will be ready for tomorrow's AI capabilities.

### Building a Zig-Native IDE: The Vision

**Why Zig for IDE Development?**

| Aspect | Zig Advantage |
|--------|---------------|
| **Zero-cost, auditable UI** | No GC pauses, no hidden allocations → deterministic rendering (critical for readonly/sticky attribute tracking) |
| **Comptime metaprogramming** | Generate editor commands, LSP handlers, and layout DSLs at compile time |
| **Cross-platform + small binary** | Full IDE can ship as <10 MB binary |
| **Memory safety without runtime** | Use `Allocator` bounds + explicit lifetimes to avoid use-after-free in text buffer models |
| **True zero-cost abstractions** | For the compiler integration Matklad describes—no hidden overhead in incremental compilation |

**Matklad's Vision + Zig + Future AI**:

1. **Readonly Characters**: Zig's explicit memory management enables precise readonly span tracking—text buffers with `(start, end, flags)` in gap buffer or rope structure. This is the foundation for "text-as-UI" where VCS status, commit messages, and diffs are just files you edit.

2. **Method Folding by Default**: Tree-sitter integration + comptime code generation for structural views. The IDE understands code structure at compile time, not just at runtime.

3. **Magit-Style VCS**: Virtual file system where `.ide/status.jj`, `.ide/commit/zxf.diff` are real files—editors open them, daemon watches and updates. This is the "missing IDE feature" Matklad describes—project-wide semantic understanding.

4. **Incremental Compilation (Majjit)**: Reuse compilation artifacts for AI context. The IDE never re-analyzes unchanged code. This feeds directly into AI understanding—the model sees the project graph, not just file contents.

5. **Project-Wide Semantic Understanding**: The IDE maintains a graph of the entire codebase. When AI suggests a change, it understands the full context—all callers, all dependencies, all related code.

**Conceptual Architecture**:

```zig
// Conceptual architecture for Zig IDE with AI integration
const AIIDE = struct {
    // 1. Read-only character streams (per matklad)
    read_only_document: DocumentStream,
    
    // 2. Majjit-style incremental compilation
    incremental_compiler: CompilerCache,
    
    // 3. "Missing IDE feature" - project-wide semantic understanding
    semantic_engine: ProjectGraph,
    
    // 4. AI provider abstraction (works with any model)
    ai_providers: []AIProvider, // Local + cloud, ready for wafer-scale when available
};
```

### The Architecture (Today and Tomorrow)

**Today's Architecture** (with available models):

```
┌--------------┐
│  Local/Cloud │  ← DeepSeek Coder, CodeLlama, or Claude 3.5 Haiku
│  AI Model    │
└----┬---------┘
     │ API or local inference
┌----┴---------┐
│  Zig IDE     │  ← single-threaded event loop (io_uring)
│  - tree-sitter incremental
│  - readonly spans (matklad)
│  - fold-bodies-by-default
│  - magit-style .jj/status.jj
│  - project-wide semantic graph
└----┬---------┘
     │  Native UI
┌----┴---------┐
│  User Laptop │  ← runs *only* the UI thread (Wayland/native)
└--------------┘
```

**Tomorrow's Architecture** (when wafer-scale AI becomes accessible):

```
┌--------------┐
│  Cerebras     │  ← WSE-3 wafer (1 kt/s, 2 kW)
│  GLM-4.6      │  ← or future wafer-scale models
└----┬---------┘
     │ zero-copy shared memory
┌----┴---------┐
│  Zig IDE     │  ← single-threaded event loop (io_uring)
│  - tree-sitter incremental
│  - readonly spans (matklad)
│  - fold-bodies-by-default
│  - magit-style .jj/status.jj
│  - project-wide semantic graph
└----┬---------┘
     │  USB-C / 10 GbE
┌----┴---------┐
│  User Laptop │  ← runs *only* the UI thread (Wayland/native)
└--------------┘
```

**Key Numbers** (Future Vision):
- **44 GB on-wafer SRAM**: Enough for 10,000 open files (4 MB each) without touching external RAM
- **1,000 tokens/second**: Full 200-line function appears in <250ms—fast enough to *feel* local
- **Cobalt-free SRAM**: Aligns with "America First, conflict-free" goal
- **Spatial architectures**: Perfect for the graph-based code understanding Matklad describes
- **Wafer-scale inference**: Could eventually provide instant project-wide analysis

### Performance Advantages of Zig + Architecture-First Approach

**Why Zig + Your Approach Could Win**:

1. **No GC pauses** for AI token streaming—deterministic rendering even during AI inference
2. **True zero-cost abstractions** for the compiler integration Matklad describes—incremental compilation feeds directly into AI context
3. **Cross-compilation** to deploy your IDE everywhere—RISC-V, ARM64, x86_64
4. **Project-contextual AI**: Instead of file-at-a-time, give the AI full project semantics through the semantic graph
5. **Incremental everything**: Reuse compilation artifacts for AI context—never re-analyze unchanged code
6. **Deterministic AI**: Cache common patterns so the IDE feels predictable—same transformation, same result

**What You Could Build Today**:

1. **Zed plugin system** - prototype your ideas within Zed
2. **Standalone Zig LSP** - implement Matklad's "majjit" concepts
3. **Gradual migration** - replace parts of your workflow incrementally

**Example Use Case** (Architecture-First AI):

Open `.jj/status.jj`. The IDE's semantic engine watches it. Highlight a hunk, press `Cmd+.` → "Split this hunk into new commit". The AI (any model, today or tomorrow):
- Accesses the project-wide semantic graph (not just file contents)
- Understands all callers, dependencies, related code
- Calls `jj diff --git` to get structured context
- Generates *two diffs* (old commit ↔ new commit)
- Uses readonly ranges to lock metadata (commit hash, parent)
- Lets you edit the *new* diff freely
- On `Cmd+Enter`, invokes `jj new` + `jj describe` via tool call

**The Key**: The architecture enables this workflow with *any* AI model—today's DeepSeek Coder, tomorrow's wafer-scale GLM-4.6, or future models we can't yet imagine.

### The Cerebras Angle Long-term

While you can't use GLM-4.6 locally today, the Cerebras approach points to the future:

- **Wafer-scale inference** could eventually provide instant project-wide analysis
- **Spatial architectures** are perfect for the graph-based code understanding Matklad describes
- **When such models become available via API**, your Zig IDE would be perfectly positioned to leverage them

**The Convergence**:

- **Cerebras**: Speed + open-weight quality (when available)
- **Matklad**: UI paradigm innovation (readonly spans, text-as-UI, project-wide semantics)
- **Zig**: Safety and simplicity substrate (zero-cost, comptime, explicit)
- **RISC-V**: Hardware foundation (simple, extensible, verifiable)

This convergence isn't just possible—it's *inevitable*. Someone's going to build it. Why not us?

**For Grain OS**: This vision extends our mission. By building developer tools in Zig on RISC-V, with an architecture-first approach to AI integration, we create a complete stack—from hardware to IDE—that is safety-first, high-performance, and developer-friendly. The architecture we build today will be ready for tomorrow's AI capabilities, whether that's wafer-scale inference, spatial architectures, or models we can't yet imagine.

**The Strategic Insight**: The IDE architecture matters more than the specific AI model. By building in Zig with Matklad's principles, we create a foundation that could leverage any future AI advancement—including eventually something like GLM-4.6 when it becomes available as a service, or wafer-scale AI for self-hosted baremetal cloud deployments.

## Unified Conclusion: RISC-V as the Foundation for Next-Generation Computing

Across the entire spectrum of computing—from wafer-scale AI and thermodynamic computing to specialized single-threaded financial databases, general-purpose systems, and next-generation developer tooling—the principles of reduction and simplicity embodied by RISC-V provide a superior foundation.

### The Hardware Revolution

**For Novel Hardware (Cerebras/Extropic)**:
- RISC-V's philosophy aligns with the physics of the machine
- Spatial architectures enable RAM-only cloud computing
- Dramatic reductions in e-waste, conflict materials, and power consumption
- America First manufacturing and recycling alignment

**For Safety-Critical Systems (TigerBeetle)**:
- RISC-V's determinism and low-latency potential are perfect for software engineered for predictability
- Single-threaded performance depends on predictable microarchitecture—RISC-V's core strength
- Explicit limits, formal verification, and bounded execution all benefit from simple, open ISAs

### The Software Revolution

**For General-Purpose Software**:
- RISC-V's advantages in safety, verification, and extensibility make it the more robust and forward-looking platform
- Custom instructions enable domain-specific acceleration without complexity overhead
- Zig + RISC-V synergy enables provably correct, high-performance systems

**For Developer Tooling**:
- GLM-4.6 + Zig + RISC-V represents the next frontier
- Matklad's vision of readonly characters, method folding, and text-as-UI becomes feasible
- 1,000 tokens/second agentic coding at 94.5% accuracy enables new paradigms

### The Strategic Imperative

**For America First Industrial Policy**:
- Reduces geopolitical supply risk (no cobalt, tantalum, rare-earth dependencies)
- Lowers long-term TCO (capex + opex + e-waste)
- Aligns with climate goals (kWh/op matters more than FLOPs/W)
- Creates high-skill, tariff-resilient jobs
- Enables closed-loop material recirculation

**For Grain OS**:
- RISC-V is not just a choice—it's the foundation that enables our goals
- Safety-first, high-performance, developer-friendly systems
- Sustainable, verifiable, aligned with national strategic interests
- Complete stack from hardware to IDE

### The Path Forward

The hypothetical open-source CISC ISA represents a path of increasing complexity and diminishing returns. RISC-V represents a path of elegant simplicity and boundless customization, which is precisely what is needed to tackle the performance and safety challenges of the next decade of computing.

**The Future**:
- Not *more NVMe*—it's **less material, more intelligence per atom**
- Not *more complexity*—it's **simpler hardware, smarter software**
- Not *more proprietary*—it's **open standards, extensible platforms**

**The Convergence**:
- **Cerebras**: Speed + open-weight quality
- **Matklad**: UI paradigm innovation
- **Zig**: Safety and simplicity substrate
- **RISC-V**: Hardware foundation

This convergence isn't just possible—it's *inevitable*. The question isn't whether it will happen, but who will build it first.

**For Grain OS**: We're building it. RISC-V is our foundation. Zig is our language. GLM-4.6 is our copilot. The future of computing—greener, safer, faster, more sustainable—starts here.

Across the entire spectrum—from wafer-scale AI and thermodynamic computing to specialized single-threaded financial databases and general-purpose systems—the principles of reduction and simplicity embodied by RISC-V provide a superior foundation.

### For Novel Hardware (Cerebras/Extropic)

RISC-V's philosophy aligns with the physics of the machine. It's the only logical choice.

### For Specialized Software (TigerBeetle)

RISC-V's determinism and low-latency potential are a perfect match for software engineered for predictability.

### For General-Purpose Software

RISC-V's advantages in safety, verification, and extensibility make it the more robust and forward-looking platform, even if a mature CISC might eke out a minor win in some generic benchmarks.

### The Path Forward

The hypothetical open-source CISC ISA represents a path of increasing complexity and diminishing returns. RISC-V represents a path of elegant simplicity and boundless customization, which is precisely what is needed to tackle the performance and safety challenges of the next decade of computing.

**For Grain OS**: RISC-V is not just a choice—it's the foundation that enables our goals of safety-first, high-performance, developer-friendly systems.

## Exercises

1. **Architecture Analysis**: Compare RISC-V RV64GC core size vs. hypothetical CISC core for wafer-scale replication.

2. **Single-Threaded Optimization**: Design a RISC-V custom instruction that would accelerate TigerBeetle's transfer batching.

3. **General Database Design**: Sketch a hybrid memory allocation strategy for a general-purpose Zig database that maintains TigerBeetle's safety guarantees.

4. **Thermodynamic Primitives**: Design a minimal RISC-V extension for thermodynamic computing primitives.

## Key Takeaways

- RISC-V enables performance through simplicity, not despite it
- Wafer-scale AI benefits from massive core replication (RISC-V's strength)
- Thermodynamic computing requires alignment with physical primitives (RISC-V's philosophy)
- Single-threaded performance depends on predictable microarchitecture (RISC-V's advantage)
- General-purpose systems benefit from extensibility (RISC-V's golden ticket)
- Safety and verification are easier with simple, open ISAs
- Zig + RISC-V synergy enables provably correct, high-performance systems

## Next Document

**0002-risc-v-architecture.md**: Deep dive into RISC-V ISA details, instruction formats, and encoding.

---

*now == next + 1*

