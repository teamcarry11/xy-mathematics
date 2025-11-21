const std = @import("std");

/// contracts.zig
/// Unified settlement interface shared across Grain modules. Encodes
/// TigerBank messages into fixed-size stack buffers while leaving room
/// for optional inventory, proof-of-sales, and payroll extensions.
pub const SettlementContracts = struct {
    pub const kind_tag_len: usize = 1;

    pub const Kind = enum(u8) {
        tigerbank_mmt = 0,
        tigerbank_cdn = 1,
        optional_inventory = 2,
        optional_sales = 3,
        optional_payroll = 4,
    };

    pub const Policy = struct {
        base_rate_bps: i32,
        tax_rate_bps: i32,

        pub const encoded_len: usize = 8;

        pub fn writeInto(policy: Policy, buffer: []u8) void {
            storeIntLittle(i32, buffer[0..4], policy.base_rate_bps);
            storeIntLittle(i32, buffer[4..8], policy.tax_rate_bps);
        }
    };

    pub const LoanTerms = struct {
        principal: u128,
        rate_bps: i32,
        duration_seconds: u64,
    };

    pub const ActionPayload = struct {
        pub const scalar_len: usize = 16;
        pub const loan_len: usize = 16 + 4 + 8;
    };

    pub const Action = union(enum) {
        mint: u128,
        burn: u128,
        loan: LoanTerms,
        collect_tax: u128,

        pub const max_payload_len: usize = ActionPayload.loan_len;

        pub fn payloadLength(self: Action) usize {
            return switch (self) {
                .mint, .burn, .collect_tax => ActionPayload.scalar_len,
                .loan => ActionPayload.loan_len,
            };
        }

        pub fn writeInto(self: Action, buffer: []u8) usize {
            return switch (self) {
                .mint => |amt| writeScalar(buffer, amt),
                .burn => |amt| writeScalar(buffer, amt),
                .collect_tax => |amt| writeScalar(buffer, amt),
                .loan => |terms| {
                    storeIntLittle(u128, buffer[0..16], terms.principal);
                    storeIntLittle(i32, buffer[16..20], terms.rate_bps);
                    storeIntLittle(u64, buffer[20..28], terms.duration_seconds);
                    return 28;
                },
            };
        }
    };

    pub const TigerBankMMT = struct {
        npub: [32]u8,
        title: []const u8,
        policy: Policy,
        action: Action,

        pub const max_title_len: usize = 96;
        pub const header_len: usize = 32 + 2 + Policy.encoded_len + 1;
        pub const max_encoded_len: usize = header_len + max_title_len + Action.max_payload_len;

        pub fn encodedLength(self: TigerBankMMT) !usize {
            if (self.title.len > max_title_len) return error.TitleTooLong;
            return header_len + self.title.len + self.action.payloadLength();
        }

        pub fn encode(self: TigerBankMMT, buffer: []u8) ![]const u8 {
            const total = try self.encodedLength();
            if (buffer.len < total) return error.BufferTooSmall;

            var index: usize = 0;
            std.mem.copyForwards(u8, buffer[index .. index + 32], self.npub[0..]);
            index += 32;

            storeIntLittle(u16, buffer[index .. index + 2], @as(u16, @intCast(self.title.len)));
            index += 2;

            std.mem.copyForwards(u8, buffer[index .. index + self.title.len], self.title);
            index += self.title.len;

            Policy.writeInto(self.policy, buffer[index .. index + Policy.encoded_len]);
            index += Policy.encoded_len;

            const tag = std.meta.activeTag(self.action);
            buffer[index] = @intFromEnum(tag);
            index += 1;

            const action_written = self.action.writeInto(buffer[index..]);
            index += action_written;

            return buffer[0..index];
        }
    };

    pub const TigerBankCDN = struct {
        tier: Tier,
        subscriber_npub: [32]u8,
        start_timestamp_seconds: u64,
        seats: u16,
        autopay_enabled: bool,

        pub const encoded_len: usize = 32 + 1 + 8 + 2 + 1;

        pub fn encode(self: TigerBankCDN, buffer: []u8) ![]const u8 {
            if (buffer.len < encoded_len) return error.BufferTooSmall;
            var index: usize = 0;
            std.mem.copyForwards(u8, buffer[index .. index + 32], self.subscriber_npub[0..]);
            index += 32;

            buffer[index] = @intFromEnum(self.tier);
            index += 1;

            storeIntLittle(u64, buffer[index .. index + 8], self.start_timestamp_seconds);
            index += 8;

            storeIntLittle(u16, buffer[index .. index + 2], self.seats);
            index += 2;

            buffer[index] = if (self.autopay_enabled) 1 else 0;
            index += 1;

            return buffer[0..index];
        }
    };

    pub const Tier = enum(u8) {
        basic = 0,
        pro = 1,
        premier = 2,
        ultra = 3,
    };

    pub const TierConfig = struct {
        tier: Tier,
        label: []const u8,
        monthly_bytes: u64,
        price_cents: u32,
        max_endpoints: u16,
    };

    pub const TierCatalog = struct {
        pub const entries = [_]TierConfig{
            .{ .tier = .basic, .label = "basic", .monthly_bytes = 5 * gib(3), .price_cents = 1500, .max_endpoints = 1 },
            .{ .tier = .pro, .label = "pro", .monthly_bytes = 25 * gib(3), .price_cents = 4900, .max_endpoints = 3 },
            .{ .tier = .premier, .label = "premier", .monthly_bytes = 100 * gib(3), .price_cents = 9900, .max_endpoints = 8 },
            .{ .tier = .ultra, .label = "ultra", .monthly_bytes = 400 * gib(3), .price_cents = 19900, .max_endpoints = 16 },
        };

        pub fn find(tier: Tier) TierConfig {
            inline for (entries) |entry| {
                if (entry.tier == tier) return entry;
            }
            return entries[0];
        }
    };

    pub const OptionalModules = struct {
        /// Small optional interface specs. Implementations may layer on top.
        pub const InventoryLedger = struct {
            sku: [16]u8,
            quantity: i32,
            location_code: [8]u8,
        };

        pub const ProofOfSales = struct {
            receipt_id: [16]u8,
            total_cents: u64,
            vegan_certified: bool,
        };

        pub const PayrollSlice = struct {
            employee_id: [16]u8,
            gross_cents: u64,
            hours: u32,
        };
    };

    pub const Envelope = union(enum) {
        tigerbank_mmt: TigerBankMMT,
        tigerbank_cdn: TigerBankCDN,
        optional_inventory: OptionalModules.InventoryLedger,
        optional_sales: OptionalModules.ProofOfSales,
        optional_payroll: OptionalModules.PayrollSlice,

        pub const max_len: usize = SettlementContracts.kind_tag_len + @max(
            TigerBankMMT.max_encoded_len,
            TigerBankCDN.encoded_len,
            @max(
                OptionalModulesEncoded.inventory_len,
                @max(OptionalModulesEncoded.sales_len, OptionalModulesEncoded.payroll_len),
            ),
        );

        pub fn encode(self: Envelope, buffer: []u8) ![]const u8 {
            if (buffer.len < kind_tag_len) return error.BufferTooSmall;
            buffer[0] = @intFromEnum(std.meta.activeTag(self));
            var index: usize = 1;
            const slice = switch (self) {
                .tigerbank_mmt => |mmt| try mmt.encode(buffer[index..]),
                .tigerbank_cdn => |cdn| try cdn.encode(buffer[index..]),
                .optional_inventory => |inv| encodeInventory(inv, buffer[index..]),
                .optional_sales => |sales| encodeSales(sales, buffer[index..]),
                .optional_payroll => |payroll| encodePayroll(payroll, buffer[index..]),
            };
            index += slice.len;
            return buffer[0..index];
        }
    };

    pub const OptionalModulesEncoded = struct {
        pub const inventory_len: usize = 16 + 4 + 8;
        pub const sales_len: usize = 16 + 8 + 1;
        pub const payroll_len: usize = 16 + 8 + 4;
    };

    fn encodeInventory(inv: OptionalModules.InventoryLedger, buffer: []u8) []const u8 {
        std.mem.copyForwards(u8, buffer[0..16], inv.sku[0..]);
        storeIntLittle(i32, buffer[16..20], inv.quantity);
        std.mem.copyForwards(u8, buffer[20..28], inv.location_code[0..]);
        return buffer[0..OptionalModulesEncoded.inventory_len];
    }

    fn encodeSales(s: OptionalModules.ProofOfSales, buffer: []u8) []const u8 {
        std.mem.copyForwards(u8, buffer[0..16], s.receipt_id[0..]);
        storeIntLittle(u64, buffer[16..24], s.total_cents);
        buffer[24] = if (s.vegan_certified) 1 else 0;
        return buffer[0..OptionalModulesEncoded.sales_len];
    }

    fn encodePayroll(p: OptionalModules.PayrollSlice, buffer: []u8) []const u8 {
        std.mem.copyForwards(u8, buffer[0..16], p.employee_id[0..]);
        storeIntLittle(u64, buffer[16..24], p.gross_cents);
        storeIntLittle(u32, buffer[24..28], p.hours);
        return buffer[0..OptionalModulesEncoded.payroll_len];
    }
};

fn writeScalar(buffer: []u8, value: u128) usize {
    storeIntLittle(u128, buffer[0..16], value);
    return 16;
}

fn storeIntLittle(comptime T: type, dest: []u8, value: T) void {
    const info = @typeInfo(T);
    switch (info) {
        .int => |int_info| {
            std.debug.assert(dest.len == int_info.bits / 8);
            var tmp = @as(std.meta.Int(.unsigned, int_info.bits), @bitCast(value));
            var i: usize = 0;
            while (i < dest.len) : (i += 1) {
                dest[i] = @as(u8, @intCast(tmp & 0xff));
                tmp >>= 8;
            }
        },
        else => @compileError("storeIntLittle expects integer type"),
    }
}

fn gib(power: u6) u64 {
    var result: u64 = 1;
    var i: u6 = 0;
    while (i < power) : (i += 1) result *= 1024;
    return result;
}
