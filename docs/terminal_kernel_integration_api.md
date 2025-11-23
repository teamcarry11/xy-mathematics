# Grain Terminal Kernel Integration API

**Purpose**: API documentation for Grain Terminal integration with Grain Basin Kernel.

**Status**: Phase 3.16 - Terminal Kernel Integration

**GrainStyle**: All APIs follow GrainStyle/TigerStyle principles (explicit types, bounded operations, static allocation).

---

## 1. Input Event Handling

### Syscall: `read_input_event`

**Syscall Number**: `60`

**Signature**:
```zig
// RISC-V syscall: a7 = 60, a0 = event_buf, a1 = reserved, a2 = reserved, a3 = reserved
// Returns: number of bytes written (32) on success, negative error code on failure
```

**Description**: Read the next input event (keyboard or mouse) from the kernel's input event queue.

**Parameters**:
- `event_buf` (u64): Virtual address in VM memory where the event structure will be written (must be valid, non-zero, within VM memory bounds)
- `arg2`, `arg3`, `arg4`: Reserved (must be 0)

**Return Value**:
- Success: Returns `32` (number of bytes written)
- Error codes (negative, cast to i64):
  - `-2` (`invalid_argument`): `event_buf` is null or invalid
  - `-6` (`would_block`): No events available (non-blocking)
  - `-9` (`invalid_address`): `event_buf + 32` exceeds VM memory bounds

**Event Structure Format** (32 bytes):

```
Offset  Size  Field        Description
------  ----  -----------  -----------------------------------------
0       1     event_type   0 = mouse, 1 = keyboard
1-3     3     reserved     Reserved (must be 0)

For mouse events (event_type == 0):
4       1     kind         0 = down, 1 = up, 2 = move, 3 = drag
5       1     button       0 = left, 1 = right, 2 = middle, 3 = other
6-9     4     x            X coordinate (u32, little-endian, 0-1023)
10-13   4     y            Y coordinate (u32, little-endian, 0-767)
14      1     modifiers    Bit flags: 1=shift, 2=control, 4=option, 8=command
15-31   17    reserved     Reserved (must be 0)

For keyboard events (event_type == 1):
4       1     kind         0 = down, 1 = up
5-7     3     reserved     Reserved (must be 0)
8-11    4     key_code     Platform key code (u32, little-endian)
12-15   4     character    Unicode character (u32, little-endian, 0 if not printable)
16      1     modifiers    Bit flags: 1=shift, 2=control, 4=option, 8=command
17-31   15    reserved     Reserved (must be 0)
```

**Usage Example**:
```zig
// Allocate event buffer in VM memory (32 bytes)
const event_buf: u64 = 0x100000; // Example address

// Read input event (non-blocking)
const result = syscall_read_input_event(event_buf, 0, 0, 0);

if (result > 0) {
    // Event read successfully (result == 32)
    // Parse event structure at event_buf
    const event_type = read_u8(event_buf);
    if (event_type == 0) {
        // Mouse event
        const kind = read_u8(event_buf + 4);
        const button = read_u8(event_buf + 5);
        const x = read_u32(event_buf + 6);
        const y = read_u32(event_buf + 10);
        const modifiers = read_u8(event_buf + 14);
    } else if (event_type == 1) {
        // Keyboard event
        const kind = read_u8(event_buf + 4);
        const key_code = read_u32(event_buf + 8);
        const character = read_u32(event_buf + 12);
        const modifiers = read_u8(event_buf + 16);
    }
} else if (result == -6) {
    // No events available (would_block)
    // Terminal should continue without blocking
} else {
    // Error occurred
    handle_error(result);
}
```

**Notes**:
- This syscall is **non-blocking**: returns `would_block` if no events are available
- Events are queued in the VM's input event queue (max 64 events)
- Events are dequeued in FIFO order
- If the queue is full, oldest events are dropped when new events arrive
- Coordinate system: X (0-1023), Y (0-767) matches framebuffer dimensions

---

## 2. File I/O for Configuration Files

### Syscall: `open`

**Syscall Number**: `30`

**Signature**:
```zig
// RISC-V syscall: a7 = 30, a0 = path_ptr, a1 = path_len, a2 = flags, a3 = reserved
// Returns: file handle (u64) on success, negative error code on failure
```

**Description**: Open a file (e.g., configuration file) for reading or writing.

**Parameters**:
- `path_ptr` (u64): Virtual address of null-terminated file path string
- `path_len` (u64): Length of path string (max 256 bytes)
- `flags` (u64): Open flags (bitmask):
  - Bit 0 (1): `read` - Open for reading
  - Bit 1 (2): `write` - Open for writing
  - Bit 2 (4): `create` - Create file if it doesn't exist
  - Bit 3 (8): `truncate` - Truncate file to zero length
- `arg4`: Reserved (must be 0)

**Return Value**:
- Success: Returns file handle (non-zero u64)
- Error codes (negative, cast to i64):
  - `-2` (`invalid_argument`): Invalid parameters
  - `-3` (`not_found`): File not found
  - `-13` (`permission_denied`): Permission denied

**Usage Example**:
```zig
// Open configuration file for reading
const config_path = "/home/user/.grain_terminal/config";
const path_ptr: u64 = 0x200000; // Example address
write_string(path_ptr, config_path);

const handle = syscall_open(path_ptr, config_path.len, 1, 0); // flags = read (1)
if (handle > 0) {
    // File opened successfully
    // Use handle for read/write operations
} else {
    // Error occurred
    handle_error(handle);
}
```

### Syscall: `read`

**Syscall Number**: `31`

**Signature**:
```zig
// RISC-V syscall: a7 = 31, a0 = handle, a1 = buffer_ptr, a2 = buffer_len, a3 = reserved
// Returns: number of bytes read (u64) on success, negative error code on failure
```

**Description**: Read data from an open file.

**Parameters**:
- `handle` (u64): File handle returned by `open`
- `buffer_ptr` (u64): Virtual address where data will be written
- `buffer_len` (u64): Maximum number of bytes to read (max 1MB)
- `arg4`: Reserved (must be 0)

**Return Value**:
- Success: Returns number of bytes read (0 = EOF)
- Error codes (negative, cast to i64):
  - `-2` (`invalid_argument`): Invalid parameters
  - `-5` (`invalid_handle`): Invalid file handle
  - `-13` (`permission_denied`): File not opened for reading

### Syscall: `write`

**Syscall Number**: `32`

**Signature**:
```zig
// RISC-V syscall: a7 = 32, a0 = handle, a1 = data_ptr, a2 = data_len, a3 = reserved
// Returns: number of bytes written (u64) on success, negative error code on failure
```

**Description**: Write data to an open file.

**Parameters**:
- `handle` (u64): File handle returned by `open`
- `data_ptr` (u64): Virtual address of data to write
- `data_len` (u64): Number of bytes to write (max 1MB)
- `arg4`: Reserved (must be 0)

**Return Value**:
- Success: Returns number of bytes written
- Error codes (negative, cast to i64):
  - `-2` (`invalid_argument`): Invalid parameters
  - `-5` (`invalid_handle`): Invalid file handle
  - `-13` (`permission_denied`): File not opened for writing

### Syscall: `close`

**Syscall Number**: `33`

**Signature**:
```zig
// RISC-V syscall: a7 = 33, a0 = handle, a1 = reserved, a2 = reserved, a3 = reserved
// Returns: 0 on success, negative error code on failure
```

**Description**: Close an open file handle.

**Parameters**:
- `handle` (u64): File handle to close
- `arg2`, `arg3`, `arg4`: Reserved (must be 0)

**Return Value**:
- Success: Returns `0`
- Error codes (negative, cast to i64):
  - `-5` (`invalid_handle`): Invalid file handle

**Configuration File Usage Example**:
```zig
// Load configuration file
fn load_config(config_path: []const u8) !Config {
    // Open file
    const handle = syscall_open(path_ptr, path_len, 1, 0); // read flag
    if (handle <= 0) {
        return error.FileNotFound;
    }
    defer syscall_close(handle, 0, 0, 0);
    
    // Read file data
    const buffer_ptr: u64 = 0x300000;
    const buffer_len: u64 = 4096; // Max 4KB config file
    const bytes_read = syscall_read(handle, buffer_ptr, buffer_len, 0);
    if (bytes_read <= 0) {
        return error.ReadFailed;
    }
    
    // Parse configuration from buffer
    return parse_config(buffer_ptr, bytes_read);
}

// Save configuration file
fn save_config(config_path: []const u8, config: Config) !void {
    // Open file (create if doesn't exist, truncate)
    const handle = syscall_open(path_ptr, path_len, 2 | 4 | 8, 0); // write | create | truncate
    if (handle <= 0) {
        return error.OpenFailed;
    }
    defer syscall_close(handle, 0, 0, 0);
    
    // Serialize configuration to buffer
    const buffer_ptr: u64 = 0x300000;
    const buffer_len = serialize_config(buffer_ptr, config);
    
    // Write file data
    const bytes_written = syscall_write(handle, buffer_ptr, buffer_len, 0);
    if (bytes_written != buffer_len) {
        return error.WriteFailed;
    }
}
```

---

## 3. Process Execution

### Syscall: `spawn`

**Syscall Number**: `1`

**Signature**:
```zig
// RISC-V syscall: a7 = 1, a0 = executable_ptr, a1 = args_ptr, a2 = args_len, a3 = reserved
// Returns: process ID (u64) on success, negative error code on failure
```

**Description**: Spawn a new process (e.g., shell command, external program).

**Parameters**:
- `executable_ptr` (u64): Virtual address of ELF executable in VM memory (must be valid ELF header)
- `args_ptr` (u64): Virtual address of argument string (null-terminated, can be 0 for no args)
- `args_len` (u64): Length of argument string (0 if `args_ptr` is 0, max 64KB)
- `arg4`: Reserved (must be 0)

**Return Value**:
- Success: Returns process ID (non-zero u64)
- Error codes (negative, cast to i64):
  - `-2` (`invalid_argument`): Invalid parameters or invalid ELF header
  - `-12` (`out_of_memory`): No free process slots

**Usage Example**:
```zig
// Spawn a shell command (e.g., "ls -la")
fn spawn_command(command: []const u8, args: []const u8) !u64 {
    // Load ELF executable into VM memory
    const executable_ptr: u64 = 0x400000;
    // ... load ELF data ...
    
    // Prepare arguments
    const args_ptr: u64 = 0x500000;
    write_string(args_ptr, args);
    
    // Spawn process
    const pid = syscall_spawn(executable_ptr, args_ptr, args.len, 0);
    if (pid <= 0) {
        return error.SpawnFailed;
    }
    
    return pid;
}
```

**Notes**:
- The kernel parses the ELF header to extract the entry point
- Process context (PC, SP) is initialized from the ELF
- Process is added to the scheduler and can be executed via `schedule_and_run_next`
- Maximum 16 processes can be spawned simultaneously

---

## 4. Error Codes

All syscalls return negative error codes (cast to i64) on failure:

```zig
pub const ErrorCode = enum(i64) {
    invalid_argument = -2,
    not_found = -3,
    out_of_memory = -12,
    permission_denied = -13,
    invalid_handle = -5,
    would_block = -6,
    invalid_address = -9,
    invalid_syscall = -1,
};
```

---

## 5. Integration Notes

### Input Event Queue
- Events are injected into the VM's input event queue by the host platform (macOS)
- Queue size: 64 events (bounded, static allocation)
- Events are dequeued in FIFO order
- If queue is full, oldest events are dropped

### File I/O
- Files are stored in the kernel's in-memory filesystem (`Storage`)
- File handles are tracked by the kernel
- Maximum file size: 1MB (configurable)
- File paths are null-terminated strings

### Process Execution
- Processes are executed via the scheduler (`schedule_and_run_next`)
- Process context switching is handled by `process_execution` module
- Maximum 16 processes can run simultaneously
- Process exit is handled via `syscall_exit`

---

## 6. Testing

See `tests/047_terminal_kernel_integration_test.zig` for comprehensive tests covering:
- Input event reading (keyboard and mouse)
- File I/O operations (open, read, write, close)
- Process spawning
- Error handling

---

## 7. Coordination

**VM/Kernel Agent**: This API is ready for use. All syscalls are implemented and tested.

**Skate Agent**: Use these APIs to:
1. Read input events for terminal input handling
2. Load/save configuration files
3. Spawn processes for command execution

**Aurora Agent**: Coordinate for:
- Framebuffer rendering (terminal already uses framebuffer syscalls)
- Window management (if needed)

