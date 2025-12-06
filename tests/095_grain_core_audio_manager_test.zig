//! Tests for Grain OS audio management system.
//!
//! Why: Verify audio management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_core = @import("grain_core");
const Compositor = grain_core.compositor.Compositor;
const AudioManager = grain_core.audio_manager.AudioManager;
const AudioDeviceType = grain_core.audio_manager.AudioDeviceType;

test "audio manager initialization" {
    const manager = AudioManager.init();
    std.debug.assert(manager.devices_len == 0);
    std.debug.assert(manager.next_device_id == 1);
    std.debug.assert(manager.get_master_volume() == 50);
    std.debug.assert(!manager.is_master_muted());
}

test "add audio device" {
    var manager = AudioManager.init();
    const device_id_opt = manager.add_device("Built-in Speaker", AudioDeviceType.speaker);
    std.debug.assert(device_id_opt != null);
    if (device_id_opt) |device_id| {
        std.debug.assert(device_id == 1);
        std.debug.assert(manager.get_device_count() == 1);
        std.debug.assert(manager.active_output_device_id == device_id);
    }
}

test "find device by ID" {
    var manager = AudioManager.init();
    if (manager.add_device("Built-in Speaker", AudioDeviceType.speaker)) |device_id| {
        const device_opt = manager.find_device(device_id);
        std.debug.assert(device_opt != null);
        if (device_opt) |device| {
            std.debug.assert(device.device_id == device_id);
            std.debug.assert(device.device_type == AudioDeviceType.speaker);
        }
    }
}

test "set device volume" {
    var manager = AudioManager.init();
    if (manager.add_device("Built-in Speaker", AudioDeviceType.speaker)) |device_id| {
        const result = manager.set_device_volume(device_id, 75);
        std.debug.assert(result);
        const volume_opt = manager.get_device_volume(device_id);
        std.debug.assert(volume_opt != null);
        if (volume_opt) |volume| {
            std.debug.assert(volume == 75);
        }
    }
}

test "mute and unmute device" {
    var manager = AudioManager.init();
    if (manager.add_device("Built-in Speaker", AudioDeviceType.speaker)) |device_id| {
        _ = manager.mute_device(device_id);
        if (manager.find_device(device_id)) |device| {
            std.debug.assert(device.muted);
        }
        _ = manager.unmute_device(device_id);
        if (manager.find_device(device_id)) |device| {
            std.debug.assert(!device.muted);
        }
    }
}

test "set active output device" {
    var manager = AudioManager.init();
    if (manager.add_device("Built-in Speaker", AudioDeviceType.speaker)) |device_id_1| {
        if (manager.add_device("Headphones", AudioDeviceType.headphone)) |device_id_2| {
            const result = manager.set_active_output_device(device_id_2);
            std.debug.assert(result);
            std.debug.assert(manager.active_output_device_id == device_id_2);
        }
    }
}

test "set master volume" {
    var manager = AudioManager.init();
    manager.set_master_volume(80);
    std.debug.assert(manager.get_master_volume() == 80);
}

test "mute and unmute master" {
    var manager = AudioManager.init();
    manager.mute_master();
    std.debug.assert(manager.is_master_muted());
    manager.unmute_master();
    std.debug.assert(!manager.is_master_muted());
}

test "remove device" {
    var manager = AudioManager.init();
    if (manager.add_device("Built-in Speaker", AudioDeviceType.speaker)) |device_id| {
        const result = manager.remove_device(device_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_device_count() == 0);
    }
}

test "compositor add audio device" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const device_id_opt = comp.add_audio_device("Built-in Speaker", AudioDeviceType.speaker);
    std.debug.assert(device_id_opt != null);
}

test "compositor set device volume" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_audio_device("Built-in Speaker", AudioDeviceType.speaker)) |device_id| {
        const result = comp.set_audio_device_volume(device_id, 60);
        std.debug.assert(result);
    }
}

test "compositor set master volume" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_master_volume(70);
    std.debug.assert(comp.get_master_volume() == 70);
}

test "compositor mute master" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.mute_master_audio();
    std.debug.assert(comp.is_master_audio_muted());
    comp.unmute_master_audio();
    std.debug.assert(!comp.is_master_audio_muted());
}

test "compositor get device count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_audio_device_count() == 0);
    _ = comp.add_audio_device("Built-in Speaker", AudioDeviceType.speaker);
    std.debug.assert(comp.get_audio_device_count() == 1);
}

test "audio device types" {
    std.debug.assert(@intFromEnum(AudioDeviceType.unknown) == 0);
    std.debug.assert(@intFromEnum(AudioDeviceType.speaker) == 1);
    std.debug.assert(@intFromEnum(AudioDeviceType.headphone) == 2);
    std.debug.assert(@intFromEnum(AudioDeviceType.microphone) == 3);
}

test "audio manager constants" {
    std.debug.assert(grain_core.audio_manager.MAX_AUDIO_DEVICES == 16);
    std.debug.assert(grain_core.audio_manager.MAX_DEVICE_NAME_LEN == 128);
}

