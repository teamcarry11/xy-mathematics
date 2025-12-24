//! Audio Device Management Tests
//! Why: Test audio device management syscalls.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.basin_kernel.BasinKernel;
const BasinError = basin_kernel.basin_kernel.BasinError;
const SyscallResult = basin_kernel.basin_kernel.SyscallResult;

// Test: audio device manager initialization.
test "audio device manager init" {
    var kernel = BasinKernel.init();
    
    // Audio device manager should be initialized.
    // We can't directly access it, but we can test through syscalls.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 15; // "Built-in Speaker"
    const device_type: u64 = 1; // speaker
    const result = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result == .success);
    const device_id = result.success;
    try testing.expect(device_id > 0);
}

// Test: create audio device.
test "audio create device" {
    var kernel = BasinKernel.init();
    
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 15; // "Built-in Speaker"
    const device_type: u64 = 1; // speaker
    const result = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result == .success);
    const device_id = result.success;
    try testing.expect(device_id > 0);
}

// Test: set device volume.
test "audio set device volume" {
    var kernel = BasinKernel.init();
    
    // Create device first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 15; // "Built-in Speaker"
    const device_type: u64 = 1; // speaker
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id = result1.success;
    
    // Set device volume to 75.
    const volume: u64 = 75;
    const result2 = try kernel.syscall_audio_set_volume(
        device_id,
        volume,
        0,
        0,
    );
    try testing.expect(result2 == .success);
}

// Test: set device mute state.
test "audio set device mute" {
    var kernel = BasinKernel.init();
    
    // Create device first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 15; // "Built-in Speaker"
    const device_type: u64 = 1; // speaker
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id = result1.success;
    
    // Mute device.
    const muted: u64 = 1; // true
    const result2 = try kernel.syscall_audio_set_mute(
        device_id,
        muted,
        0,
        0,
    );
    try testing.expect(result2 == .success);
    
    // Unmute device.
    const unmuted: u64 = 0; // false
    const result3 = try kernel.syscall_audio_set_mute(
        device_id,
        unmuted,
        0,
        0,
    );
    try testing.expect(result3 == .success);
}

// Test: set device state.
test "audio set device state" {
    var kernel = BasinKernel.init();
    
    // Create device first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 15; // "Built-in Speaker"
    const device_type: u64 = 1; // speaker
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id = result1.success;
    
    // Set device state to active.
    const state: u64 = 2; // active
    const result2 = try kernel.syscall_audio_set_state(
        device_id,
        state,
        0,
        0,
    );
    try testing.expect(result2 == .success);
}

// Test: set active output device.
test "audio set active output device" {
    var kernel = BasinKernel.init();
    
    // Create first device.
    const name_ptr1: u64 = 0x10000;
    const name_len1: u64 = 15; // "Built-in Speaker"
    const device_type1: u64 = 1; // speaker
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr1,
        name_len1,
        device_type1,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id1 = result1.success;
    
    // Create second device.
    const name_ptr2: u64 = 0x20000;
    const name_len2: u64 = 10; // "Headphones"
    const device_type2: u64 = 2; // headphone
    const result2 = try kernel.syscall_audio_create_device(
        name_ptr2,
        name_len2,
        device_type2,
        0,
    );
    try testing.expect(result2 == .success);
    const device_id2 = result2.success;
    
    // Set active output device to second device.
    const result3 = try kernel.syscall_audio_set_active_output(
        device_id2,
        0,
        0,
        0,
    );
    try testing.expect(result3 == .success);
}

// Test: set active input device.
test "audio set active input device" {
    var kernel = BasinKernel.init();
    
    // Create device first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 10; // "Microphone"
    const device_type: u64 = 3; // microphone
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id = result1.success;
    
    // Set active input device.
    const result2 = try kernel.syscall_audio_set_active_input(
        device_id,
        0,
        0,
        0,
    );
    try testing.expect(result2 == .success);
}

// Test: set master volume.
test "audio set master volume" {
    var kernel = BasinKernel.init();
    
    // Set master volume to 80.
    const volume: u64 = 80;
    const result = try kernel.syscall_audio_set_master_volume(
        volume,
        0,
        0,
        0,
    );
    try testing.expect(result == .success);
}

// Test: set master mute state.
test "audio set master mute" {
    var kernel = BasinKernel.init();
    
    // Mute master.
    const muted: u64 = 1; // true
    const result1 = try kernel.syscall_audio_set_master_mute(
        muted,
        0,
        0,
        0,
    );
    try testing.expect(result1 == .success);
    
    // Unmute master.
    const unmuted: u64 = 0; // false
    const result2 = try kernel.syscall_audio_set_master_mute(
        unmuted,
        0,
        0,
        0,
    );
    try testing.expect(result2 == .success);
}

// Test: get device information.
test "audio get device" {
    var kernel = BasinKernel.init();
    
    // Create device first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 15; // "Built-in Speaker"
    const device_type: u64 = 1; // speaker
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id = result1.success;
    
    // Get device information.
    const info_ptr: u64 = 0x30000;
    const result2 = try kernel.syscall_audio_get_device(
        device_id,
        info_ptr,
        0,
        0,
    );
    try testing.expect(result2 == .success);
}

// Test: invalid device ID.
test "audio invalid device id" {
    var kernel = BasinKernel.init();
    
    // Try to set volume on invalid device.
    const invalid_id: u64 = 999;
    const volume: u64 = 50;
    const result = kernel.syscall_audio_set_volume(
        invalid_id,
        volume,
        0,
        0,
    );
    try testing.expectError(BasinError.not_found, result);
}

// Test: invalid volume value.
test "audio invalid volume" {
    var kernel = BasinKernel.init();
    
    // Create device first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 15; // "Built-in Speaker"
    const device_type: u64 = 1; // speaker
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id = result1.success;
    
    // Try to set invalid volume (over 100).
    const invalid_volume: u64 = 150;
    const result2 = kernel.syscall_audio_set_volume(
        device_id,
        invalid_volume,
        0,
        0,
    );
    try testing.expectError(BasinError.invalid_argument, result2);
}

// Test: invalid device type.
test "audio invalid device type" {
    var kernel = BasinKernel.init();
    
    // Try to create device with invalid type.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 15; // "Built-in Speaker"
    const invalid_type: u64 = 99; // invalid
    const result = kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        invalid_type,
        0,
    );
    try testing.expectError(BasinError.invalid_argument, result);
}

// Test: null name pointer.
test "audio null name pointer" {
    var kernel = BasinKernel.init();
    
    // Try to create device with null name pointer.
    const name_ptr: u64 = 0;
    const name_len: u64 = 15;
    const device_type: u64 = 1; // speaker
    const result = kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expectError(BasinError.invalid_argument, result);
}

// Test: zero-length name.
test "audio zero length name" {
    var kernel = BasinKernel.init();
    
    // Try to create device with zero-length name.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 0;
    const device_type: u64 = 1; // speaker
    const result = kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expectError(BasinError.invalid_argument, result);
}

// Test: multiple devices.
test "audio multiple devices" {
    var kernel = BasinKernel.init();
    
    // Create multiple devices.
    const name_ptr1: u64 = 0x10000;
    const name_len1: u64 = 15; // "Built-in Speaker"
    const device_type1: u64 = 1; // speaker
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr1,
        name_len1,
        device_type1,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id1 = result1.success;
    
    const name_ptr2: u64 = 0x20000;
    const name_len2: u64 = 10; // "Headphones"
    const device_type2: u64 = 2; // headphone
    const result2 = try kernel.syscall_audio_create_device(
        name_ptr2,
        name_len2,
        device_type2,
        0,
    );
    try testing.expect(result2 == .success);
    const device_id2 = result2.success;
    
    // Verify different device IDs.
    try testing.expect(device_id1 != device_id2);
    
    // Set different volumes.
    const volume1: u64 = 50;
    const result3 = try kernel.syscall_audio_set_volume(
        device_id1,
        volume1,
        0,
        0,
    );
    try testing.expect(result3 == .success);
    
    const volume2: u64 = 75;
    const result4 = try kernel.syscall_audio_set_volume(
        device_id2,
        volume2,
        0,
        0,
    );
    try testing.expect(result4 == .success);
}

// Test: set audio format.
test "audio set format" {
    var kernel = BasinKernel.init();
    
    // Create device first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 15; // "Built-in Speaker"
    const device_type: u64 = 1; // speaker
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id = result1.success;
    
    // Set audio format (44.1kHz, stereo, 16-bit).
    const sample_rate: u64 = 44100;
    const channels: u64 = 2;
    const bit_depth: u64 = 16;
    const result2 = try kernel.syscall_audio_set_format(
        device_id,
        sample_rate,
        channels,
        bit_depth,
    );
    try testing.expect(result2 == .success);
}

// Test: read audio data from input device.
test "audio read from input device" {
    var kernel = BasinKernel.init();
    
    // Create input device first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 10; // "Microphone"
    const device_type: u64 = 3; // microphone
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id = result1.success;
    
    // Set device state to active.
    const state: u64 = 2; // active
    const result2 = try kernel.syscall_audio_set_state(
        device_id,
        state,
        0,
        0,
    );
    try testing.expect(result2 == .success);
    
    // Read audio data.
    const buffer_ptr: u64 = 0x20000;
    const buffer_len: u64 = 1024;
    const result3 = try kernel.syscall_audio_read(
        device_id,
        buffer_ptr,
        buffer_len,
        0,
    );
    try testing.expect(result3 == .success);
    const bytes_read = result3.success;
    try testing.expect(bytes_read <= buffer_len);
}

// Test: write audio data to output device.
test "audio write to output device" {
    var kernel = BasinKernel.init();
    
    // Create output device first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 15; // "Built-in Speaker"
    const device_type: u64 = 1; // speaker
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id = result1.success;
    
    // Set device state to active.
    const state: u64 = 2; // active
    const result2 = try kernel.syscall_audio_set_state(
        device_id,
        state,
        0,
        0,
    );
    try testing.expect(result2 == .success);
    
    // Write audio data.
    const data_ptr: u64 = 0x30000;
    const data_len: u64 = 1024;
    const result3 = try kernel.syscall_audio_write(
        device_id,
        data_ptr,
        data_len,
        0,
    );
    try testing.expect(result3 == .success);
    const bytes_written = result3.success;
    try testing.expect(bytes_written <= data_len);
}

// Test: invalid format parameters.
test "audio invalid format" {
    var kernel = BasinKernel.init();
    
    // Create device first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 15; // "Built-in Speaker"
    const device_type: u64 = 1; // speaker
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id = result1.success;
    
    // Try to set invalid sample rate.
    const invalid_sample_rate: u64 = 5000; // Too low
    const channels: u64 = 2;
    const bit_depth: u64 = 16;
    const result2 = kernel.syscall_audio_set_format(
        device_id,
        invalid_sample_rate,
        channels,
        bit_depth,
    );
    try testing.expectError(BasinError.invalid_argument, result2);
}

// Test: read from output device (should fail).
test "audio read from output device fails" {
    var kernel = BasinKernel.init();
    
    // Create output device first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 15; // "Built-in Speaker"
    const device_type: u64 = 1; // speaker
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id = result1.success;
    
    // Set device state to active.
    const state: u64 = 2; // active
    const result2 = try kernel.syscall_audio_set_state(
        device_id,
        state,
        0,
        0,
    );
    try testing.expect(result2 == .success);
    
    // Try to read from output device (should fail).
    const buffer_ptr: u64 = 0x20000;
    const buffer_len: u64 = 1024;
    const result3 = kernel.syscall_audio_read(
        device_id,
        buffer_ptr,
        buffer_len,
        0,
    );
    try testing.expectError(BasinError.not_found, result3);
}

// Test: write to input device (should fail).
test "audio write to input device fails" {
    var kernel = BasinKernel.init();
    
    // Create input device first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 10; // "Microphone"
    const device_type: u64 = 3; // microphone
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id = result1.success;
    
    // Set device state to active.
    const state: u64 = 2; // active
    const result2 = try kernel.syscall_audio_set_state(
        device_id,
        state,
        0,
        0,
    );
    try testing.expect(result2 == .success);
    
    // Try to write to input device (should fail).
    const data_ptr: u64 = 0x30000;
    const data_len: u64 = 1024;
    const result3 = kernel.syscall_audio_write(
        device_id,
        data_ptr,
        data_len,
        0,
    );
    try testing.expectError(BasinError.not_found, result3);
}

// Test: enumerate audio devices.
test "audio enumerate devices" {
    var kernel = BasinKernel.init();
    
    // Create multiple devices.
    const name_ptr1: u64 = 0x10000;
    const name_len1: u64 = 15; // "Built-in Speaker"
    const device_type1: u64 = 1; // speaker
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr1,
        name_len1,
        device_type1,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id1 = result1.success;
    
    const name_ptr2: u64 = 0x20000;
    const name_len2: u64 = 10; // "Microphone"
    const device_type2: u64 = 3; // microphone
    const result2 = try kernel.syscall_audio_create_device(
        name_ptr2,
        name_len2,
        device_type2,
        0,
    );
    try testing.expect(result2 == .success);
    const device_id2 = result2.success;
    
    // Enumerate devices.
    const device_ids_ptr: u64 = 0x30000;
    const max_count: u64 = 16;
    const result3 = try kernel.syscall_audio_enumerate_devices(
        device_ids_ptr,
        max_count,
        0,
        0,
    );
    try testing.expect(result3 == .success);
    const count = result3.success;
    try testing.expect(count >= 2); // At least 2 devices
}

// Test: delete audio device.
test "audio delete device" {
    var kernel = BasinKernel.init();
    
    // Create device first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 15; // "Built-in Speaker"
    const device_type: u64 = 1; // speaker
    const result1 = try kernel.syscall_audio_create_device(
        name_ptr,
        name_len,
        device_type,
        0,
    );
    try testing.expect(result1 == .success);
    const device_id = result1.success;
    
    // Delete device.
    const result2 = try kernel.syscall_audio_delete_device(device_id, 0, 0, 0);
    try testing.expect(result2 == .success);
    
    // Try to delete again (should fail).
    const result3 = kernel.syscall_audio_delete_device(device_id, 0, 0, 0);
    try testing.expectError(BasinError.not_found, result3);
}