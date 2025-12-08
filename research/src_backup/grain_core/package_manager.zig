//! Grain OS Package Manager: Software package management.
//!
//! Why: Provide package management for software installation and removal.
//! Architecture: Package installation, removal, dependency management.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max packages.
pub const MAX_PACKAGES: u32 = 256;

// Bounded: Max package name length.
pub const MAX_PACKAGE_NAME_LEN: u32 = 128;

// Bounded: Max package version length.
pub const MAX_PACKAGE_VERSION_LEN: u32 = 32;

// Bounded: Max package description length.
pub const MAX_PACKAGE_DESC_LEN: u32 = 256;

// Bounded: Max dependencies per package.
pub const MAX_DEPENDENCIES: u32 = 16;

// Package state.
pub const PackageState = enum(u8) {
    not_installed,
    installing,
    installed,
    removing,
    failed,
};

// Package: represents a software package.
pub const Package = struct {
    package_id: u32,
    name: [MAX_PACKAGE_NAME_LEN]u8,
    name_len: u32,
    version: [MAX_PACKAGE_VERSION_LEN]u8,
    version_len: u32,
    description: [MAX_PACKAGE_DESC_LEN]u8,
    description_len: u32,
    state: PackageState,
    size_bytes: u64,
    dependencies: [MAX_DEPENDENCIES]u32, // Package IDs.
    dependencies_len: u32,
    installed_timestamp: u64,
    active: bool,

    pub fn init() Package {
        var pkg = Package{
            .package_id = 0,
            .name = undefined,
            .name_len = 0,
            .version = undefined,
            .version_len = 0,
            .description = undefined,
            .description_len = 0,
            .state = PackageState.not_installed,
            .size_bytes = 0,
            .dependencies = undefined,
            .dependencies_len = 0,
            .installed_timestamp = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_PACKAGE_NAME_LEN) : (i += 1) {
            pkg.name[i] = 0;
        }
        i = 0;
        while (i < MAX_PACKAGE_VERSION_LEN) : (i += 1) {
            pkg.version[i] = 0;
        }
        i = 0;
        while (i < MAX_PACKAGE_DESC_LEN) : (i += 1) {
            pkg.description[i] = 0;
        }
        i = 0;
        while (i < MAX_DEPENDENCIES) : (i += 1) {
            pkg.dependencies[i] = 0;
        }
        return pkg;
    }
};

// Package manager: manages software packages.
pub const PackageManager = struct {
    packages: [MAX_PACKAGES]Package,
    packages_len: u32,
    next_package_id: u32,

    pub fn init() PackageManager {
        var manager = PackageManager{
            .packages = undefined,
            .packages_len = 0,
            .next_package_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_PACKAGES) : (i += 1) {
            manager.packages[i] = Package.init();
        }
        return manager;
    }

    // Add package.
    pub fn add_package(
        self: *PackageManager,
        name: []const u8,
        version: []const u8,
        description: []const u8,
        size_bytes: u64,
    ) ?u32 {
        if (self.packages_len >= MAX_PACKAGES) {
            return null;
        }
        if (name.len > MAX_PACKAGE_NAME_LEN) {
            return null;
        }
        if (version.len > MAX_PACKAGE_VERSION_LEN) {
            return null;
        }
        if (description.len > MAX_PACKAGE_DESC_LEN) {
            return null;
        }
        const package_id = self.next_package_id;
        self.next_package_id += 1;
        self.packages[self.packages_len] = Package.init();
        self.packages[self.packages_len].package_id = package_id;
        self.packages[self.packages_len].state = PackageState.not_installed;
        self.packages[self.packages_len].size_bytes = size_bytes;
        self.packages[self.packages_len].active = true;
        var i: u32 = 0;
        while (i < MAX_PACKAGE_NAME_LEN) : (i += 1) {
            self.packages[self.packages_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_PACKAGE_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.packages[self.packages_len].name[i] = name[i];
        }
        self.packages[self.packages_len].name_len = @intCast(name_len);
        i = 0;
        while (i < MAX_PACKAGE_VERSION_LEN) : (i += 1) {
            self.packages[self.packages_len].version[i] = 0;
        }
        const version_len = @min(version.len, MAX_PACKAGE_VERSION_LEN);
        i = 0;
        while (i < version_len) : (i += 1) {
            self.packages[self.packages_len].version[i] = version[i];
        }
        self.packages[self.packages_len].version_len = @intCast(version_len);
        i = 0;
        while (i < MAX_PACKAGE_DESC_LEN) : (i += 1) {
            self.packages[self.packages_len].description[i] = 0;
        }
        const desc_len = @min(description.len, MAX_PACKAGE_DESC_LEN);
        i = 0;
        while (i < desc_len) : (i += 1) {
            self.packages[self.packages_len].description[i] = description[i];
        }
        self.packages[self.packages_len].description_len = @intCast(desc_len);
        self.packages_len += 1;
        return package_id;
    }

    // Find package by ID.
    pub fn find_package(
        self: *PackageManager,
        package_id: u32,
    ) ?*Package {
        std.debug.assert(package_id > 0);
        var i: u32 = 0;
        while (i < self.packages_len) : (i += 1) {
            if (self.packages[i].package_id == package_id and self.packages[i].active) {
                return &self.packages[i];
            }
        }
        return null;
    }

    // Install package.
    pub fn install_package(self: *PackageManager, package_id: u32, timestamp: u64) bool {
        std.debug.assert(package_id > 0);
        if (self.find_package(package_id)) |pkg| {
            if (pkg.state == PackageState.not_installed) {
                pkg.state = PackageState.installing;
                // Would install actual package in full implementation.
                pkg.state = PackageState.installed;
                pkg.installed_timestamp = timestamp;
                return true;
            }
        }
        return false;
    }

    // Remove package.
    pub fn remove_package(self: *PackageManager, package_id: u32) bool {
        std.debug.assert(package_id > 0);
        if (self.find_package(package_id)) |pkg| {
            if (pkg.state == PackageState.installed) {
                pkg.state = PackageState.removing;
                // Would remove actual package in full implementation.
                pkg.state = PackageState.not_installed;
                pkg.installed_timestamp = 0;
                return true;
            }
        }
        return false;
    }

    // Add dependency.
    pub fn add_dependency(
        self: *PackageManager,
        package_id: u32,
        dependency_id: u32,
    ) bool {
        std.debug.assert(package_id > 0);
        std.debug.assert(dependency_id > 0);
        if (self.find_package(package_id)) |pkg| {
            if (pkg.dependencies_len >= MAX_DEPENDENCIES) {
                return false;
            }
            var i: u32 = 0;
            while (i < pkg.dependencies_len) : (i += 1) {
                if (pkg.dependencies[i] == dependency_id) {
                    return false; // Already a dependency.
                }
            }
            pkg.dependencies[pkg.dependencies_len] = dependency_id;
            pkg.dependencies_len += 1;
            return true;
        }
        return false;
    }

    // Remove dependency.
    pub fn remove_dependency(
        self: *PackageManager,
        package_id: u32,
        dependency_id: u32,
    ) bool {
        std.debug.assert(package_id > 0);
        std.debug.assert(dependency_id > 0);
        if (self.find_package(package_id)) |pkg| {
            var i: u32 = 0;
            var found: bool = false;
            while (i < pkg.dependencies_len) : (i += 1) {
                if (pkg.dependencies[i] == dependency_id) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                return false;
            }
            while (i < pkg.dependencies_len - 1) : (i += 1) {
                pkg.dependencies[i] = pkg.dependencies[i + 1];
            }
            pkg.dependencies_len -= 1;
            return true;
        }
        return false;
    }

    // Remove package entry.
    pub fn remove_package_entry(self: *PackageManager, package_id: u32) bool {
        std.debug.assert(package_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.packages_len) : (i += 1) {
            if (self.packages[i].package_id == package_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        while (i < self.packages_len - 1) : (i += 1) {
            self.packages[i] = self.packages[i + 1];
        }
        self.packages_len -= 1;
        return true;
    }

    // Get package count.
    pub fn get_package_count(self: *const PackageManager) u32 {
        return self.packages_len;
    }

    // Get installed package count.
    pub fn get_installed_package_count(self: *const PackageManager) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.packages_len) : (i += 1) {
            if (self.packages[i].state == PackageState.installed) {
                count += 1;
            }
        }
        return count;
    }
};

