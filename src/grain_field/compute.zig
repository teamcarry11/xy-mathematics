const std = @import("std");

/// Grain Field: WSE RAM-only spatial computing abstraction.
/// ~<~ Glow Airbend: explicit compute state, bounded core management.
/// ~~~~ Glow Waterbend: deterministic spatial computing, iterative algorithms.
///
/// Represents the WSE compute layer: 44GB+ on-wafer SRAM, 900k cores,
/// field topology (2D grid with wrap-around) for parallel execution.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
///
/// 2025-11-23-114146-pst: Active implementation
pub const Compute = struct {
    // Bounded: Max cores per field (explicit limit)
    // 2025-11-23-114146-pst: Active constant
    pub const MAX_CORES: u32 = 1_000_000; // 900k cores + headroom

    // Bounded: Max SRAM capacity (explicit limit, in bytes)
    // 2025-11-23-114146-pst: Active constant
    pub const MAX_SRAM_CAPACITY: u64 = 47_185_920_000; // 44GB + headroom (44 * 1024^3)

    // Bounded: Max parallel operations (explicit limit)
    // 2025-11-23-114146-pst: Active constant
    pub const MAX_PARALLEL_OPS: u32 = 10_000;

    /// Core state enumeration.
    // 2025-11-23-114146-pst: Active enum
    pub const CoreState = enum(u8) {
        idle, // Core is idle
        active, // Core is executing
        waiting, // Core is waiting for data
        error_state, // Core is in error state
    };

    /// Field core structure.
    // 2025-11-23-114146-pst: Active struct
    pub const Core = struct {
        id: u32, // Core ID (unique identifier)
        state: CoreState, // Core state
        sram_offset: u64, // SRAM offset for this core's data
        sram_size: u64, // SRAM size allocated to this core
        neighbors: []u32, // Neighboring core IDs (field topology)
        neighbors_len: u32,
    };

    /// Field compute structure.
    pub const FieldCompute = struct {
        cores: []Core, // Cores buffer (bounded)
        cores_len: u32, // Number of cores
        sram_capacity: u64, // Total SRAM capacity (bytes)
        sram_used: u64, // SRAM used (bytes)
        sram_data: []u8, // SRAM data buffer (bounded)
        parallel_ops: []ParallelOp, // Parallel operations queue (bounded)
        parallel_ops_len: u32, // Number of parallel operations
        allocator: std.mem.Allocator,

        /// Parallel operation structure.
        pub const ParallelOp = struct {
            op_id: u32, // Operation ID
            op_type: OpType, // Operation type
            core_ids: []u32, // Core IDs involved in operation
            core_ids_len: u32,
            data_offset: u64, // Data offset in SRAM
            data_size: u64, // Data size
            status: OpStatus, // Operation status
        };

        /// Operation type enumeration.
        pub const OpType = enum(u8) {
            vector_search, // Vector similarity search
            fulltext_search, // Full-text search (BM25)
            matrix_multiply, // Matrix multiplication
            data_transform, // Data transformation
        };

        /// Operation status enumeration.
        // 2025-11-23-114146-pst: Active enum
        pub const OpStatus = enum(u8) {
            pending, // Operation pending
            executing, // Operation executing
            completed, // Operation completed
            error_state, // Operation error
        };

        /// Initialize field compute.
        // 2025-11-23-114146-pst: Active function
        pub fn init(allocator: std.mem.Allocator, sram_capacity: u64, core_count: u32) !FieldCompute {

            // Assert: Capacity and core count must be bounded
            std.debug.assert(sram_capacity <= MAX_SRAM_CAPACITY);
            std.debug.assert(core_count <= MAX_CORES);

            // Pre-allocate cores buffer
            const cores = try allocator.alloc(Core, core_count);
            errdefer allocator.free(cores);

            // Pre-allocate SRAM data buffer
            const sram_data = try allocator.alloc(u8, @as(usize, @intCast(sram_capacity)));
            errdefer allocator.free(sram_data);

            // Pre-allocate parallel operations buffer
            const parallel_ops = try allocator.alloc(ParallelOp, MAX_PARALLEL_OPS);
            errdefer allocator.free(parallel_ops);

            // Initialize cores (toroidal topology)
            // Calculate grid dimensions (square grid for simplicity)
            const grid_size = @as(u32, @intFromFloat(@ceil(@sqrt(@as(f64, @floatFromInt(core_count))))));
            var i: u32 = 0;
            while (i < core_count) : (i += 1) {
                // Calculate toroidal neighbors (simplified: each core has 4 neighbors)
                const neighbors = try allocator.alloc(u32, 4);
                errdefer allocator.free(neighbors);

                // Toroidal topology: connect to neighbors in 2D grid
                const row = i / grid_size;
                const col = i % grid_size;
                
                // Calculate neighbor IDs (toroidal wrap-around)
                const row_down = (row + 1) % grid_size;
                const row_up = (row - 1 + grid_size) % grid_size;
                const col_right = (col + 1) % grid_size;
                const col_left = (col - 1 + grid_size) % grid_size;
                
                neighbors[0] = row_down * grid_size + col; // Down
                neighbors[1] = row_up * grid_size + col; // Up
                neighbors[2] = row * grid_size + col_right; // Right
                neighbors[3] = row * grid_size + col_left; // Left

                cores[i] = Core{
                    .id = i,
                    .state = .idle,
                    .sram_offset = 0, // Will be allocated on demand
                    .sram_size = 0,
                    .neighbors = neighbors,
                    .neighbors_len = 4,
                };
            }

            return FieldCompute{
                .cores = cores,
                .cores_len = core_count,
                .sram_capacity = sram_capacity,
                .sram_used = 0,
                .sram_data = sram_data,
                .parallel_ops = parallel_ops,
                .parallel_ops_len = 0,
                .allocator = allocator,
            };
        }

        /// Deinitialize field compute and free memory.
        pub fn deinit(self: *FieldCompute) void {
            // Assert: Allocator must be valid
            std.debug.assert(self.allocator.ptr != null);

            // Free core neighbors
            var i: u32 = 0;
            while (i < self.cores_len) : (i += 1) {
                self.allocator.free(self.cores[i].neighbors);
            }

            // Free buffers
            self.allocator.free(self.cores);
            self.allocator.free(self.sram_data);
            self.allocator.free(self.parallel_ops);

            self.* = undefined;
        }

        /// Allocate SRAM for core.
        pub fn allocate_sram(self: *FieldCompute, core_id: u32, size: u64) !u64 {
            // Assert: Core ID must be valid
            std.debug.assert(core_id < self.cores_len);

            // Assert: Size must be bounded
            std.debug.assert(size <= MAX_SRAM_CAPACITY);

            // Check SRAM availability
            if (self.sram_used + size > self.sram_capacity) {
                return error.OutOfSRAM;
            }

            // Allocate SRAM offset
            const offset = self.sram_used;
            self.sram_used += size;

            // Update core SRAM allocation
            self.cores[core_id].sram_offset = offset;
            self.cores[core_id].sram_size = size;

            return offset;
        }

        /// Execute parallel operation on field.
        // 2025-11-23-114146-pst: Active function
        pub fn execute_parallel(self: *FieldCompute, op_type: OpType, core_ids: []const u32, data_offset: u64, data_size: u64) !u32 {
            // Assert: Core IDs must be valid
            var i: u32 = 0;
            while (i < core_ids.len) : (i += 1) {
                std.debug.assert(core_ids[i] < self.cores_len);
            }

            // Check parallel operations limit
            if (self.parallel_ops_len >= MAX_PARALLEL_OPS) {
                return error.TooManyParallelOps;
            }

            // Allocate core IDs copy
            const core_ids_copy = try self.allocator.alloc(u32, core_ids.len);
            errdefer self.allocator.free(core_ids_copy);
            @memcpy(core_ids_copy, core_ids);

            // Create parallel operation
            const op_id = self.parallel_ops_len;
            self.parallel_ops[op_id] = ParallelOp{
                .op_id = op_id,
                .op_type = op_type,
                .core_ids = core_ids_copy,
                .core_ids_len = @as(u32, @intCast(core_ids.len)),
                .data_offset = data_offset,
                .data_size = data_size,
                .status = .pending,
            };
            self.parallel_ops_len += 1;

            // Mark cores as active
            i = 0;
            while (i < core_ids.len) : (i += 1) {
                self.cores[core_ids[i]].state = .active;
            }

            return op_id;
        }

        /// Get operation status.
        pub fn get_op_status(self: *FieldCompute, op_id: u32) ?OpStatus {
            if (op_id >= self.parallel_ops_len) {
                return null;
            }
            return self.parallel_ops[op_id].status;
        }

        /// Get core by ID.
        pub fn get_core(self: *FieldCompute, core_id: u32) ?*Core {
            if (core_id >= self.cores_len) {
                return null;
            }
            return &self.cores[core_id];
        }
    };
};

