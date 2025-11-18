//! Debug script to inspect Hello World ELF structure
//! Why: Understand ELF segment addresses to debug loading issues.

const std = @import("std");

const Elf64_Ehdr = extern struct {
    e_ident: [16]u8,
    e_type: u16,
    e_machine: u16,
    e_version: u32,
    e_entry: u64,
    e_phoff: u64,
    e_shoff: u64,
    e_flags: u32,
    e_ehsize: u16,
    e_phentsize: u16,
    e_phnum: u16,
    e_shentsize: u16,
    e_shnum: u16,
    e_shstrndx: u16,
};

const Elf64_Phdr = extern struct {
    p_type: u32,
    p_flags: u32,
    p_offset: u64,
    p_vaddr: u64,
    p_paddr: u64,
    p_filesz: u64,
    p_memsz: u64,
    p_align: u64,
};

pub fn main() !void {
    const hello_world_path = "zig-out/bin/hello_world";
    const elf_data = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, hello_world_path, 10 * 1024 * 1024);
    defer std.heap.page_allocator.free(elf_data);

    const ehdr = @as(*const Elf64_Ehdr, @alignCast(@ptrCast(elf_data.ptr)));

    std.debug.print("ELF Header:\n", .{});
    std.debug.print("  Magic: {x:0>2} {x:0>2} {x:0>2} {x:0>2}\n", .{ ehdr.e_ident[0], ehdr.e_ident[1], ehdr.e_ident[2], ehdr.e_ident[3] });
    std.debug.print("  Class: {}\n", .{ehdr.e_ident[4]});
    std.debug.print("  Endian: {}\n", .{ehdr.e_ident[5]});
    std.debug.print("  Machine: {}\n", .{ehdr.e_machine});
    std.debug.print("  Type: {}\n", .{ehdr.e_type});
    std.debug.print("  Entry: 0x{x}\n", .{ehdr.e_entry});
    std.debug.print("  Program headers: {} at offset 0x{x}\n", .{ ehdr.e_phnum, ehdr.e_phoff });

    const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB
    std.debug.print("\nVM Memory Size: 0x{x} ({d} MB)\n", .{ VM_MEMORY_SIZE, VM_MEMORY_SIZE / (1024 * 1024) });

    const phdr_base = elf_data[@intCast(ehdr.e_phoff)..];
    var phdr_idx: u16 = 0;
    while (phdr_idx < ehdr.e_phnum) : (phdr_idx += 1) {
        const phdr_offset = phdr_idx * @sizeOf(Elf64_Phdr);
        const phdr = @as(*const Elf64_Phdr, @alignCast(@ptrCast(phdr_base.ptr + phdr_offset)));

        std.debug.print("\nProgram Header {}:\n", .{phdr_idx});
        std.debug.print("  Type: {}\n", .{phdr.p_type});
        std.debug.print("  Flags: 0x{x}\n", .{phdr.p_flags});
        std.debug.print("  Offset: 0x{x}\n", .{phdr.p_offset});
        std.debug.print("  VAddr: 0x{x}\n", .{phdr.p_vaddr});
        std.debug.print("  PAddr: 0x{x}\n", .{phdr.p_paddr});
        std.debug.print("  FileSz: 0x{x}\n", .{phdr.p_filesz});
        std.debug.print("  MemSz: 0x{x}\n", .{phdr.p_memsz});
        std.debug.print("  Align: 0x{x}\n", .{phdr.p_align});

        if (phdr.p_type == 1) {
            const segment_end = phdr.p_vaddr + phdr.p_memsz;
            const fits = segment_end <= VM_MEMORY_SIZE;
            std.debug.print("  Segment end: 0x{x}\n", .{segment_end});
            std.debug.print("  Fits in VM: {}\n", .{fits});
            if (!fits) {
                std.debug.print("  ERROR: Segment extends beyond VM memory!\n", .{});
            }
        }
    }

    if (ehdr.e_entry >= VM_MEMORY_SIZE) {
        std.debug.print("\nERROR: Entry point 0x{x} is outside VM memory!\n", .{ehdr.e_entry});
    } else {
        std.debug.print("\nEntry point 0x{x} is within VM memory.\n", .{ehdr.e_entry});
    }
}

