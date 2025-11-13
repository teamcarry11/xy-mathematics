# 006 Fuzz Test: Memory Management Foundation

**Date**: 2025-11-13  
**Objective**: Validate memory management syscalls (map/unmap/protect) with randomized fuzz testing for mapping table operations, overlap detection, allocation/deallocation patterns, and edge cases.

## Test Categories

### 1. Map Operations Fuzzing (`006_fuzz_map_operations`)
- **Objective**: Validate map syscall with random addresses, sizes, and flags.
- **Method**: Generate 200 random map operations with:
  - Random addresses (kernel-chosen vs user-provided)
  - Random page-aligned sizes (4KB - 64KB)
  - Random MapFlags (read, write, execute, shared combinations)
- **Assertions**:
  - Success result must have valid address (>= 0x100000, page-aligned)
  - Mapping must be tracked in table (count > 0, <= 256)
  - Final mapping count must be <= 256 (max mappings)

### 2. Unmap Operations Fuzzing (`006_fuzz_unmap_operations`)
- **Objective**: Validate unmap syscall with random addresses.
- **Method**: 
  - Create 64 random mappings first
  - Generate 100 random unmap operations (existing vs non-existent mappings)
- **Assertions**:
  - Success result must be 0 (unmap returns 0 on success)
  - Mapping must be removed from table (count decreases)
  - Error must be invalid_argument if mapping not found

### 3. Protect Operations Fuzzing (`006_fuzz_protect_operations`)
- **Objective**: Validate protect syscall with random addresses and flags.
- **Method**:
  - Create 32 random mappings first
  - Generate 100 random protect operations (existing vs non-existent mappings)
  - Random MapFlags (must have at least one permission)
- **Assertions**:
  - Success result must be 0 (protect returns 0 on success)
  - Error must be invalid_argument if mapping not found

### 4. Overlap Detection Fuzzing (`006_fuzz_overlap_detection`)
- **Objective**: Validate overlap detection prevents overlapping mappings.
- **Method**:
  - Create initial mapping
  - Generate 100 random overlapping addresses (from start vs from before)
  - Round to page boundaries
- **Assertions**:
  - Result must be error (overlapping mapping)
  - Error must be invalid_argument
  - If success (edge case: exact boundaries), verify no actual overlap

### 5. Table Exhaustion Fuzzing (`006_fuzz_table_exhaustion`)
- **Objective**: Validate mapping table exhaustion (max 256 entries).
- **Method**:
  - Fill mapping table to capacity (256 entries)
  - Try to allocate one more mapping (should fail if table full)
- **Assertions**:
  - Mapping count must match allocated count
  - If table full (256 entries), error must be out_of_memory
  - If table has space, success is valid

### 6. Edge Cases Fuzzing (`006_fuzz_edge_cases`)
- **Objective**: Validate edge cases (zero size, unaligned addresses, invalid flags, etc.).
- **Test Cases**:
  1. Zero size (should fail with invalid_argument or unaligned_access)
  2. Unaligned address (should fail with unaligned_access)
  3. Invalid flags (no permissions, should fail with invalid_argument)
  4. Kernel space address (should fail with permission_denied)
  5. Unmap non-existent mapping (should fail with invalid_argument)
  6. Protect non-existent mapping (should fail with invalid_argument)
- **Assertions**: Each edge case must fail with correct error type

### 7. State Consistency Fuzzing (`006_fuzz_state_consistency`)
- **Objective**: Validate mapping table state consistency after operations.
- **Method**: Perform 100 random operations (map/unmap/protect) and validate state after each.
- **Assertions**:
  - Mapping count must be <= 256
  - All allocated mappings must have valid addresses (>= 0x100000, page-aligned)
  - All allocated mappings must have valid sizes (>= 4KB, page-aligned)
  - Mapping table state must be consistent after each operation

## Helper Functions

- `generate_user_address()`: Generate random page-aligned address in user space
- `generate_page_aligned_size()`: Generate random page-aligned size (4KB - 64KB)
- `generate_map_flags()`: Generate random MapFlags (read, write, execute, shared)
- `generate_address_choice()`: Generate random kernel-chosen (0) vs user-provided address

## Assertions Added to Code

### BasinKernel Memory Management Functions

1. **`find_free_mapping()`**:
   - Self pointer validity and alignment
   - Unallocated mappings must have zero address and size
   - Allocated mappings must have valid address and size
   - Free count must be <= MAX_MAPPINGS

2. **`find_mapping_by_address()`**:
   - Self pointer validity and alignment
   - Address must be page-aligned
   - Address must be unique (no duplicate mappings)
   - Matching mapping must have valid state

3. **`check_overlap()`**:
   - Self pointer validity and alignment
   - Address and size must be valid (page-aligned, >= 4KB)
   - Overlapping mapping must be allocated
   - Overlap count must be consistent (0 or 1, no duplicates)

4. **`count_allocated_mappings()`** (public method):
   - Self pointer validity and alignment
   - Allocated mappings must have valid state (address, size, alignment)
   - Count must be <= MAX_MAPPINGS

## Tiger Style Compliance

- **Deterministic Randomness**: SimpleRng with wrap-safe arithmetic
- **Comprehensive Assertions**: All operations validated with assertions
- **Explicit Error Handling**: All error cases explicitly handled
- **Zero Warnings**: All compilation warnings resolved
- **Static Allocation**: Mapping table uses static allocation (no dynamic memory)

## Expected Results

All 7 test categories should pass, validating:
- Memory mapping operations work correctly
- Overlap detection prevents overlapping mappings
- Table exhaustion handled correctly
- Edge cases fail with correct errors
- State consistency maintained throughout operations

