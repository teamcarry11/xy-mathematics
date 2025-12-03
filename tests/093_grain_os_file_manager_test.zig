//! Tests for Grain OS file management system.
//!
//! Why: Verify file management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const FileManager = grain_os.file_manager.FileManager;
const FileType = grain_os.file_manager.FileType;

test "file manager initialization" {
    const manager = FileManager.init();
    std.debug.assert(manager.files_len == 0);
    std.debug.assert(manager.next_entry_id == 1);
    const current_dir = manager.get_current_directory();
    std.debug.assert(std.mem.eql(u8, current_dir, "/"));
}

test "add file entry" {
    var manager = FileManager.init();
    const entry_id_opt = manager.add_file_entry("test.txt", "/test.txt", FileType.regular, 1024, 1000);
    std.debug.assert(entry_id_opt != null);
    if (entry_id_opt) |entry_id| {
        std.debug.assert(entry_id == 1);
        std.debug.assert(manager.get_file_count() == 1);
    }
}

test "find file entry by ID" {
    var manager = FileManager.init();
    if (manager.add_file_entry("test.txt", "/test.txt", FileType.regular, 1024, 1000)) |entry_id| {
        const entry_opt = manager.find_file_entry(entry_id);
        std.debug.assert(entry_opt != null);
        if (entry_opt) |entry| {
            std.debug.assert(entry.entry_id == entry_id);
            std.debug.assert(entry.file_type == FileType.regular);
            std.debug.assert(entry.size == 1024);
        }
    }
}

test "find file entry by path" {
    var manager = FileManager.init();
    _ = manager.add_file_entry("test.txt", "/test.txt", FileType.regular, 1024, 1000);
    const entry_opt = manager.find_file_entry_by_path("/test.txt");
    std.debug.assert(entry_opt != null);
    if (entry_opt) |entry| {
        const name_slice = entry.name[0..entry.name_len];
        std.debug.assert(std.mem.eql(u8, name_slice, "test.txt"));
    }
}

test "set current directory" {
    var manager = FileManager.init();
    const result = manager.set_current_directory("/home/user");
    std.debug.assert(result);
    const current_dir = manager.get_current_directory();
    std.debug.assert(std.mem.eql(u8, current_dir, "/home/user"));
}

test "remove file entry" {
    var manager = FileManager.init();
    if (manager.add_file_entry("test.txt", "/test.txt", FileType.regular, 1024, 1000)) |entry_id| {
        const result = manager.remove_file_entry(entry_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_file_count() == 0);
    }
}

test "clear all file entries" {
    var manager = FileManager.init();
    _ = manager.add_file_entry("test1.txt", "/test1.txt", FileType.regular, 1024, 1000);
    _ = manager.add_file_entry("test2.txt", "/test2.txt", FileType.regular, 2048, 2000);
    std.debug.assert(manager.get_file_count() == 2);
    manager.clear_all();
    std.debug.assert(manager.get_file_count() == 0);
}

test "compositor add file entry" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const entry_id_opt = comp.add_file_entry("test.txt", "/test.txt", FileType.regular, 1024, 1000);
    std.debug.assert(entry_id_opt != null);
}

test "compositor find file entry by path" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.add_file_entry("test.txt", "/test.txt", FileType.regular, 1024, 1000);
    const entry_opt = comp.find_file_entry_by_path("/test.txt");
    std.debug.assert(entry_opt != null);
}

test "compositor set current directory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const result = comp.set_current_directory("/home/user");
    std.debug.assert(result);
    const current_dir = comp.get_current_directory();
    std.debug.assert(std.mem.eql(u8, current_dir, "/home/user"));
}

test "compositor get file count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_file_count() == 0);
    _ = comp.add_file_entry("test.txt", "/test.txt", FileType.regular, 1024, 1000);
    std.debug.assert(comp.get_file_count() == 1);
}

test "file types" {
    std.debug.assert(@intFromEnum(FileType.unknown) == 0);
    std.debug.assert(@intFromEnum(FileType.regular) == 1);
    std.debug.assert(@intFromEnum(FileType.directory) == 2);
    std.debug.assert(@intFromEnum(FileType.symlink) == 3);
}

test "file manager constants" {
    std.debug.assert(grain_os.file_manager.MAX_FILES == 512);
    std.debug.assert(grain_os.file_manager.MAX_PATH_LEN == 512);
    std.debug.assert(grain_os.file_manager.MAX_NAME_LEN == 256);
}

