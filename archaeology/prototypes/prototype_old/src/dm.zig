const std = @import("std");
const crypto = std.crypto;

const X25519 = crypto.dh.X25519;
const Ae = crypto.aead.chacha_poly.ChaCha20Poly1305;
const Sha256 = crypto.hash.sha2.Sha256;

pub const shared_length = X25519.shared_length;
pub const public_length = X25519.public_length;
pub const secret_length = X25519.secret_length;

pub const Nonce = [Ae.nonce_length]u8;
pub const Tag = [Ae.tag_length]u8;
pub const Key = [Ae.key_length]u8;

pub const SharedSecret = struct {
    bytes: [shared_length]u8,

    fn symmetricKey(self: SharedSecret) Key {
        var digest: [Sha256.digest_length]u8 = undefined;
        Sha256.hash(&self.bytes, &digest, .{});
        return digest;
    }
};

pub fn deriveSharedSecret(
    local_secret: [secret_length]u8,
    peer_public: [public_length]u8,
) !SharedSecret {
    const shared = try X25519.scalarmult(local_secret, peer_public);
    return SharedSecret{ .bytes = shared };
}

pub fn encryptMessage(
    allocator: std.mem.Allocator,
    shared: SharedSecret,
    nonce: Nonce,
    plaintext: []const u8,
    aad: []const u8,
) ![]u8 {
    const mac = Ae.tag_length;
    const buf = try allocator.alloc(u8, plaintext.len + mac);
    errdefer allocator.free(buf);

    const key = shared.symmetricKey();
    const nonce_copy = nonce;
    var tag: Tag = undefined;
    Ae.encrypt(buf[0..plaintext.len], &tag, plaintext, aad, nonce_copy, key);
    std.mem.copyForwards(u8, buf[plaintext.len..], tag[0..]);
    return buf;
}

pub fn decryptMessage(
    allocator: std.mem.Allocator,
    shared: SharedSecret,
    nonce: Nonce,
    ciphertext: []const u8,
    aad: []const u8,
) ![]u8 {
    if (ciphertext.len < Ae.tag_length) return error.CiphertextTooShort;
    const msg_len = ciphertext.len - Ae.tag_length;

    const key = shared.symmetricKey();
    const nonce_copy = nonce;
    var tag: Tag = undefined;
    std.mem.copyForwards(u8, tag[0..], ciphertext[msg_len..]);

    const plaintext = try allocator.alloc(u8, msg_len);
    errdefer allocator.free(plaintext);

    try Ae.decrypt(plaintext, ciphertext[0..msg_len], tag, aad, nonce_copy, key);
    return plaintext;
}

pub const DirectMessage = struct {
    sender: [public_length]u8,
    receiver: [public_length]u8,
    nonce: Nonce,
    ciphertext: []u8,
    timestamp: i64,

    pub fn deinit(self: *DirectMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.ciphertext);
        self.* = undefined;
    }
};

pub const Conversation = struct {
    allocator: std.mem.Allocator,
    messages: std.ArrayListUnmanaged(DirectMessage),

    pub fn init(allocator: std.mem.Allocator) Conversation {
        return .{
            .allocator = allocator,
            .messages = .{},
        };
    }

    pub fn deinit(self: *Conversation) void {
        for (self.messages.items) |*msg| {
            msg.deinit(self.allocator);
        }
        self.messages.deinit(self.allocator);
        self.messages = .{};
    }

    pub fn append(self: *Conversation, message: DirectMessage) !void {
        try self.messages.append(self.allocator, message);
    }

    pub fn count(self: *Conversation) usize {
        return self.messages.items.len;
    }

    pub fn last(self: *Conversation) ?DirectMessage {
        if (self.messages.items.len == 0) return null;
        return self.messages.items[self.messages.items.len - 1];
    }
};

test "direct message encrypt/decrypt roundtrip" {
    const alice_seed = [_]u8{0x11} ** secret_length;
    const bob_seed = [_]u8{0x22} ** secret_length;

    const alice = try X25519.KeyPair.generateDeterministic(alice_seed);
    const bob = try X25519.KeyPair.generateDeterministic(bob_seed);

    const alice_shared = try deriveSharedSecret(alice.secret_key, bob.public_key);
    const bob_shared = try deriveSharedSecret(bob.secret_key, alice.public_key);
    try std.testing.expectEqualSlices(u8, &alice_shared.bytes, &bob_shared.bytes);

    const nonce: Nonce = [_]u8{0xAA} ** Ae.nonce_length;
    const aad = "nostr-dm";
    const plain = "Glow G2 whispers";

    const cipher = try encryptMessage(std.testing.allocator, alice_shared, nonce, plain, aad);
    defer std.testing.allocator.free(cipher);

    const decrypted = try decryptMessage(std.testing.allocator, bob_shared, nonce, cipher, aad);
    defer std.testing.allocator.free(decrypted);

    try std.testing.expectEqualSlices(u8, plain, decrypted);
}

test "conversation appends and frees" {
    const alice_seed = [_]u8{0x01} ** secret_length;
    const bob_seed = [_]u8{0x02} ** secret_length;
    const alice = try X25519.KeyPair.generateDeterministic(alice_seed);
    const bob = try X25519.KeyPair.generateDeterministic(bob_seed);
    const shared = try deriveSharedSecret(alice.secret_key, bob.public_key);

    const nonce: Nonce = [_]u8{0xBB} ** Ae.nonce_length;
    const aad = "";
    const plain = "Descending prompts stay true.";

    const cipher = try encryptMessage(std.testing.allocator, shared, nonce, plain, aad);
    defer std.testing.allocator.free(cipher);

    var dm = DirectMessage{
        .sender = alice.public_key,
        .receiver = bob.public_key,
        .nonce = nonce,
        .ciphertext = try std.testing.allocator.dupe(u8, cipher),
        .timestamp = 1,
    };
    errdefer dm.deinit(std.testing.allocator);

    var convo = Conversation.init(std.testing.allocator);
    defer convo.deinit();

    try convo.append(dm);
    dm = undefined;
    try std.testing.expectEqual(@as(usize, 1), convo.count());
}
