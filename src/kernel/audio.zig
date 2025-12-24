//! Audio Device Management
//! Why: Manage audio devices for multimedia applications.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const AudioDeviceStats = @import("audio_device_stats.zig").AudioDeviceStats;

/// Maximum number of audio devices.
/// Why: Bounded allocation for device tracking.
const MAX_AUDIO_DEVICES: u32 = 16;

/// Maximum device name length.
/// Why: Bounded string storage for device names.
const MAX_DEVICE_NAME_LEN: u32 = 128;

/// Maximum audio buffer size (64KB).
/// Why: Bounded allocation for audio I/O buffers.
const MAX_AUDIO_BUFFER_SIZE: u32 = 64 * 1024;

/// Audio device type.
/// Why: Categorize audio devices (speaker, headphone, microphone, etc.).
pub const AudioDeviceType = enum(u8) {
    unknown = 0,
    speaker = 1,
    headphone = 2,
    microphone = 3,
    bluetooth = 4,
    usb = 5,
};

/// Audio device state.
/// Why: Track device state (disconnected, connected, active, disabled).
pub const AudioDeviceState = enum(u8) {
    disconnected = 0,
    connected = 1,
    active = 2,
    disabled = 3,
};

/// Audio format.
/// Why: Specify audio format (sample rate, channels, bit depth).
/// Grain Style: Explicit types, bounded values.
pub const AudioFormat = struct {
    /// Sample rate in Hz (e.g., 44100, 48000).
    sample_rate: u32,
    
    /// Number of channels (1 = mono, 2 = stereo).
    channels: u32,
    
    /// Bit depth (8, 16, 24, 32).
    bit_depth: u32,
    
    /// Initialize audio format with defaults.
    /// Why: Explicit initialization, clear state.
    pub fn init() AudioFormat {
        return AudioFormat{
            .sample_rate = 44100,
            .channels = 2,
            .bit_depth = 16,
        };
    }
    
    /// Validate audio format.
    /// Why: Ensure format is valid.
    /// Contract: sample_rate, channels, bit_depth must be valid.
    pub fn is_valid(self: *const AudioFormat) bool {
        // Assert: Sample rate must be reasonable (8kHz to 192kHz).
        if (self.sample_rate < 8000 or self.sample_rate > 192000) {
            return false;
        }
        
        // Assert: Channels must be reasonable (1 to 8).
        if (self.channels == 0 or self.channels > 8) {
            return false;
        }
        
        // Assert: Bit depth must be valid (8, 16, 24, 32).
        if (self.bit_depth != 8 and
            self.bit_depth != 16 and
            self.bit_depth != 24 and
            self.bit_depth != 32) {
            return false;
        }
        
        return true;
    }
};

/// Audio device entry.
/// Why: Track audio device configuration and state.
/// Grain Style: Static allocation, explicit types.
pub const AudioDevice = struct {
    /// Device ID (non-zero if allocated).
    device_id: u32,
    
    /// Device name (null-terminated).
    name: [MAX_DEVICE_NAME_LEN]u8,
    
    /// Device type.
    device_type: AudioDeviceType,
    
    /// Device state.
    state: AudioDeviceState,
    
    /// Volume level (0-100 percentage).
    volume: u32,
    
    /// Mute state.
    muted: bool,
    
    /// Whether this entry is allocated (in use).
    allocated: bool,
    
    /// Owner process ID (0 = kernel-owned, non-zero = process-owned).
    /// Why: Track which process owns this device for resource cleanup.
    owner_process_id: u32,
    
    /// Audio format (sample rate, channels, bit depth).
    /// Why: Specify audio format for I/O operations.
    format: AudioFormat,
    
    /// Input buffer (for recording/input devices).
    /// Why: Buffer incoming audio data.
    input_buffer: [MAX_AUDIO_BUFFER_SIZE]u8,
    
    /// Input buffer size (actual data length).
    input_buffer_len: u32,
    
    /// Output buffer (for playback/output devices).
    /// Why: Buffer outgoing audio data.
    output_buffer: [MAX_AUDIO_BUFFER_SIZE]u8,
    
    /// Output buffer size (actual data length).
    output_buffer_len: u32,
    
    /// Initialize empty audio device entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() AudioDevice {
        var device = AudioDevice{
            .device_id = 0,
            .name = undefined,
            .device_type = .unknown,
            .state = .disconnected,
            .volume = 50,
            .muted = false,
            .allocated = false,
            .owner_process_id = 0,
            .format = AudioFormat.init(),
            .input_buffer = [_]u8{0} ** MAX_AUDIO_BUFFER_SIZE,
            .input_buffer_len = 0,
            .output_buffer = [_]u8{0} ** MAX_AUDIO_BUFFER_SIZE,
            .output_buffer_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_DEVICE_NAME_LEN) : (i += 1) {
            device.name[i] = 0;
        }
        return device;
    }
    
    /// Set device name.
    /// Why: Configure device name.
    /// Contract: name must be valid, non-empty, null-terminated.
    pub fn set_name(self: *AudioDevice, name: []const u8) bool {
        // Assert: Entry must be allocated.
        Debug.kassert(self.allocated, "Entry not allocated", .{});
        
        // Assert: Name must be non-empty.
        if (name.len == 0) {
            return false;
        }
        
        // Assert: Name must fit in buffer (including null terminator).
        if (name.len >= MAX_DEVICE_NAME_LEN) {
            return false;
        }
        
        // Copy name to buffer.
        var i: u32 = 0;
        while (i < MAX_DEVICE_NAME_LEN) : (i += 1) {
            self.name[i] = 0;
        }
        std.mem.copyForwards(u8, self.name[0..name.len], name);
        self.name[name.len] = 0; // Null terminator
        
        return true;
    }
    
    /// Get device name.
    /// Why: Retrieve device name.
    /// Contract: Returns null-terminated string.
    pub fn get_name(self: *const AudioDevice) []const u8 {
        // Assert: Entry must be allocated.
        Debug.kassert(self.allocated, "Entry not allocated", .{});
        
        // Find null terminator.
        var len: u32 = 0;
        while (len < MAX_DEVICE_NAME_LEN) : (len += 1) {
            if (self.name[len] == 0) {
                break;
            }
        }
        
        return self.name[0..len];
    }
    
    /// Set audio format.
    /// Why: Configure audio format for I/O operations.
    /// Contract: format must be valid.
    pub fn set_format(self: *AudioDevice, format: AudioFormat) bool {
        // Assert: Entry must be allocated.
        Debug.kassert(self.allocated, "Entry not allocated", .{});
        
        // Assert: Format must be valid.
        if (!format.is_valid()) {
            return false;
        }
        
        self.format = format;
        return true;
    }
    
    /// Get audio format.
    /// Why: Retrieve audio format.
    /// Contract: Returns current format.
    pub fn get_format(self: *const AudioDevice) AudioFormat {
        // Assert: Entry must be allocated.
        Debug.kassert(self.allocated, "Entry not allocated", .{});
        
        return self.format;
    }
};

/// Audio device manager.
/// Why: Manage all audio devices.
/// Grain Style: Static allocation, bounded operations.
pub const AudioDeviceManager = struct {
    /// Device entries.
    devices: [MAX_AUDIO_DEVICES]AudioDevice,
    
    /// Next device ID (simple allocator, starts at 1).
    /// Why: Track device ID allocation (1-based, 0 is invalid).
    next_device_id: u32,
    
    /// Master volume (0-100 percentage).
    master_volume: u32,
    
    /// Master mute state.
    master_muted: bool,
    
    /// Active output device ID (0 if none).
    active_output_device_id: u32,
    
    /// Active input device ID (0 if none).
    active_input_device_id: u32,
    
    /// Whether manager is initialized.
    initialized: bool,
    
    /// Audio device statistics tracker.
    /// Why: Track device operations and state changes.
    stats: AudioDeviceStats,
    
    /// Initialize audio device manager.
    /// Why: Set up manager state.
    pub fn init() AudioDeviceManager {
        var manager = AudioDeviceManager{
            .devices = undefined,
            .next_device_id = 1,
            .master_volume = 50,
            .master_muted = false,
            .active_output_device_id = 0,
            .active_input_device_id = 0,
            .initialized = true,
            .stats = AudioDeviceStats.init(),
        };
        var i: u32 = 0;
        while (i < MAX_AUDIO_DEVICES) : (i += 1) {
            manager.devices[i] = AudioDevice.init();
        }
        return manager;
    }
    
    /// Create a new audio device.
    /// Why: Add a new audio device.
    /// Contract: name must be valid, non-empty, null-terminated, device_type must be valid.
    /// Returns: Device ID, or null if no free slot.
    pub fn create_device(
        self: *AudioDeviceManager,
        name: []const u8,
        device_type: AudioDeviceType,
        owner_process_id: u32,
    ) ?u32 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Name must be non-empty.
        if (name.len == 0) {
            self.stats.record_creation_error();
            return null;
        }
        
        // Assert: Name must fit in buffer.
        if (name.len >= MAX_DEVICE_NAME_LEN) {
            self.stats.record_creation_error();
            return null;
        }
        
        // Find free slot.
        var idx: u32 = 0;
        while (idx < MAX_AUDIO_DEVICES) : (idx += 1) {
            if (!self.devices[idx].allocated) {
                // Initialize device.
                self.devices[idx] = AudioDevice.init();
                self.devices[idx].allocated = true;
                self.devices[idx].device_id = self.next_device_id;
                self.devices[idx].device_type = device_type;
                self.devices[idx].owner_process_id = owner_process_id;
                
                // Set name.
                if (!self.devices[idx].set_name(name)) {
                    self.devices[idx].allocated = false;
                    self.stats.record_creation_error();
                    return null;
                }
                
                // Increment device ID.
                const device_id = self.next_device_id;
                self.next_device_id += 1;
                if (self.next_device_id == 0) {
                    self.next_device_id = 1; // Wrap around (skip 0)
                }
                
                // Record statistics.
                self.stats.record_device_created();
                
                return device_id;
            }
        }
        
        // No free slot found.
        self.stats.record_creation_error();
        return null;
    }
    
    /// Get device by ID.
    /// Why: Retrieve device entry.
    /// Contract: device_id must be valid (non-zero).
    /// Returns: Pointer to device entry, or null if not found.
    pub fn get_device(
        self: *AudioDeviceManager,
        device_id: u32,
    ) ?*AudioDevice {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Device ID must be non-zero.
        if (device_id == 0) {
            return null;
        }
        
        // Search for device with matching ID.
        var idx: u32 = 0;
        while (idx < MAX_AUDIO_DEVICES) : (idx += 1) {
            if (self.devices[idx].allocated and self.devices[idx].device_id == device_id) {
                return &self.devices[idx];
            }
        }
        
        // Device not found.
        return null;
    }
    
    /// Set device volume.
    /// Why: Control device volume.
    /// Contract: device_id must be valid, volume must be 0-100.
    pub fn set_device_volume(
        self: *AudioDeviceManager,
        device_id: u32,
        volume: u32,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Volume must be valid (0-100).
        if (volume > 100) {
            self.stats.record_configuration_error();
            return false;
        }
        
        const device = self.get_device(device_id) orelse {
            self.stats.record_configuration_error();
            return false;
        };
        
        const old_volume = device.volume;
        device.volume = volume;
        
        // Record statistics if volume changed.
        if (old_volume != volume) {
            self.stats.record_volume_change();
        }
        
        return true;
    }
    
    /// Set device mute state.
    /// Why: Control device mute state.
    /// Contract: device_id must be valid.
    pub fn set_device_mute(
        self: *AudioDeviceManager,
        device_id: u32,
        muted: bool,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const device = self.get_device(device_id) orelse {
            self.stats.record_configuration_error();
            return false;
        };
        
        const old_muted = device.muted;
        device.muted = muted;
        
        // Record statistics if mute state changed.
        if (old_muted != muted) {
            self.stats.record_mute_toggle();
        }
        
        return true;
    }
    
    /// Set device state.
    /// Why: Control device state.
    /// Contract: device_id must be valid, state must be valid.
    pub fn set_device_state(
        self: *AudioDeviceManager,
        device_id: u32,
        state: AudioDeviceState,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const device = self.get_device(device_id) orelse {
            self.stats.record_configuration_error();
            return false;
        };
        
        // Record state transition.
        const old_state = device.state;
        device.state = state;
        if (old_state != state) {
            switch (state) {
                .connected => self.stats.record_connected_transition(),
                .active => self.stats.record_active_transition(),
                .disabled => self.stats.record_disabled_transition(),
                .disconnected => {}, // No specific transition counter for disconnected
            }
        }
        
        return true;
    }
    
    /// Set active output device.
    /// Why: Select active output device.
    /// Contract: device_id must be valid (or 0 to clear).
    pub fn set_active_output_device(
        self: *AudioDeviceManager,
        device_id: u32,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // If device_id is 0, clear active device.
        if (device_id == 0) {
            self.active_output_device_id = 0;
            return true;
        }
        
        // Verify device exists.
        const device = self.get_device(device_id) orelse {
            return false;
        };
        
        // Verify device is output-capable (speaker, headphone, bluetooth, usb).
        if (device.device_type != .speaker and
            device.device_type != .headphone and
            device.device_type != .bluetooth and
            device.device_type != .usb) {
            return false;
        }
        
        self.active_output_device_id = device_id;
        return true;
    }
    
    /// Set active input device.
    /// Why: Select active input device.
    /// Contract: device_id must be valid (or 0 to clear).
    pub fn set_active_input_device(
        self: *AudioDeviceManager,
        device_id: u32,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // If device_id is 0, clear active device.
        if (device_id == 0) {
            self.active_input_device_id = 0;
            return true;
        }
        
        // Verify device exists.
        const device = self.get_device(device_id) orelse {
            return false;
        };
        
        // Verify device is input-capable (microphone, bluetooth, usb).
        if (device.device_type != .microphone and
            device.device_type != .bluetooth and
            device.device_type != .usb) {
            return false;
        }
        
        self.active_input_device_id = device_id;
        return true;
    }
    
    /// Set master volume.
    /// Why: Control master volume.
    /// Contract: volume must be 0-100.
    pub fn set_master_volume(
        self: *AudioDeviceManager,
        volume: u32,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Volume must be valid (0-100).
        if (volume > 100) {
            return false;
        }
        
        self.master_volume = volume;
        return true;
    }
    
    /// Set master mute state.
    /// Why: Control master mute state.
    pub fn set_master_mute(
        self: *AudioDeviceManager,
        muted: bool,
    ) void {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        self.master_muted = muted;
    }
    
    /// Enumerate all audio devices.
    /// Why: Get list of all allocated devices.
    /// Contract: device_ids array must be large enough (MAX_AUDIO_DEVICES).
    /// Returns: Number of devices found.
    pub fn enumerate_devices(
        self: *AudioDeviceManager,
        device_ids: []u32,
    ) u32 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Device IDs array must be large enough.
        Debug.kassert(device_ids.len >= MAX_AUDIO_DEVICES, "Device IDs array too small", .{});
        
        var count: u32 = 0;
        var idx: u32 = 0;
        while (idx < MAX_AUDIO_DEVICES) : (idx += 1) {
            if (self.devices[idx].allocated) {
                device_ids[count] = self.devices[idx].device_id;
                count += 1;
            }
        }
        
        return count;
    }
    
    /// Delete device.
    /// Why: Remove audio device.
    /// Contract: device_id must be valid.
    pub fn delete_device(
        self: *AudioDeviceManager,
        device_id: u32,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Search for device with matching ID.
        var idx: u32 = 0;
        while (idx < MAX_AUDIO_DEVICES) : (idx += 1) {
            if (self.devices[idx].allocated and self.devices[idx].device_id == device_id) {
                // Clear active device references if this device is active.
                if (self.active_output_device_id == device_id) {
                    self.active_output_device_id = 0;
                }
                if (self.active_input_device_id == device_id) {
                    self.active_input_device_id = 0;
                }
                
                // Deallocate device.
                self.devices[idx] = AudioDevice.init();
                
                // Record statistics.
                self.stats.record_device_deleted();
                
                return true;
            }
        }
        
        // Device not found.
        self.stats.record_deletion_error();
        return false;
    }
    
    /// Set audio format for device.
    /// Why: Configure audio format for I/O operations.
    /// Contract: device_id must be valid, format must be valid.
    pub fn set_device_format(
        self: *AudioDeviceManager,
        device_id: u32,
        format: AudioFormat,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Format must be valid.
        if (!format.is_valid()) {
            self.stats.record_configuration_error();
            return false;
        }
        
        const device = self.get_device(device_id) orelse {
            self.stats.record_configuration_error();
            return false;
        };
        
        const result = device.set_format(format);
        if (result) {
            self.stats.record_format_change();
        } else {
            self.stats.record_configuration_error();
        }
        
        return result;
    }
    
    /// Read audio data from device.
    /// Why: Read audio data from input device.
    /// Contract: device_id must be valid, buffer must be valid, len must be valid.
    /// Returns: Number of bytes read, or null on error.
    pub fn read_audio(
        self: *AudioDeviceManager,
        device_id: u32,
        buffer: []u8,
    ) ?u32 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Buffer must be non-empty.
        if (buffer.len == 0) {
            self.stats.record_io_error();
            return null;
        }
        
        // Assert: Buffer must fit within max size.
        if (buffer.len > MAX_AUDIO_BUFFER_SIZE) {
            self.stats.record_io_error();
            return null;
        }
        
        const device = self.get_device(device_id) orelse {
            self.stats.record_io_error();
            return null;
        };
        
        // Assert: Device must be input-capable (microphone, bluetooth, usb).
        if (device.device_type != .microphone and
            device.device_type != .bluetooth and
            device.device_type != .usb) {
            self.stats.record_io_error();
            return null;
        }
        
        // Assert: Device must be active.
        if (device.state != .active) {
            self.stats.record_io_error();
            return null;
        }
        
        // Calculate bytes to read (min of available data and buffer size).
        const available = device.input_buffer_len;
        const bytes_to_read = @min(available, @as(u32, @intCast(buffer.len)));
        
        // Copy data from input buffer.
        if (bytes_to_read > 0) {
            std.mem.copyForwards(u8, buffer[0..bytes_to_read], 
                device.input_buffer[0..bytes_to_read]);
            
            // Shift remaining data to front of buffer.
            if (bytes_to_read < available) {
                const remaining = available - bytes_to_read;
                std.mem.copyForwards(u8, 
                    device.input_buffer[0..remaining],
                    device.input_buffer[bytes_to_read..available]);
            }
            
            device.input_buffer_len -= bytes_to_read;
            
            // Record statistics.
            self.stats.record_bytes_read(bytes_to_read);
        }
        
        return bytes_to_read;
    }
    
    /// Write audio data to device.
    /// Why: Write audio data to output device.
    /// Contract: device_id must be valid, data must be valid, len must be valid.
    /// Returns: Number of bytes written, or null on error.
    pub fn write_audio(
        self: *AudioDeviceManager,
        device_id: u32,
        data: []const u8,
    ) ?u32 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Data must be non-empty.
        if (data.len == 0) {
            self.stats.record_io_error();
            return null;
        }
        
        // Assert: Data must fit within max size.
        if (data.len > MAX_AUDIO_BUFFER_SIZE) {
            self.stats.record_io_error();
            return null;
        }
        
        const device = self.get_device(device_id) orelse {
            self.stats.record_io_error();
            return null;
        };
        
        // Assert: Device must be output-capable (speaker, headphone, bluetooth, usb).
        if (device.device_type != .speaker and
            device.device_type != .headphone and
            device.device_type != .bluetooth and
            device.device_type != .usb) {
            self.stats.record_io_error();
            return null;
        }
        
        // Assert: Device must be active.
        if (device.state != .active) {
            self.stats.record_io_error();
            return null;
        }
        
        // Calculate bytes to write (min of available space and data size).
        const available = MAX_AUDIO_BUFFER_SIZE - device.output_buffer_len;
        const bytes_to_write = @min(available, @as(u32, @intCast(data.len)));
        
        // Copy data to output buffer.
        if (bytes_to_write > 0) {
            std.mem.copyForwards(u8, 
                device.output_buffer[device.output_buffer_len..device.output_buffer_len + bytes_to_write],
                data[0..bytes_to_write]);
            
            device.output_buffer_len += bytes_to_write;
            
            // Record statistics.
            self.stats.record_bytes_written(bytes_to_write);
        }
        
        return bytes_to_write;
    }
    
    /// Get audio device statistics snapshot.
    /// Why: Provide statistics for userspace queries.
    /// Returns: Reference to statistics tracker.
    pub fn get_stats(self: *const AudioDeviceManager) *const AudioDeviceStats {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        return &self.stats;
    }
};

