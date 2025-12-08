# Struct Definitions Index

This directory provides a central reference for all struct definitions in the Aurora codebase.

## Purpose

`index.zig` re-exports all struct definitions from their implementation files, allowing you to view all structs in one place for documentation and review purposes.

## Usage

To view all struct definitions, read `src/structs/index.zig`. This file is not meant to be imported or compiled standalone—it's a reference document.

Structs remain in their implementation files for tight coupling with their functionality, following TigerStyle principles of keeping abstractions minimal and well-placed.

## Organization

Structs are organized by domain:
- **Platform**: Window abstractions (macOS, RISC-V, null)
- **Aurora**: UI component tree and rendering
- **LSP**: Language Server Protocol client
- **Crash**: Panic handling and error logging
- **Editor**: Code editor integration

