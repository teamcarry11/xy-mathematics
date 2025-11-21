# GrainView Browser: Zig-Native Web Browser for Grain OS

## Overview

**GrainView** is a native web browser written in Zig, designed to run on the Grain Basin Kernel (RISC-V) within the Grain VM macOS Tahoe application. It uses Grain Aurora UI as its native rendering engine and follows the GrainStyle coding philosophy.

## Architecture

### Target Platform
- **Host OS**: macOS Sequoia 15.1 (Tahoe)
- **VM**: Grain VM (RISC-V emulation via JIT)
- **Kernel**: Grain Basin Kernel (RISC-V64)
- **UI Framework**: Grain Aurora
- **Language**: Zig (zero dependencies)

### Hardware Specifications
- **Device**: MacBook Air M2 (2022)
- **Storage**: 1TB SSD
- **Memory**: 24GB RAM
- **CPU**: Apple M2 (AArch64 native, RISC-V via JIT)

## Design Goals

1. **Zero Dependencies**: Pure Zig implementation, no external libraries
2. **GrainStyle Compliance**: 73-char line width, 70-line function limit, explicit types
3. **Native Performance**: Leverage Grain VM JIT for RISC-V → AArch64 translation
4. **Grain Aurora Integration**: Use existing UI framework for rendering
5. **Minimal Kernel Surface**: Reimplement only necessary POSIX functionality

## Implementation Phases

### Phase 1: Core Engine
- [ ] HTML parser (subset of HTML5)
- [ ] CSS parser (subset of CSS3)
- [ ] DOM tree construction
- [ ] Layout engine (block/inline flow)
- [ ] Basic rendering to Grain Aurora framebuffer

### Phase 2: Networking
- [ ] HTTP/1.1 client (no TLS initially)
- [ ] URL parsing and resolution
- [ ] Resource fetching (HTML, CSS, images)
- [ ] Basic caching

### Phase 3: JavaScript Engine
- [ ] ECMAScript 5 subset parser
- [ ] Interpreter (or JIT via Grain VM)
- [ ] DOM API bindings
- [ ] Event system

### Phase 4: Advanced Features
- [ ] TLS/HTTPS support
- [ ] Image decoding (PNG, JPEG)
- [ ] Font rendering
- [ ] Scrolling and navigation
- [ ] Bookmarks and history

## Kernel Requirements

The Grain Basin Kernel must provide:

1. **Network Stack**: TCP/IP implementation
2. **File System**: Basic POSIX file operations
3. **Memory Management**: Heap allocation, mmap
4. **Process Management**: Multi-process support for tabs
5. **System Calls**: Minimal POSIX syscalls (read, write, open, close, socket, etc.)

## QEMU Development Environment

For initial development and testing:

1. **Install QEMU**: `brew install qemu`
2. **RISC-V Target**: Use `qemu-system-riscv64` for kernel testing
3. **VirtIO Devices**: Network and block devices for I/O
4. **Debugging**: GDB remote debugging via QEMU

## GrainStyle Constraints

All code must follow GrainStyle:
- **Line Width**: 73 characters (graincard compatible)
- **Function Length**: Max 70 lines
- **Types**: Explicit (u32, u64, not usize)
- **Memory**: Static allocation only (startup)
- **Assertions**: Minimum 2 per function (pair assertions)

## Integration with Grain Aurora

GrainView will use Grain Aurora's:
- **Framebuffer**: Direct pixel access for rendering
- **Input System**: Keyboard and mouse events
- **Window Management**: Native macOS window integration
- **Font Rendering**: Existing text rendering pipeline

## Browser Naming Rationale

**GrainView** follows the Grain product naming convention:
- **Grain**: Core brand identity
- **View**: Represents the browser's primary function (viewing web content)
- **Consistency**: Matches other Grain products (Grain Aurora, Grain Basin, Grain VM)

Alternative names considered:
- GrainFlow (emphasizes data flow)
- GrainSurf (playful, but less professional)
- GrainBrowser (too generic)
- GrainStream (implies streaming, not general browsing)

## Development Roadmap

1. **QEMU Setup**: Get Grain Basin Kernel running in QEMU
2. **Network Stack**: Implement basic TCP/IP in kernel
3. **HTML Parser**: Start with minimal HTML subset
4. **Rendering**: Basic text and block layout
5. **Integration**: Connect to Grain Aurora UI
6. **Testing**: Load simple web pages
7. **Iteration**: Expand feature set incrementally

## References

- **Grain OS Architecture**: `docs/tahoe_architecture.md`
- **Grain Style Guide**: `docs/zyx/grain_style.md`
- **Grain VM JIT**: `docs/jit_architecture.md`
- **QEMU RISC-V**: https://www.qemu.org/docs/master/system/target-riscv.html

