//! Grain Package Manager UI: Graphical package management.
//!
//! Why: Provide GUI for package installation and management.
//! Architecture: Package browsing, installation, dependency visualization.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-173505-pst: Active implementation
//! 2025-12-07-060853-pst: Phase 12 HTTP Client integration for repository access

const std = @import("std");
const grain_core = @import("grain_core");

// Bounded: Max search results (explicit limit)
// 2025-12-03-173505-pst: Active constant
pub const MAX_SEARCH_RESULTS: u32 = 256;

// Bounded: Max categories (explicit limit)
// 2025-12-03-173505-pst: Active constant
pub const MAX_CATEGORIES: u32 = 32;

// Bounded: Max category name length (explicit limit, in bytes)
// 2025-12-03-173505-pst: Active constant
pub const MAX_CATEGORY_NAME_LEN: u32 = 64;

// Bounded: Max package name length (explicit limit, in bytes)
// 2025-12-03-173505-pst: Active constant (matches package_manager)
pub const MAX_PACKAGE_NAME_LEN: u32 = 128;

// Bounded: Max repository URLs (explicit limit)
// 2025-12-07-060853-pst: Phase 12 HTTP Client integration
pub const MAX_REPOSITORY_URLS: u32 = 16;

// Package category enumeration.
// 2025-12-03-173505-pst: Active enum
pub const PackageCategory = enum(u8) {
    all, // All packages
    system, // System packages
    development, // Development tools
    utilities, // Utility programs
    multimedia, // Multimedia applications
    network, // Network tools
    other, // Other packages
};

// Package info structure for UI.
// 2025-12-03-173505-pst: Active struct
pub const PackageInfo = struct {
    package_id: u32,
    name: []const u8,
    name_len: u32,
    version: []const u8,
    version_len: u32,
    description: []const u8,
    description_len: u32,
    state: grain_core.package_manager.PackageState,
    size_bytes: u64,
    category: PackageCategory,
};

// Dependency node for visualization.
// 2025-12-03-173505-pst: Active struct
pub const DependencyNode = struct {
    package_id: u32,
    level: u32, // Depth in dependency tree
};

// Repository URL structure.
// 2025-12-07-060853-pst: Phase 12 HTTP Client integration
pub const RepositoryUrl = struct {
    url: [grain_core.http_client.MAX_URL_LEN]u8,
    url_len: u32,
    active: bool,
};

// Package Manager UI application state.
// 2025-12-03-173505-pst: Active struct
// 2025-12-07-060853-pst: Phase 12 HTTP Client integration
pub const PackageManagerUI = struct {
    package_manager: *grain_core.package_manager.PackageManager,
    http_client: *grain_core.http_client.HttpClient,
    search_query: [MAX_PACKAGE_NAME_LEN]u8,
    search_query_len: u32,
    selected_category: PackageCategory,
    selected_package_id: u32,
    repository_urls: [MAX_REPOSITORY_URLS]?RepositoryUrl,
    repository_urls_len: u32,
    allocator: std.mem.Allocator,

    /// Initialize package manager UI.
    // 2025-12-03-173505-pst: Active function
    // 2025-12-07-060853-pst: Phase 12 HTTP Client integration
    pub fn init(
        allocator: std.mem.Allocator,
        pkg_mgr: *grain_core.package_manager.PackageManager,
        http_cli: *grain_core.http_client.HttpClient,
    ) PackageManagerUI {
        // Precondition: Allocator and managers must be valid
        std.debug.assert(allocator.ptr != null);
        std.debug.assert(@intFromPtr(pkg_mgr) != 0);
        std.debug.assert(@intFromPtr(http_cli) != 0);

        var ui = PackageManagerUI{
            .package_manager = pkg_mgr,
            .http_client = http_cli,
            .search_query = undefined,
            .search_query_len = 0,
            .selected_category = .all,
            .selected_package_id = 0,
            .repository_urls = undefined,
            .repository_urls_len = 0,
            .allocator = allocator,
        };

        // Initialize search query
        @memset(&ui.search_query, 0);

        // Initialize repository URLs array
        var i: u32 = 0;
        while (i < MAX_REPOSITORY_URLS) : (i += 1) {
            ui.repository_urls[i] = null;
        }

        // Postcondition: UI must be valid
        std.debug.assert(ui.search_query_len == 0);
        std.debug.assert(ui.repository_urls_len == 0);

        return ui;
    }

    /// Set search query.
    // 2025-12-03-173505-pst: Active function
    pub fn set_search_query(
        self: *PackageManagerUI,
        query: []const u8,
    ) void {
        // Precondition: Query must be bounded
        std.debug.assert(query.len <= MAX_PACKAGE_NAME_LEN);

        @memset(&self.search_query, 0);
        const query_len = @min(query.len, MAX_PACKAGE_NAME_LEN);
        if (query_len > 0) {
            @memcpy(self.search_query[0..query_len], query[0..query_len]);
        }
        self.search_query_len = @as(u32, @intCast(query_len));

        // Postcondition: Query must be valid
        std.debug.assert(self.search_query_len <= MAX_PACKAGE_NAME_LEN);
    }

    /// Set selected category.
    // 2025-12-03-173505-pst: Active function
    pub fn set_category(
        self: *PackageManagerUI,
        category: PackageCategory,
    ) void {
        // Precondition: Category must be valid
        std.debug.assert(@intFromEnum(category) >= 0);

        self.selected_category = category;

        // Postcondition: Category must be set
        std.debug.assert(self.selected_category == category);
    }

    /// Search packages by name or description.
    // 2025-12-03-173505-pst: Active function
    pub fn search_packages(
        self: *const PackageManagerUI,
        results: []u32,
        results_len: *u32,
    ) void {
        // Precondition: Results buffer must be valid
        std.debug.assert(results.len > 0);
        std.debug.assert(results_len != null);

        results_len.* = 0;

        if (self.search_query_len == 0) {
            return;
        }

        const query_slice = self.search_query[0..self.search_query_len];
        var i: u32 = 0;
        while (i < self.package_manager.packages_len and results_len.* < results.len) : (i += 1) {
            const pkg = &self.package_manager.packages[i];
            if (!pkg.active) {
                continue;
            }

            // Filter by category
            if (self.selected_category != .all) {
                const pkg_category = categorize_package(pkg);
                if (pkg_category != self.selected_category) {
                    continue;
                }
            }

            // Search in name
            const name_slice = pkg.name[0..pkg.name_len];
            if (std.mem.indexOf(u8, name_slice, query_slice) != null) {
                results[results_len.*] = pkg.package_id;
                results_len.* += 1;
                continue;
            }

            // Search in description
            const desc_slice = pkg.description[0..pkg.description_len];
            if (std.mem.indexOf(u8, desc_slice, query_slice) != null) {
                results[results_len.*] = pkg.package_id;
                results_len.* += 1;
            }
        }
    }

    /// Get all packages (filtered by category).
    // 2025-12-03-173505-pst: Active function
    pub fn get_packages(
        self: *const PackageManagerUI,
        packages: []PackageInfo,
        packages_len: *u32,
    ) void {
        // Precondition: Packages buffer must be valid
        std.debug.assert(packages.len > 0);
        std.debug.assert(packages_len != null);

        packages_len.* = 0;

        var i: u32 = 0;
        while (i < self.package_manager.packages_len and packages_len.* < packages.len) : (i += 1) {
            const pkg = &self.package_manager.packages[i];
            if (!pkg.active) {
                continue;
            }

            // Filter by category
            if (self.selected_category != .all) {
                const pkg_category = categorize_package(pkg);
                if (pkg_category != self.selected_category) {
                    continue;
                }
            }

            packages[packages_len.*] = PackageInfo{
                .package_id = pkg.package_id,
                .name = &pkg.name,
                .name_len = pkg.name_len,
                .version = &pkg.version,
                .version_len = pkg.version_len,
                .description = &pkg.description,
                .description_len = pkg.description_len,
                .state = pkg.state,
                .size_bytes = pkg.size_bytes,
                .category = categorize_package(pkg),
            };
            packages_len.* += 1;
        }
    }

    /// Get package information.
    // 2025-12-03-173505-pst: Active function
    pub fn get_package_info(
        self: *const PackageManagerUI,
        package_id: u32,
        info: *PackageInfo,
    ) bool {
        // Precondition: Package ID and info must be valid
        std.debug.assert(package_id > 0);
        std.debug.assert(@intFromPtr(info) != 0);

        var i: u32 = 0;
        while (i < self.package_manager.packages_len) : (i += 1) {
            const pkg = &self.package_manager.packages[i];
            if (pkg.package_id == package_id and pkg.active) {
                info.package_id = pkg.package_id;
                info.name = &pkg.name;
                info.name_len = pkg.name_len;
                info.version = &pkg.version;
                info.version_len = pkg.version_len;
                info.description = &pkg.description;
                info.description_len = pkg.description_len;
                info.state = pkg.state;
                info.size_bytes = pkg.size_bytes;
                info.category = categorize_package(pkg);

                // Postcondition: Info must be valid
                std.debug.assert(info.package_id == package_id);

                return true;
            }
        }

        return false;
    }

    /// Install package.
    // 2025-12-03-173505-pst: Active function
    pub fn install_package(
        self: *PackageManagerUI,
        package_id: u32,
    ) !void {
        // Precondition: Package ID must be valid
        std.debug.assert(package_id > 0);

        const timestamp = @as(u64, @intCast(std.time.timestamp()));
        const result = self.package_manager.install_package(package_id, timestamp);
        if (!result) {
            return error.InstallFailed;
        }
    }

    /// Remove package.
    // 2025-12-03-173505-pst: Active function
    pub fn remove_package(
        self: *PackageManagerUI,
        package_id: u32,
    ) !void {
        // Precondition: Package ID must be valid
        std.debug.assert(package_id > 0);

        const result = self.package_manager.remove_package(package_id);
        if (!result) {
            return error.RemoveFailed;
        }
    }

    /// Get package dependencies.
    // 2025-12-03-173505-pst: Active function
    pub fn get_package_dependencies(
        self: *const PackageManagerUI,
        package_id: u32,
        dependencies: []u32,
        dependencies_len: *u32,
    ) bool {
        // Precondition: Dependencies buffer must be valid
        std.debug.assert(package_id > 0);
        std.debug.assert(dependencies.len > 0);
        std.debug.assert(dependencies_len != null);

        dependencies_len.* = 0;

        var i: u32 = 0;
        while (i < self.package_manager.packages_len) : (i += 1) {
            const pkg = &self.package_manager.packages[i];
            if (pkg.package_id == package_id and pkg.active) {
                var j: u32 = 0;
                while (j < pkg.dependencies_len and dependencies_len.* < dependencies.len) : (j += 1) {
                    dependencies[dependencies_len.*] = pkg.dependencies[j];
                    dependencies_len.* += 1;
                }
                return true;
            }
        }

        return false;
    }

    /// Build dependency graph (breadth-first traversal).
    // 2025-12-03-173505-pst: Active function
    pub fn build_dependency_graph(
        self: *const PackageManagerUI,
        package_id: u32,
        nodes: []DependencyNode,
        nodes_len: *u32,
    ) void {
        // Precondition: Nodes buffer must be valid
        std.debug.assert(package_id > 0);
        std.debug.assert(nodes.len > 0);
        std.debug.assert(nodes_len != null);

        nodes_len.* = 0;

        // Add root node
        if (nodes_len.* < nodes.len) {
            nodes[nodes_len.*] = DependencyNode{
                .package_id = package_id,
                .level = 0,
            };
            nodes_len.* += 1;
        }

        // BFS traversal using stack
        var visited: [MAX_SEARCH_RESULTS]bool = undefined;
        @memset(&visited, false);
        var queue: [MAX_SEARCH_RESULTS]u32 = undefined;
        var queue_len: u32 = 1;
        queue[0] = package_id;
        visited[0] = true; // Simple visited tracking

        var level: u32 = 0;
        while (queue_len > 0 and nodes_len.* < nodes.len) {
            level += 1;
            const current_level_size = queue_len;
            var processed: u32 = 0;

            while (processed < current_level_size and nodes_len.* < nodes.len) {
                queue_len -= 1;
                const current_id = queue[queue_len];
                processed += 1;

                // Get dependencies
                var deps: [16]u32 = undefined;
                var deps_len: u32 = 0;
                if (self.get_package_dependencies(current_id, &deps, &deps_len)) {
                    var k: u32 = 0;
                    while (k < deps_len and queue_len < queue.len and nodes_len.* < nodes.len) : (k += 1) {
                        const dep_id = deps[k];
                        if (dep_id > 0 and dep_id < visited.len) {
                            if (!visited[dep_id]) {
                                visited[dep_id] = true;
                                queue[queue_len] = dep_id;
                                queue_len += 1;

                                nodes[nodes_len.*] = DependencyNode{
                                    .package_id = dep_id,
                                    .level = level,
                                };
                                nodes_len.* += 1;
                            }
                        }
                    }
                }
            }
        }
    }
};

// Categorize package (internal helper).
// 2025-12-03-173505-pst: Active function
fn categorize_package(
    pkg: *const grain_core.package_manager.Package,
) PackageCategory {
    // Precondition: Package must be valid
    std.debug.assert(pkg.package_id > 0);

    const name_slice = pkg.name[0..pkg.name_len];
    if (std.mem.indexOf(u8, name_slice, "kernel") != null or std.mem.indexOf(u8, name_slice, "os") != null) {
        return .system;
    }
    if (std.mem.indexOf(u8, name_slice, "dev") != null or std.mem.indexOf(u8, name_slice, "tool") != null) {
        return .development;
    }
    if (std.mem.indexOf(u8, name_slice, "util") != null or std.mem.indexOf(u8, name_slice, "cmd") != null) {
        return .utilities;
    }
    if (std.mem.indexOf(u8, name_slice, "media") != null or std.mem.indexOf(u8, name_slice, "audio") != null) {
        return .multimedia;
    }
    if (std.mem.indexOf(u8, name_slice, "net") != null or std.mem.indexOf(u8, name_slice, "http") != null) {
        return .network;
    }

    return .other;
}

// Package Manager UI HTTP Client functions.
// 2025-12-07-060853-pst: Phase 12 HTTP Client integration

/// Add repository URL.
// 2025-12-07-060853-pst: Phase 12 HTTP Client integration
pub fn add_repository_url(
    self: *PackageManagerUI,
    url: []const u8,
) bool {
    // Precondition: URL must be valid
    std.debug.assert(url.len > 0);
    std.debug.assert(url.len <= grain_core.http_client.MAX_URL_LEN);
    std.debug.assert(self.repository_urls_len < MAX_REPOSITORY_URLS);

    if (self.repository_urls_len >= MAX_REPOSITORY_URLS) {
        return false;
    }

    var repo_url = RepositoryUrl{
        .url = undefined,
        .url_len = @as(u32, @intCast(url.len)),
        .active = true,
    };

    @memset(&repo_url.url, 0);
    const url_len = @min(url.len, grain_core.http_client.MAX_URL_LEN);
    @memcpy(repo_url.url[0..url_len], url[0..url_len]);

    var i: u32 = 0;
    while (i < MAX_REPOSITORY_URLS) : (i += 1) {
        if (self.repository_urls[i] == null) {
            self.repository_urls[i] = repo_url;
            self.repository_urls_len += 1;
            break;
        }
    }

    // Postcondition: Repository URL must be added
    std.debug.assert(self.repository_urls_len > 0);

    return true;
}

/// Fetch package list from repository.
// 2025-12-07-060853-pst: Phase 12 HTTP Client integration
pub fn fetch_packages_from_repository(
    self: *PackageManagerUI,
    repository_index: u32,
) ?u32 {
    // Precondition: Repository index must be valid
    std.debug.assert(repository_index < MAX_REPOSITORY_URLS);
    std.debug.assert(self.repository_urls_len > 0);

    if (repository_index >= self.repository_urls_len) {
        return null;
    }

    const repo = self.repository_urls[repository_index];
    if (repo == null or !repo.?.active) {
        return null;
    }

    const url_slice = repo.?.url[0..repo.?.url_len];
    const request = self.http_client.create_request(.get, url_slice);
    if (request == null) {
        return null;
    }

    // Return request ID for tracking
    return request.?.request_id;
}

/// Get repository URLs.
// 2025-12-07-060853-pst: Phase 12 HTTP Client integration
pub fn get_repository_urls(
    self: *const PackageManagerUI,
    urls: []?*const RepositoryUrl,
    urls_len: *u32,
) void {
    // Precondition: URLs buffer must be valid
    std.debug.assert(urls.len > 0);
    std.debug.assert(urls_len != null);

    urls_len.* = 0;

    var i: u32 = 0;
    while (i < self.repository_urls_len and urls_len.* < urls.len) : (i += 1) {
        if (self.repository_urls[i]) |*repo| {
            if (repo.active) {
                urls[urls_len.*] = repo;
                urls_len.* += 1;
            }
        }
    }
}

/// Remove repository URL.
// 2025-12-07-060853-pst: Phase 12 HTTP Client integration
pub fn remove_repository_url(
    self: *PackageManagerUI,
    repository_index: u32,
) bool {
    // Precondition: Repository index must be valid
    std.debug.assert(repository_index < MAX_REPOSITORY_URLS);

    if (repository_index >= self.repository_urls_len) {
        return false;
    }

    if (self.repository_urls[repository_index]) |*repo| {
        repo.active = false;
        self.repository_urls_len -= 1;
        return true;
    }

    return false;
}

