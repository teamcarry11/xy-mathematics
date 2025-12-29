//! Basin Kernel File Syscalls
//! Why: File system syscalls (open, read, write, close, unlink, rename, mkdir, opendir, readdir, closedir).
//! Grain Style: Explicit types, static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

// Import types
const types = @import("basin_kernel_types.zig");
const BasinError = types.BasinError;
const SyscallResult = types.SyscallResult;
const OpenFlags = types.OpenFlags;
const DirectoryHandle = types.DirectoryHandle;
const MAX_PROCESSES = types.MAX_PROCESSES;
const MAX_HANDLES = types.MAX_HANDLES;
const MAX_DIR_HANDLES = types.MAX_DIR_HANDLES;

// Import core
const core = @import("basin_kernel_core.zig");
const BasinKernel = core.BasinKernel;

/// File syscall handlers for BasinKernel.
/// Why: Extract file system syscalls to separate module for organization.
pub const FileSyscalls = struct {
    pub fn syscall_open(
        self: *BasinKernel,
        path_ptr: u64,
        path_len: u64,
        flags: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: path pointer must be valid (non-zero, within VM memory).
        if (path_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (path_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path pointer exceeds VM memory
        }
        
        // Assert: path length must be reasonable (max 4096 bytes).
        if (path_len == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Empty path
        }
        if (path_len > 4096) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path too long
        }
        
        // Assert: path must fit within VM memory.
        if (path_ptr + path_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path exceeds VM memory
        }
        
        // Decode flags (OpenFlags packed struct).
        const open_flags = @as(OpenFlags, @bitCast(@as(u32, @truncate(flags))));
        
        // Assert: flags padding must be zero (no reserved bits set).
        if (open_flags._padding != 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Reserved bits set
        }
        
        // Assert: flags must have at least one permission (read or write).
        if (!open_flags.read and !open_flags.write) {
            return SyscallResult.fail(BasinError.invalid_argument); // No permissions set
        }
        
        // Assert: path length must fit in handle path buffer (max 256 bytes, so max path_len is 255).
        // Note: path_len is the string length, handle.path is 256 bytes, so max path_len is 255.
        if (path_len > 255) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path too long for handle buffer
        }
        
        // Assert: path_len must be > 0 (already checked above, but double-check for safety).
        Debug.kassert(path_len > 0, "Path len is 0", .{});
        Debug.kassert(path_len <= 255, "Path len > 255", .{});
        
        // Find free handle entry.
        const handle_idx = self.find_free_handle() orelse {
            return SyscallResult.fail(BasinError.out_of_memory); // Handle table full
        };
        
        // Get current process ID from scheduler.
        // Why: Track which process owns this handle for resource cleanup.
        const current_process_id = self.scheduler.get_current();
        const owner_process_id = @as(u32, @truncate(current_process_id));
        
        // Check file descriptor limit for current process.
        if (current_process_id > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_process_id) {
                    if (!self.can_open_file_descriptor(self, &self.processes[i])) {
                        return SyscallResult.fail(BasinError.resource_exhausted); // File descriptor limit exceeded
                    }
                    break;
                }
            }
        }
        
        // Allocate handle entry.
        var file_handle = &self.handles[handle_idx];
        const handle_id = self.next_handle_id;
        self.next_handle_id += 1;
        
        // Assert: Handle ID must be non-zero (1-based).
        Debug.kassert(handle_id != 0, "Handle ID is 0", .{});
        
        // Note: Actual path reading from VM memory is handled by integration layer.
        // This kernel syscall validates parameters and creates handle entry.
        // Integration layer will:
        // 1. Read path string from VM memory at path_ptr
        // 2. Look up or create file in storage filesystem
        // 3. Link handle to storage file entry
        // For now, we create handle entry and store path length.
        file_handle.id = handle_id;
        file_handle.path_len = @as(u32, @intCast(path_len));
        file_handle.flags = open_flags;
        file_handle.position = 0;
        file_handle.buffer_size = 0;
        file_handle.allocated = true;
        file_handle.owner_process_id = owner_process_id;
        
        // If truncate flag is set, clear buffer.
        if (open_flags.truncate) {
            file_handle.buffer_size = 0;
        }
        
        // Update process resource usage (increment file descriptor count).
        if (current_process_id > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_process_id) {
                    self.processes[i].open_file_descriptors += 1;
                    break;
                }
            }
        }
        
        // Assert: Handle must be allocated correctly.
        Debug.kassert(file_handle.allocated, "Handle not allocated", .{});
        Debug.kassert(file_handle.id == handle_id, "Handle ID mismatch", .{});
        Debug.kassert(file_handle.path_len == @as(u32, @intCast(path_len)), "Path len mismatch", .{});
        
        const result = SyscallResult.ok(handle_id);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == handle_id, "Result value mismatch", .{});
        
        return result;
    }
    
    pub fn syscall_read(
        self: *BasinKernel,
        handle: u64,
        buffer_ptr: u64,
        buffer_len: u64,
        timeout_ns: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Record start time for timeout checking.
        const start_time_ns = self.timer.get_monotonic_ns();
        
        // Assert: handle must be valid (non-zero).
        if (handle == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Invalid handle
        }
        
        // Assert: buffer pointer must be valid (non-zero, within VM memory).
        if (buffer_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (buffer_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Buffer pointer exceeds VM memory
        }
        
        // Assert: buffer length must be reasonable (max 1MB per read).
        if (buffer_len == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Zero-length buffer
        }
        if (buffer_len > 1024 * 1024) {
            return SyscallResult.fail(BasinError.invalid_argument); // Buffer too large (> 1MB)
        }
        
        // Assert: buffer must fit within VM memory.
        if (buffer_ptr + buffer_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Buffer exceeds VM memory
        }
        
        // Find handle by ID.
        const handle_idx = self.find_handle_by_id(handle) orelse {
            return SyscallResult.fail(BasinError.invalid_handle); // Handle not found
        };
        
        // Assert: Handle must be allocated.
        Debug.kassert(self.handles[handle_idx].allocated, "Handle not allocated", .{});
        Debug.kassert(self.handles[handle_idx].id == handle, "Handle ID mismatch", .{});
        
        var file_handle = &self.handles[handle_idx];
        
        // Assert: Handle must be readable.
        if (!file_handle.flags.read) {
            return SyscallResult.fail(BasinError.permission_denied); // Handle not readable
        }
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return SyscallResult.fail(BasinError.file_io_timeout); // Timeout expired
        }
        
        // Note: Actual file data reading is handled by integration layer.
        // This kernel syscall validates parameters and calculates read size.
        // Integration layer will:
        // 1. Look up file in storage filesystem by handle path
        // 2. Read data from storage file entry
        // 3. Write data to VM memory at buffer_ptr
        // For now, we use handle buffer (in-memory file data).
        // Calculate bytes to read (min of available data and buffer size).
        // Note: In a real implementation, this would be a blocking operation that checks timeout periodically.
        const available = if (file_handle.position < file_handle.buffer_size)
            file_handle.buffer_size - file_handle.position
        else
            0;
        const bytes_to_read = @min(available, @as(u32, @intCast(buffer_len)));
        
        // Note: Integration layer will write data to VM memory.
        // For now, just update position (data is in handle buffer).
        file_handle.position += bytes_to_read;
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return SyscallResult.fail(BasinError.file_io_timeout); // Timeout expired
        }
        
        // Assert: Position must not exceed buffer size.
        Debug.kassert(file_handle.position <= file_handle.buffer_size, "Position > buffer size", .{});
        
        const bytes_read: u64 = @as(u64, @intCast(bytes_to_read));
        const result = SyscallResult.ok(bytes_read);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == bytes_read, "Result value mismatch", .{});
        Debug.kassert(result.success <= buffer_len, "Read > buffer len", .{});
        
        return result;
    }
    
    pub fn syscall_write(
        self: *BasinKernel,
        handle: u64,
        data_ptr: u64,
        data_len: u64,
        timeout_ns: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Record start time for timeout checking.
        const start_time_ns = self.timer.get_monotonic_ns();
        
        // Assert: handle must be valid (non-zero).
        if (handle == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Invalid handle
        }
        
        // Assert: data pointer must be valid (non-zero, within VM memory).
        if (data_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (data_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Data pointer exceeds VM memory
        }
        
        // Assert: data length must be reasonable (max 1MB per write).
        if (data_len == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Zero-length data
        }
        if (data_len > 1024 * 1024) {
            return SyscallResult.fail(BasinError.invalid_argument); // Data too large (> 1MB)
        }
        
        // Assert: data must fit within VM memory.
        if (data_ptr + data_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Data exceeds VM memory
        }
        
        // Find handle by ID.
        const handle_idx = self.find_handle_by_id(handle) orelse {
            return SyscallResult.fail(BasinError.invalid_handle); // Handle not found
        };
        
        // Assert: Handle must be allocated.
        Debug.kassert(self.handles[handle_idx].allocated, "Handle not allocated", .{});
        Debug.kassert(self.handles[handle_idx].id == handle, "Handle ID mismatch", .{});
        
        var file_handle = &self.handles[handle_idx];
        
        // Assert: Handle must be writable.
        if (!file_handle.flags.write) {
            return SyscallResult.fail(BasinError.permission_denied); // Handle not writable
        }
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return SyscallResult.fail(BasinError.file_io_timeout); // Timeout expired
        }
        
        // Calculate bytes to write (min of data length and available buffer space).
        const data_len_u32 = @as(u32, @intCast(data_len));
        const max_buffer_size = file_handle.buffer.len;
        const available_space = if (file_handle.position < max_buffer_size)
            @as(u32, @intCast(max_buffer_size - file_handle.position))
        else
            0;
        const bytes_to_write = @min(data_len_u32, available_space);
        
        // Write data to handle buffer (simulated - in real implementation, would read from VM memory).
        // Note: In a real implementation, this would be a blocking operation that checks timeout periodically.
        // For now, just update position and buffer size.
        file_handle.position += bytes_to_write;
        if (file_handle.position > file_handle.buffer_size) {
            file_handle.buffer_size = @as(u32, @intCast(file_handle.position));
        }
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return SyscallResult.fail(BasinError.file_io_timeout); // Timeout expired
        }
        
        // Assert: Position and buffer size must be valid.
        Debug.kassert(file_handle.position <= max_buffer_size, "Position > max buffer", .{});
        Debug.kassert(file_handle.buffer_size <= max_buffer_size, "Buffer size > max", .{});
        
        const bytes_written: u64 = @as(u64, @intCast(bytes_to_write));
        const result = SyscallResult.ok(bytes_written);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == bytes_written, "Result value mismatch", .{});
        Debug.kassert(result.success <= data_len, "Written > data len", .{}); // Can't write more than data length
        
        return result;
    }
    
    pub fn syscall_close(
        self: *BasinKernel,
        handle: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: handle must be valid (non-zero).
        if (handle == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Invalid handle
        }
        
        // Find handle by ID.
        const handle_idx = self.find_handle_by_id(handle) orelse {
            return SyscallResult.fail(BasinError.invalid_handle); // Handle not found
        };
        
        // Assert: Handle must be allocated.
        Debug.kassert(self.handles[handle_idx].allocated, "Handle not allocated", .{});
        Debug.kassert(self.handles[handle_idx].id == handle, "Handle ID mismatch", .{});
        
        // Close handle (free entry).
        var file_handle = &self.handles[handle_idx];
        const owner_pid = file_handle.owner_process_id;
        file_handle.allocated = false;
        file_handle.id = 0;
        file_handle.path_len = 0;
        file_handle.position = 0;
        file_handle.buffer_size = 0;
        file_handle.owner_process_id = 0;
        
        // Update process resource usage (decrement file descriptor count).
        if (owner_pid > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == owner_pid) {
                    if (self.processes[i].open_file_descriptors > 0) {
                        self.processes[i].open_file_descriptors -= 1;
                    }
                    break;
                }
            }
        }
        
        // Assert: Handle must be unallocated after close.
        Debug.kassert(!file_handle.allocated, "Handle still allocated", .{});
        Debug.kassert(file_handle.id == 0, "Handle ID not 0", .{});
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == 0, "Result not 0", .{}); // Close returns 0 on success
        
        return result;
    }
    
    pub fn syscall_unlink(
        self: *BasinKernel,
        path_ptr: u64,
        path_len: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: path pointer must be valid (non-zero, within VM memory).
        if (path_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (path_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path pointer exceeds VM memory
        }
        
        // Assert: path length must be reasonable (max 4096 bytes).
        if (path_len == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Empty path
        }
        if (path_len > 4096) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path too long
        }
        
        // Assert: path must fit within VM memory.
        if (path_ptr + path_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path exceeds VM memory
        }
        
        // Find handle by path and remove it (simulated file deletion).
        // For now, search for handle with matching path and mark as deleted.
        var found: bool = false;
        for (0..MAX_HANDLES) |i| {
            if (self.handles[i].allocated and self.handles[i].path_len == @as(u32, @intCast(path_len))) {
                // In real implementation, would compare path strings.
                // For now, just mark as deleted if path length matches.
                self.handles[i].allocated = false;
                self.handles[i].id = 0;
                found = true;
                break;
            }
        }
        
        if (!found) {
            return SyscallResult.fail(BasinError.not_found); // File not found
        }
        
        const result = SyscallResult.ok(0);
        return result;
    }
    
    pub fn syscall_rename(
        self: *BasinKernel,
        old_path_ptr: u64,
        old_path_len: u64,
        new_path_ptr: u64,
        new_path_len: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Assert: old path pointer must be valid (non-zero, within VM memory).
        if (old_path_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (old_path_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Old path pointer exceeds VM memory
        }
        
        // Assert: new path pointer must be valid (non-zero, within VM memory).
        if (new_path_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        if (new_path_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // New path pointer exceeds VM memory
        }
        
        // Assert: path lengths must be reasonable (max 4096 bytes).
        if (old_path_len == 0 or old_path_len > 4096) {
            return SyscallResult.fail(BasinError.invalid_argument); // Invalid old path length
        }
        if (new_path_len == 0 or new_path_len > 4096) {
            return SyscallResult.fail(BasinError.invalid_argument); // Invalid new path length
        }
        
        // Assert: paths must fit within VM memory.
        if (old_path_ptr + old_path_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Old path exceeds VM memory
        }
        if (new_path_ptr + new_path_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // New path exceeds VM memory
        }
        
        // Find handle by old path and update to new path (simulated rename).
        // For now, search for handle with matching path length and update.
        var found: bool = false;
        for (0..MAX_HANDLES) |i| {
            if (self.handles[i].allocated and self.handles[i].path_len == @as(u32, @intCast(old_path_len))) {
                // In real implementation, would compare path strings and update.
                // For now, just update path length if it matches.
                self.handles[i].path_len = @as(u32, @intCast(new_path_len));
                found = true;
                break;
            }
        }
        
        if (!found) {
            return SyscallResult.fail(BasinError.not_found); // File not found
        }
        
        const result = SyscallResult.ok(0);
        return result;
    }
    
    pub fn syscall_mkdir(
        self: *BasinKernel,
        path_ptr: u64,
        path_len: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: path pointer must be valid (non-zero, within VM memory).
        if (path_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (path_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path pointer exceeds VM memory
        }
        
        // Assert: path length must be reasonable (max 4096 bytes).
        if (path_len == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Empty path
        }
        if (path_len > 4096) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path too long
        }
        
        // Assert: path must fit within VM memory.
        if (path_ptr + path_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path exceeds VM memory
        }
        
        // Check if directory already exists (simulated).
        // For now, just check if handle with same path exists.
        for (0..MAX_HANDLES) |i| {
            if (self.handles[i].allocated and self.handles[i].path_len == @as(u32, @intCast(path_len))) {
                // In real implementation, would compare path strings.
                // For now, return error if path length matches (directory exists).
                return SyscallResult.fail(BasinError.invalid_argument); // Directory already exists
            }
        }
        
        // Create directory (simulated - in real implementation, would create directory entry).
        // For now, just return success (directory created).
        const result = SyscallResult.ok(0);
        return result;
    }
    
    pub fn syscall_opendir(
        self: *BasinKernel,
        path_ptr: u64,
        path_len: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: path pointer must be valid (non-zero, within VM memory).
        if (path_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (path_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        // Assert: path length must be reasonable (max 256 bytes).
        if (path_len == 0 or path_len > 256) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        // Find free directory handle slot.
        var slot: ?usize = null;
        for (0..MAX_DIR_HANDLES) |i| {
            if (!self.dir_handles[i].allocated) {
                slot = i;
                break;
            }
        }
        
        if (slot == null) {
            return SyscallResult.fail(BasinError.out_of_memory);
        }
        
        const idx = slot.?;
        
        // Allocate directory handle.
        const handle_id = self.next_dir_handle_id;
        self.next_dir_handle_id += 1;
        
        // Copy path (simulated - in real implementation, would read from VM memory).
        self.dir_handles[idx].id = handle_id;
        self.dir_handles[idx].path_len = @as(u32, @intCast(path_len));
        self.dir_handles[idx].position = 0;
        self.dir_handles[idx].allocated = true;
        
        // Return directory handle ID.
        const result = SyscallResult.ok(handle_id);
        return result;
    }
    
    pub fn syscall_readdir(
        self: *BasinKernel,
        dir_handle: u64,
        entry_ptr: u64,
        entry_len: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: directory handle must be valid (non-zero).
        if (dir_handle == 0) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        // Assert: entry pointer must be valid (non-zero, within VM memory).
        if (entry_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (entry_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        // Assert: entry length must be reasonable (max 256 bytes).
        if (entry_len == 0 or entry_len > 256) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        // Find directory handle.
        var found: ?usize = null;
        for (0..MAX_DIR_HANDLES) |i| {
            if (self.dir_handles[i].allocated and self.dir_handles[i].id == dir_handle) {
                found = i;
                break;
            }
        }
        
        if (found == null) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        const idx = found.?;
        
        // Simulated directory reading: return empty (end of directory).
        // In real implementation, would read directory entries from file system.
        // For now, return 0 (no more entries) after first read.
        if (self.dir_handles[idx].position > 0) {
            return SyscallResult.ok(0); // End of directory
        }
        
        // First read: return stub entry name "."
        // In real implementation, would write entry name to entry_ptr.
        self.dir_handles[idx].position += 1;
        
        // Return bytes written (simulated - would be actual entry name length).
        const result = SyscallResult.ok(1); // 1 byte for "."
        return result;
    }
    
    pub fn syscall_closedir(
        self: *BasinKernel,
        dir_handle: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: directory handle must be valid (non-zero).
        if (dir_handle == 0) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        // Find and free directory handle.
        var found: bool = false;
        for (0..MAX_DIR_HANDLES) |i| {
            if (self.dir_handles[i].allocated and self.dir_handles[i].id == dir_handle) {
                self.dir_handles[i] = DirectoryHandle.init();
                found = true;
                break;
            }
        }
        
        if (!found) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        const result = SyscallResult.ok(0);
        return result;
    }
};
