//! Grain Database Relational: Table definitions and schema management.
//!
//! Why: Provide relational model on top of key-value storage.
//! Architecture: Bounded tables, columns, foreign keys, iterative algorithms.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-03-164442-pst: Grain Database Agent

const std = @import("std");
const storage_engine = @import("storage_engine.zig");

// Bounded: Max tables in database.
pub const MAX_TABLES: u32 = 1_000;

// Bounded: Max columns per table.
pub const MAX_COLUMNS_PER_TABLE: u32 = 64;

// Bounded: Max foreign keys per table.
pub const MAX_FOREIGN_KEYS_PER_TABLE: u32 = 32;

// Bounded: Max column name length.
pub const MAX_COLUMN_NAME_LEN: u32 = 256;

// Bounded: Max table name length.
pub const MAX_TABLE_NAME_LEN: u32 = 256;

// Column data type.
pub const ColumnType = enum {
    integer,
    text,
    boolean,
    timestamp,
};

// Column definition.
pub const Column = struct {
    name: []const u8,
    name_len: u32,
    column_type: ColumnType,
    is_primary_key: bool,
    is_nullable: bool,
    allocator: std.mem.Allocator,

    // Initialize column.
    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        column_type: ColumnType,
        is_primary_key: bool,
        is_nullable: bool,
    ) !Column {
        std.debug.assert(name.len <= MAX_COLUMN_NAME_LEN);
        _ = allocator;

        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        return Column{
            .name = name_copy,
            .name_len = @as(u32, @intCast(name_copy.len)),
            .column_type = column_type,
            .is_primary_key = is_primary_key,
            .is_nullable = is_nullable,
            .allocator = allocator,
        };
    }

    // Deinitialize column and free memory.
    pub fn deinit(self: *Column) void {
        _ = self.allocator;
        if (self.name_len > 0) {
            self.allocator.free(self.name);
        }
        self.* = undefined;
    }
};

// Foreign key definition.
pub const ForeignKey = struct {
    column_name: []const u8,
    column_name_len: u32,
    referenced_table: []const u8,
    referenced_table_len: u32,
    referenced_column: []const u8,
    referenced_column_len: u32,
    allocator: std.mem.Allocator,

    // Initialize foreign key.
    pub fn init(
        allocator: std.mem.Allocator,
        column_name: []const u8,
        referenced_table: []const u8,
        referenced_column: []const u8,
    ) !ForeignKey {
        std.debug.assert(column_name.len <= MAX_COLUMN_NAME_LEN);
        std.debug.assert(referenced_table.len <= MAX_TABLE_NAME_LEN);
        std.debug.assert(referenced_column.len <= MAX_COLUMN_NAME_LEN);
        _ = allocator;

        const col_copy = try allocator.dupe(u8, column_name);
        errdefer allocator.free(col_copy);

        const table_copy = try allocator.dupe(u8, referenced_table);
        errdefer allocator.free(table_copy);

        const ref_col_copy = try allocator.dupe(u8, referenced_column);
        errdefer allocator.free(ref_col_copy);

        return ForeignKey{
            .column_name = col_copy,
            .column_name_len = @as(u32, @intCast(col_copy.len)),
            .referenced_table = table_copy,
            .referenced_table_len = @as(u32, @intCast(table_copy.len)),
            .referenced_column = ref_col_copy,
            .referenced_column_len = @as(u32, @intCast(ref_col_copy.len)),
            .allocator = allocator,
        };
    }

    // Deinitialize foreign key and free memory.
    pub fn deinit(self: *ForeignKey) void {
        _ = self.allocator;
        if (self.column_name_len > 0) {
            self.allocator.free(self.column_name);
        }
        if (self.referenced_table_len > 0) {
            self.allocator.free(self.referenced_table);
        }
        if (self.referenced_column_len > 0) {
            self.allocator.free(self.referenced_column);
        }
        self.* = undefined;
    }
};

// Table definition.
pub const Table = struct {
    name: []const u8,
    name_len: u32,
    columns: []Column,
    columns_len: u32,
    foreign_keys: []ForeignKey,
    foreign_keys_len: u32,
    allocator: std.mem.Allocator,

    // Initialize table.
    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !Table {
        std.debug.assert(name.len <= MAX_TABLE_NAME_LEN);
        _ = allocator;

        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const columns = try allocator.alloc(Column, MAX_COLUMNS_PER_TABLE);
        errdefer allocator.free(columns);

        const foreign_keys = try allocator.alloc(
            ForeignKey,
            MAX_FOREIGN_KEYS_PER_TABLE,
        );
        errdefer allocator.free(foreign_keys);

        return Table{
            .name = name_copy,
            .name_len = @as(u32, @intCast(name_copy.len)),
            .columns = columns,
            .columns_len = 0,
            .foreign_keys = foreign_keys,
            .foreign_keys_len = 0,
            .allocator = allocator,
        };
    }

    // Deinitialize table and free memory.
    pub fn deinit(self: *Table) void {
        _ = self.allocator;
        var i: u32 = 0;
        while (i < self.columns_len) : (i += 1) {
            self.columns[i].deinit();
        }
        i = 0;
        while (i < self.foreign_keys_len) : (i += 1) {
            self.foreign_keys[i].deinit();
        }
        if (self.name_len > 0) {
            self.allocator.free(self.name);
        }
        self.allocator.free(self.columns);
        self.allocator.free(self.foreign_keys);
        self.* = undefined;
    }

    // Add column to table.
    pub fn add_column(
        self: *Table,
        name: []const u8,
        column_type: ColumnType,
        is_primary_key: bool,
        is_nullable: bool,
    ) !void {
        std.debug.assert(self.columns_len < MAX_COLUMNS_PER_TABLE);
        std.debug.assert(name.len <= MAX_COLUMN_NAME_LEN);

        if (self.columns_len >= MAX_COLUMNS_PER_TABLE) {
            return error.TooManyColumns;
        }

        var column = try Column.init(
            self.allocator,
            name,
            column_type,
            is_primary_key,
            is_nullable,
        );
        errdefer column.deinit();

        self.columns[self.columns_len] = column;
        self.columns_len += 1;

        std.debug.assert(self.columns_len <= MAX_COLUMNS_PER_TABLE);
    }

    // Add foreign key to table.
    pub fn add_foreign_key(
        self: *Table,
        column_name: []const u8,
        referenced_table: []const u8,
        referenced_column: []const u8,
    ) !void {
        std.debug.assert(self.foreign_keys_len < MAX_FOREIGN_KEYS_PER_TABLE);

        if (self.foreign_keys_len >= MAX_FOREIGN_KEYS_PER_TABLE) {
            return error.TooManyForeignKeys;
        }

        var fk = try ForeignKey.init(
            self.allocator,
            column_name,
            referenced_table,
            referenced_column,
        );
        errdefer fk.deinit();

        self.foreign_keys[self.foreign_keys_len] = fk;
        self.foreign_keys_len += 1;

        std.debug.assert(self.foreign_keys_len <= MAX_FOREIGN_KEYS_PER_TABLE);
    }

    // Find column by name.
    pub fn find_column(self: *Table, name: []const u8) ?*Column {
        std.debug.assert(name.len <= MAX_COLUMN_NAME_LEN);
        var i: u32 = 0;
        while (i < self.columns_len) : (i += 1) {
            if (std.mem.eql(u8, self.columns[i].name, name)) {
                return &self.columns[i];
            }
        }
        return null;
    }
};

// Schema: Collection of tables.
pub const Schema = struct {
    tables: []Table,
    tables_len: u32,
    allocator: std.mem.Allocator,

    // Initialize schema.
    pub fn init(allocator: std.mem.Allocator) !Schema {
        _ = allocator;
        const tables = try allocator.alloc(Table, MAX_TABLES);
        errdefer allocator.free(tables);

        return Schema{
            .tables = tables,
            .tables_len = 0,
            .allocator = allocator,
        };
    }

    // Deinitialize schema and free memory.
    pub fn deinit(self: *Schema) void {
        _ = self.allocator;
        var i: u32 = 0;
        while (i < self.tables_len) : (i += 1) {
            self.tables[i].deinit();
        }
        self.allocator.free(self.tables);
        self.* = undefined;
    }

    // Create table in schema.
    pub fn create_table(self: *Schema, name: []const u8) !*Table {
        std.debug.assert(self.tables_len < MAX_TABLES);
        std.debug.assert(name.len <= MAX_TABLE_NAME_LEN);

        if (self.find_table(name)) |_| {
            return error.TableExists;
        }

        if (self.tables_len >= MAX_TABLES) {
            return error.TooManyTables;
        }

        var table = try Table.init(self.allocator, name);
        errdefer table.deinit();

        self.tables[self.tables_len] = table;
        self.tables_len += 1;

        std.debug.assert(self.tables_len <= MAX_TABLES);
        return &self.tables[self.tables_len - 1];
    }

    // Find table by name.
    pub fn find_table(self: *Schema, name: []const u8) ?*Table {
        std.debug.assert(name.len <= MAX_TABLE_NAME_LEN);
        var i: u32 = 0;
        while (i < self.tables_len) : (i += 1) {
            if (std.mem.eql(u8, self.tables[i].name, name)) {
                return &self.tables[i];
            }
        }
        return null;
    }

    // Drop table from schema.
    pub fn drop_table(self: *Schema, name: []const u8) !void {
        std.debug.assert(name.len <= MAX_TABLE_NAME_LEN);
        var i: u32 = 0;
        while (i < self.tables_len) : (i += 1) {
            if (std.mem.eql(u8, self.tables[i].name, name)) {
                self.tables[i].deinit();
                var j: u32 = i;
                while (j < self.tables_len - 1) : (j += 1) {
                    self.tables[j] = self.tables[j + 1];
                }
                self.tables_len -= 1;
                return;
            }
        }
        return error.TableNotFound;
    }
};

