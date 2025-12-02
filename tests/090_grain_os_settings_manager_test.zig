//! Tests for Grain OS settings management system.
//!
//! Why: Verify settings management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const SettingsManager = grain_os.settings_manager.SettingsManager;
const SettingValueType = grain_os.settings_manager.SettingValueType;

test "settings manager initialization" {
    const manager = SettingsManager.init();
    std.debug.assert(manager.settings_len == 0);
    std.debug.assert(manager.categories_len == 0);
    std.debug.assert(manager.next_setting_id == 1);
    std.debug.assert(manager.next_category_id == 1);
}

test "add category" {
    var manager = SettingsManager.init();
    const category_id_opt = manager.add_category("Display");
    std.debug.assert(category_id_opt != null);
    if (category_id_opt) |category_id| {
        std.debug.assert(category_id == 1);
        std.debug.assert(manager.get_category_count() == 1);
    }
}

test "find category by ID" {
    var manager = SettingsManager.init();
    if (manager.add_category("Display")) |category_id| {
        const category_opt = manager.find_category(category_id);
        std.debug.assert(category_opt != null);
        if (category_opt) |category| {
            std.debug.assert(category.category_id == category_id);
        }
    }
}

test "add setting" {
    var manager = SettingsManager.init();
    if (manager.add_category("Display")) |category_id| {
        const setting_id_opt = manager.add_setting(category_id, "brightness", SettingValueType.integer);
        std.debug.assert(setting_id_opt != null);
        if (setting_id_opt) |setting_id| {
            std.debug.assert(setting_id == 1);
            std.debug.assert(manager.get_setting_count() == 1);
        }
    }
}

test "find setting by ID" {
    var manager = SettingsManager.init();
    if (manager.add_category("Display")) |category_id| {
        if (manager.add_setting(category_id, "brightness", SettingValueType.integer)) |setting_id| {
            const setting_opt = manager.find_setting(setting_id);
            std.debug.assert(setting_opt != null);
            if (setting_opt) |setting| {
                std.debug.assert(setting.setting_id == setting_id);
                std.debug.assert(setting.value_type == SettingValueType.integer);
            }
        }
    }
}

test "find setting by key" {
    var manager = SettingsManager.init();
    if (manager.add_category("Display")) |category_id| {
        _ = manager.add_setting(category_id, "brightness", SettingValueType.integer);
        const setting_opt = manager.find_setting_by_key(category_id, "brightness");
        std.debug.assert(setting_opt != null);
        if (setting_opt) |setting| {
            const key_slice = setting.key[0..setting.key_len];
            std.debug.assert(std.mem.eql(u8, key_slice, "brightness"));
        }
    }
}

test "set setting string value" {
    var manager = SettingsManager.init();
    if (manager.add_category("Display")) |category_id| {
        if (manager.add_setting(category_id, "theme", SettingValueType.string)) |setting_id| {
            const result = manager.set_setting_string(setting_id, "dark");
            std.debug.assert(result);
            if (manager.find_setting(setting_id)) |setting| {
                const value_slice = setting.value_string[0..setting.value_string_len];
                std.debug.assert(std.mem.eql(u8, value_slice, "dark"));
            }
        }
    }
}

test "set setting integer value" {
    var manager = SettingsManager.init();
    if (manager.add_category("Display")) |category_id| {
        if (manager.add_setting(category_id, "brightness", SettingValueType.integer)) |setting_id| {
            const result = manager.set_setting_integer(setting_id, 75);
            std.debug.assert(result);
            if (manager.find_setting(setting_id)) |setting| {
                std.debug.assert(setting.value_integer == 75);
            }
        }
    }
}

test "set setting boolean value" {
    var manager = SettingsManager.init();
    if (manager.add_category("Display")) |category_id| {
        if (manager.add_setting(category_id, "auto_brightness", SettingValueType.boolean)) |setting_id| {
            const result = manager.set_setting_boolean(setting_id, true);
            std.debug.assert(result);
            if (manager.find_setting(setting_id)) |setting| {
                std.debug.assert(setting.value_boolean == true);
            }
        }
    }
}

test "set setting float value" {
    var manager = SettingsManager.init();
    if (manager.add_category("Display")) |category_id| {
        if (manager.add_setting(category_id, "scale", SettingValueType.float)) |setting_id| {
            const result = manager.set_setting_float(setting_id, 1.5);
            std.debug.assert(result);
            if (manager.find_setting(setting_id)) |setting| {
                std.debug.assert(setting.value_float == 1.5);
            }
        }
    }
}

test "remove setting" {
    var manager = SettingsManager.init();
    if (manager.add_category("Display")) |category_id| {
        if (manager.add_setting(category_id, "brightness", SettingValueType.integer)) |setting_id| {
            const result = manager.remove_setting(setting_id);
            std.debug.assert(result);
            std.debug.assert(manager.get_setting_count() == 0);
        }
    }
}

test "compositor add category" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const category_id_opt = comp.add_settings_category("Display");
    std.debug.assert(category_id_opt != null);
}

test "compositor add setting" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_settings_category("Display")) |category_id| {
        const setting_id_opt = comp.add_setting(category_id, "brightness", SettingValueType.integer);
        std.debug.assert(setting_id_opt != null);
    }
}

test "compositor set setting value" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_settings_category("Display")) |category_id| {
        if (comp.add_setting(category_id, "brightness", SettingValueType.integer)) |setting_id| {
            const result = comp.set_setting_integer(setting_id, 80);
            std.debug.assert(result);
        }
    }
}

test "compositor find setting by key" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_settings_category("Display")) |category_id| {
        _ = comp.add_setting(category_id, "brightness", SettingValueType.integer);
        const setting_opt = comp.find_setting_by_key(category_id, "brightness");
        std.debug.assert(setting_opt != null);
    }
}

test "compositor get setting count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_setting_count() == 0);
    if (comp.add_settings_category("Display")) |category_id| {
        _ = comp.add_setting(category_id, "brightness", SettingValueType.integer);
        std.debug.assert(comp.get_setting_count() == 1);
    }
}

test "settings constants" {
    std.debug.assert(grain_os.settings_manager.MAX_SETTINGS == 256);
    std.debug.assert(grain_os.settings_manager.MAX_KEY_LEN == 64);
    std.debug.assert(grain_os.settings_manager.MAX_VALUE_LEN == 256);
    std.debug.assert(grain_os.settings_manager.MAX_CATEGORIES == 16);
}

test "setting value types" {
    std.debug.assert(@intFromEnum(SettingValueType.string) == 0);
    std.debug.assert(@intFromEnum(SettingValueType.integer) == 1);
    std.debug.assert(@intFromEnum(SettingValueType.boolean) == 2);
    std.debug.assert(@intFromEnum(SettingValueType.float) == 3);
}

