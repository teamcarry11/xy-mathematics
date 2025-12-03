//! Grain OS Audio Manager: Audio device and volume management.
//!
//! Why: Provide audio management for device selection and volume control.
//! Architecture: Audio device management, volume control, mute state.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max audio devices.
pub const MAX_AUDIO_DEVICES: u32 = 16;

// Bounded: Max device name length.
pub const MAX_DEVICE_NAME_LEN: u32 = 128;

// Audio device type.
pub const AudioDeviceType = enum(u8) {
    unknown,
    speaker,
    headphone,
    microphone,
    bluetooth,
    usb,
};

// Audio device state.
pub const AudioDeviceState = enum(u8) {
    disconnected,
    connected,
    active,
    disabled,
};

// Audio device: represents an audio device.
pub const AudioDevice = struct {
    device_id: u32,
    name: [MAX_DEVICE_NAME_LEN]u8,
    name_len: u32,
    device_type: AudioDeviceType,
    state: AudioDeviceState,
    volume: u32, // 0-100 percentage.
    muted: bool,
    active: bool,

    pub fn init() AudioDevice {
        var device = AudioDevice{
            .device_id = 0,
            .name = undefined,
            .name_len = 0,
            .device_type = AudioDeviceType.unknown,
            .state = AudioDeviceState.disconnected,
            .volume = 50,
            .muted = false,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_DEVICE_NAME_LEN) : (i += 1) {
            device.name[i] = 0;
        }
        return device;
    }
};

// Audio manager: manages audio devices and volume.
pub const AudioManager = struct {
    devices: [MAX_AUDIO_DEVICES]AudioDevice,
    devices_len: u32,
    next_device_id: u32,
    master_volume: u32, // 0-100 percentage.
    master_muted: bool,
    active_output_device_id: u32,
    active_input_device_id: u32,

    pub fn init() AudioManager {
        var manager = AudioManager{
            .devices = undefined,
            .devices_len = 0,
            .next_device_id = 1,
            .master_volume = 50,
            .master_muted = false,
            .active_output_device_id = 0,
            .active_input_device_id = 0,
        };
        var i: u32 = 0;
        while (i < MAX_AUDIO_DEVICES) : (i += 1) {
            manager.devices[i] = AudioDevice.init();
        }
        return manager;
    }

    // Add audio device.
    pub fn add_device(
        self: *AudioManager,
        name: []const u8,
        device_type: AudioDeviceType,
    ) ?u32 {
        if (self.devices_len >= MAX_AUDIO_DEVICES) {
            return null;
        }
        if (name.len > MAX_DEVICE_NAME_LEN) {
            return null;
        }
        const device_id = self.next_device_id;
        self.next_device_id += 1;
        self.devices[self.devices_len] = AudioDevice.init();
        self.devices[self.devices_len].device_id = device_id;
        self.devices[self.devices_len].device_type = device_type;
        self.devices[self.devices_len].state = AudioDeviceState.connected;
        self.devices[self.devices_len].active = true;
        var i: u32 = 0;
        while (i < MAX_DEVICE_NAME_LEN) : (i += 1) {
            self.devices[self.devices_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_DEVICE_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.devices[self.devices_len].name[i] = name[i];
        }
        self.devices[self.devices_len].name_len = @intCast(name_len);
        if (self.active_output_device_id == 0 and device_type == AudioDeviceType.speaker) {
            self.active_output_device_id = device_id;
        }
        if (self.active_input_device_id == 0 and device_type == AudioDeviceType.microphone) {
            self.active_input_device_id = device_id;
        }
        self.devices_len += 1;
        return device_id;
    }

    // Find device by ID.
    pub fn find_device(
        self: *AudioManager,
        device_id: u32,
    ) ?*AudioDevice {
        std.debug.assert(device_id > 0);
        var i: u32 = 0;
        while (i < self.devices_len) : (i += 1) {
            if (self.devices[i].device_id == device_id and self.devices[i].active) {
                return &self.devices[i];
            }
        }
        return null;
    }

    // Set device volume.
    pub fn set_device_volume(self: *AudioManager, device_id: u32, volume: u32) bool {
        std.debug.assert(device_id > 0);
        std.debug.assert(volume <= 100);
        if (self.find_device(device_id)) |device| {
            device.volume = volume;
            return true;
        }
        return false;
    }

    // Get device volume.
    pub fn get_device_volume(self: *AudioManager, device_id: u32) ?u32 {
        std.debug.assert(device_id > 0);
        if (self.find_device(device_id)) |device| {
            return device.volume;
        }
        return null;
    }

    // Mute device.
    pub fn mute_device(self: *AudioManager, device_id: u32) bool {
        std.debug.assert(device_id > 0);
        if (self.find_device(device_id)) |device| {
            device.muted = true;
            return true;
        }
        return false;
    }

    // Unmute device.
    pub fn unmute_device(self: *AudioManager, device_id: u32) bool {
        std.debug.assert(device_id > 0);
        if (self.find_device(device_id)) |device| {
            device.muted = false;
            return true;
        }
        return false;
    }

    // Set active output device.
    pub fn set_active_output_device(self: *AudioManager, device_id: u32) bool {
        std.debug.assert(device_id > 0);
        if (self.find_device(device_id)) |device| {
            if (device.device_type == AudioDeviceType.speaker or device.device_type == AudioDeviceType.headphone) {
                self.active_output_device_id = device_id;
                return true;
            }
        }
        return false;
    }

    // Set active input device.
    pub fn set_active_input_device(self: *AudioManager, device_id: u32) bool {
        std.debug.assert(device_id > 0);
        if (self.find_device(device_id)) |device| {
            if (device.device_type == AudioDeviceType.microphone) {
                self.active_input_device_id = device_id;
                return true;
            }
        }
        return false;
    }

    // Get active output device.
    pub fn get_active_output_device(self: *const AudioManager) ?*const AudioDevice {
        if (self.active_output_device_id == 0) {
            return null;
        }
        var i: u32 = 0;
        while (i < self.devices_len) : (i += 1) {
            if (self.devices[i].device_id == self.active_output_device_id) {
                return &self.devices[i];
            }
        }
        return null;
    }

    // Get active input device.
    pub fn get_active_input_device(self: *const AudioManager) ?*const AudioDevice {
        if (self.active_input_device_id == 0) {
            return null;
        }
        var i: u32 = 0;
        while (i < self.devices_len) : (i += 1) {
            if (self.devices[i].device_id == self.active_input_device_id) {
                return &self.devices[i];
            }
        }
        return null;
    }

    // Set master volume.
    pub fn set_master_volume(self: *AudioManager, volume: u32) void {
        std.debug.assert(volume <= 100);
        self.master_volume = volume;
    }

    // Get master volume.
    pub fn get_master_volume(self: *const AudioManager) u32 {
        return self.master_volume;
    }

    // Mute master.
    pub fn mute_master(self: *AudioManager) void {
        self.master_muted = true;
    }

    // Unmute master.
    pub fn unmute_master(self: *AudioManager) void {
        self.master_muted = false;
    }

    // Check if master is muted.
    pub fn is_master_muted(self: *const AudioManager) bool {
        return self.master_muted;
    }

    // Remove device.
    pub fn remove_device(self: *AudioManager, device_id: u32) bool {
        std.debug.assert(device_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.devices_len) : (i += 1) {
            if (self.devices[i].device_id == device_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        if (self.active_output_device_id == device_id) {
            self.active_output_device_id = 0;
        }
        if (self.active_input_device_id == device_id) {
            self.active_input_device_id = 0;
        }
        // Shift remaining devices left.
        while (i < self.devices_len - 1) : (i += 1) {
            self.devices[i] = self.devices[i + 1];
        }
        self.devices_len -= 1;
        return true;
    }

    // Get device count.
    pub fn get_device_count(self: *const AudioManager) u32 {
        return self.devices_len;
    }
};

