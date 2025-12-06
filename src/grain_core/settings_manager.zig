//! Grain OS Settings Manager: System settings and configuration management.
//!
//! Why: Provide centralized settings management for system configuration.
//! Architecture: Settings storage, categories, value types, persistence.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max settings.
pub const MAX_SETTINGS: u32 = 256;

// Bounded: Max setting key length.
pub const MAX_KEY_LEN: u32 = 64;

// Bounded: Max setting value length.
pub const MAX_VALUE_LEN: u32 = 256;

// Bounded: Max categories.
pub const MAX_CATEGORIES: u32 = 16;

// Bounded: Max category name length.
pub const MAX_CATEGORY_NAME_LEN: u32 = 32;

// Setting value type.
pub const SettingValueType = enum(u8) {
    string,
    integer,
    boolean,
    float,
};

// Setting: represents a system setting.
pub const Setting = struct {
    setting_id: u32,
    category_id: u32,
    key: [MAX_KEY_LEN]u8,
    key_len: u32,
    value_type: SettingValueType,
    value_string: [MAX_VALUE_LEN]u8,
    value_string_len: u32,
    value_integer: i64,
    value_boolean: bool,
    value_float: f64,
    active: bool,

    pub fn init() Setting {
        var setting = Setting{
            .setting_id = 0,
            .category_id = 0,
            .key = undefined,
            .key_len = 0,
            .value_type = SettingValueType.string,
            .value_string = undefined,
            .value_string_len = 0,
            .value_integer = 0,
            .value_boolean = false,
            .value_float = 0.0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_KEY_LEN) : (i += 1) {
            setting.key[i] = 0;
        }
        i = 0;
        while (i < MAX_VALUE_LEN) : (i += 1) {
            setting.value_string[i] = 0;
        }
        return setting;
    }
};

// Category: represents a settings category.
pub const Category = struct {
    category_id: u32,
    name: [MAX_CATEGORY_NAME_LEN]u8,
    name_len: u32,
    active: bool,

    pub fn init() Category {
        var category = Category{
            .category_id = 0,
            .name = undefined,
            .name_len = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_CATEGORY_NAME_LEN) : (i += 1) {
            category.name[i] = 0;
        }
        return category;
    }
};

// Settings manager: manages system settings.
pub const SettingsManager = struct {
    settings: [MAX_SETTINGS]Setting,
    settings_len: u32,
    categories: [MAX_CATEGORIES]Category,
    categories_len: u32,
    next_setting_id: u32,
    next_category_id: u32,

    pub fn init() SettingsManager {
        var manager = SettingsManager{
            .settings = undefined,
            .settings_len = 0,
            .categories = undefined,
            .categories_len = 0,
            .next_setting_id = 1,
            .next_category_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_SETTINGS) : (i += 1) {
            manager.settings[i] = Setting.init();
        }
        i = 0;
        while (i < MAX_CATEGORIES) : (i += 1) {
            manager.categories[i] = Category.init();
        }
        return manager;
    }

    // Add category.
    pub fn add_category(self: *SettingsManager, name: []const u8) ?u32 {
        if (self.categories_len >= MAX_CATEGORIES) {
            return null;
        }
        if (name.len > MAX_CATEGORY_NAME_LEN) {
            return null;
        }
        const category_id = self.next_category_id;
        self.next_category_id += 1;
        self.categories[self.categories_len] = Category.init();
        self.categories[self.categories_len].category_id = category_id;
        self.categories[self.categories_len].active = true;
        var i: u32 = 0;
        while (i < MAX_CATEGORY_NAME_LEN) : (i += 1) {
            self.categories[self.categories_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_CATEGORY_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.categories[self.categories_len].name[i] = name[i];
        }
        self.categories[self.categories_len].name_len = @intCast(name_len);
        self.categories_len += 1;
        return category_id;
    }

    // Find category by ID.
    pub fn find_category(
        self: *SettingsManager,
        category_id: u32,
    ) ?*Category {
        std.debug.assert(category_id > 0);
        var i: u32 = 0;
        while (i < self.categories_len) : (i += 1) {
            if (self.categories[i].category_id == category_id and self.categories[i].active) {
                return &self.categories[i];
            }
        }
        return null;
    }

    // Add setting.
    pub fn add_setting(
        self: *SettingsManager,
        category_id: u32,
        key: []const u8,
        value_type: SettingValueType,
    ) ?u32 {
        if (self.settings_len >= MAX_SETTINGS) {
            return null;
        }
        if (key.len > MAX_KEY_LEN) {
            return null;
        }
        if (self.find_category(category_id) == null) {
            return null;
        }
        const setting_id = self.next_setting_id;
        self.next_setting_id += 1;
        self.settings[self.settings_len] = Setting.init();
        self.settings[self.settings_len].setting_id = setting_id;
        self.settings[self.settings_len].category_id = category_id;
        self.settings[self.settings_len].value_type = value_type;
        self.settings[self.settings_len].active = true;
        var i: u32 = 0;
        while (i < MAX_KEY_LEN) : (i += 1) {
            self.settings[self.settings_len].key[i] = 0;
        }
        const key_len = @min(key.len, MAX_KEY_LEN);
        i = 0;
        while (i < key_len) : (i += 1) {
            self.settings[self.settings_len].key[i] = key[i];
        }
        self.settings[self.settings_len].key_len = @intCast(key_len);
        self.settings_len += 1;
        return setting_id;
    }

    // Find setting by ID.
    pub fn find_setting(
        self: *SettingsManager,
        setting_id: u32,
    ) ?*Setting {
        std.debug.assert(setting_id > 0);
        var i: u32 = 0;
        while (i < self.settings_len) : (i += 1) {
            if (self.settings[i].setting_id == setting_id and self.settings[i].active) {
                return &self.settings[i];
            }
        }
        return null;
    }

    // Find setting by key.
    pub fn find_setting_by_key(
        self: *SettingsManager,
        category_id: u32,
        key: []const u8,
    ) ?*Setting {
        std.debug.assert(category_id > 0);
        var i: u32 = 0;
        while (i < self.settings_len) : (i += 1) {
            if (self.settings[i].category_id == category_id and self.settings[i].active) {
                const key_slice = self.settings[i].key[0..self.settings[i].key_len];
                if (std.mem.eql(u8, key_slice, key)) {
                    return &self.settings[i];
                }
            }
        }
        return null;
    }

    // Set setting string value.
    pub fn set_setting_string(
        self: *SettingsManager,
        setting_id: u32,
        value: []const u8,
    ) bool {
        std.debug.assert(setting_id > 0);
        if (value.len > MAX_VALUE_LEN) {
            return false;
        }
        if (self.find_setting(setting_id)) |setting| {
            if (setting.value_type != SettingValueType.string) {
                return false;
            }
            var i: u32 = 0;
            while (i < MAX_VALUE_LEN) : (i += 1) {
                setting.value_string[i] = 0;
            }
            const value_len = @min(value.len, MAX_VALUE_LEN);
            i = 0;
            while (i < value_len) : (i += 1) {
                setting.value_string[i] = value[i];
            }
            setting.value_string_len = @intCast(value_len);
            return true;
        }
        return false;
    }

    // Set setting integer value.
    pub fn set_setting_integer(
        self: *SettingsManager,
        setting_id: u32,
        value: i64,
    ) bool {
        std.debug.assert(setting_id > 0);
        if (self.find_setting(setting_id)) |setting| {
            if (setting.value_type != SettingValueType.integer) {
                return false;
            }
            setting.value_integer = value;
            return true;
        }
        return false;
    }

    // Set setting boolean value.
    pub fn set_setting_boolean(
        self: *SettingsManager,
        setting_id: u32,
        value: bool,
    ) bool {
        std.debug.assert(setting_id > 0);
        if (self.find_setting(setting_id)) |setting| {
            if (setting.value_type != SettingValueType.boolean) {
                return false;
            }
            setting.value_boolean = value;
            return true;
        }
        return false;
    }

    // Set setting float value.
    pub fn set_setting_float(
        self: *SettingsManager,
        setting_id: u32,
        value: f64,
    ) bool {
        std.debug.assert(setting_id > 0);
        if (self.find_setting(setting_id)) |setting| {
            if (setting.value_type != SettingValueType.float) {
                return false;
            }
            setting.value_float = value;
            return true;
        }
        return false;
    }

    // Remove setting.
    pub fn remove_setting(self: *SettingsManager, setting_id: u32) bool {
        std.debug.assert(setting_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.settings_len) : (i += 1) {
            if (self.settings[i].setting_id == setting_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining settings left.
        while (i < self.settings_len - 1) : (i += 1) {
            self.settings[i] = self.settings[i + 1];
        }
        self.settings_len -= 1;
        return true;
    }

    // Get setting count.
    pub fn get_setting_count(self: *const SettingsManager) u32 {
        return self.settings_len;
    }

    // Get category count.
    pub fn get_category_count(self: *const SettingsManager) u32 {
        return self.categories_len;
    }
};

