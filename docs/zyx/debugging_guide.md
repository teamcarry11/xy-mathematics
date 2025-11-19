# Debugging Guide for Grain Basin Kernel

## Quick Start: Using lldb

### 1. Build with Debug Symbols

Zig builds with debug symbols by default in Debug mode. Ensure you're using Debug:

```bash
zig build hello-world-test -Doptimize=Debug
```

### 2. Run with lldb

```bash
# Build the test first
zig build hello-world-test

# Run with lldb
lldb .zig-cache/o/*/test

# In lldb:
(lldb) run
# When it crashes:
(lldb) bt          # Backtrace
(lldb) frame select 0  # Select crashing frame
(lldb) print <variable>  # Print variables
(lldb) disassemble  # See assembly
```

### 3. Set Breakpoints

```bash
(lldb) breakpoint set --file loader.zig --line 93
(lldb) breakpoint set --name loadUserspaceELF
(lldb) run
```

### 4. Common lldb Commands

```bash
# Backtrace
(lldb) bt

# Print variables
(lldb) print ptr_addr
(lldb) print alignment_required

# Step through code
(lldb) step
(lldb) next
(lldb) continue

# Inspect memory
(lldb) memory read --format hex --count 16 elf_data.ptr

# Watch variables
(lldb) watchpoint set variable ptr_addr
```

## Using Zig's Built-in Debugging

### Add Debug Prints

```zig
std.debug.print("DEBUG: Loading ELF, ptr_addr=0x{x}, alignment={}\n", .{ ptr_addr, alignment_required });
std.debug.print("DEBUG: ELF magic: {x:0>2} {x:0>2} {x:0>2} {x:0>2}\n", .{ 
    ehdr.e_ident[0], ehdr.e_ident[1], ehdr.e_ident[2], ehdr.e_ident[3] 
});
```

### Enable AddressSanitizer

Add to `build.zig`:

```zig
hello_world_tests.addCSourceFlags(&.{ "-fsanitize=address" });
hello_world_tests.linkLibC();
```

## VM-Level Debugging

Add debug prints in the VM to trace execution:

```zig
// In vm.zig step() function
std.debug.print("VM: PC=0x{x}, instruction=0x{x:0>8}\n", .{ self.regs.pc, instruction });
```

## Debugging the Current Crash

For the signal 4 (SIGILL) crash:

1. **Run with lldb**:
   ```bash
   lldb .zig-cache/o/*/test
   (lldb) run
   ```

2. **When it crashes, check backtrace**:
   ```bash
   (lldb) bt
   ```

3. **Inspect the crashing frame**:
   ```bash
   (lldb) frame select 0
   (lldb) print elf_data.ptr
   (lldb) print @intFromPtr(elf_data.ptr) % 8
   ```

4. **Check if @alignCast is the issue**:
   ```bash
   (lldb) breakpoint set --file loader.zig --line 99
   (lldb) run
   ```

## Alternative: Use GDB

If lldb doesn't work well:

```bash
# Install gdb (via Homebrew)
brew install gdb

# Run with gdb
gdb .zig-cache/o/*/test
(gdb) run
(gdb) bt
```

## Best Practices

1. **Always build in Debug mode** for debugging
2. **Use `std.debug.print`** liberally to trace execution
3. **Set breakpoints** at suspicious locations
4. **Check alignment** before using `@alignCast`
5. **Use AddressSanitizer** for memory issues

## For RISC-V VM Specifically

Since we're debugging a VM (not real RISC-V hardware):

- Debug the **host code** (Zig) that implements the VM
- Use lldb/gdb on macOS (host platform)
- Add VM-level logging to trace VM execution
- Consider adding a VM debug mode with register/memory dumps

