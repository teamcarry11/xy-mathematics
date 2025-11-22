const std = @import("std");
const DagCore = @import("dag_core.zig").DagCore;
const BrowserDagIntegration = @import("dream_browser_dag_integration.zig").BrowserDagIntegration;

/// GrainBank Integration: Micropayments and deterministic contracts in browser.
/// ~<~ Glow Airbend: explicit contract state, bounded payments.
/// ~~~~ Glow Waterbend: payments flow deterministically through state machine.
///
/// This implements:
/// - Micropayments in browser (automatic payments for content)
/// - Deterministic contracts (TigerBeetle-style state machine)
/// - Peer-to-peer payments (direct Nostr-based transfers)
/// - State machine execution (bounded, deterministic)
pub const AuroraGrainBank = struct {
    allocator: std.mem.Allocator,
    dag: *DagCore,
    browser_dag: BrowserDagIntegration,
    
    // Bounded: Max 1,000 active contracts
    pub const MAX_ACTIVE_CONTRACTS: u32 = 1_000;
    active_contracts: std.ArrayList(Contract) = undefined,
    
    // Bounded: Max 10,000 pending payments per second
    pub const MAX_PENDING_PAYMENTS: u32 = 10_000;
    pending_payments: std.ArrayList(Payment) = undefined,
    
    // Bounded: Max 100 currencies per user
    pub const MAX_CURRENCIES_PER_USER: u32 = 100;
    
    pub const Contract = struct {
        id: u64, // Unique contract ID
        npub: [32]u8, // Nostr public key (issuer)
        title: []const u8, // Currency title
        policy: Policy,
        state: ContractState,
        balance: u128, // Current balance
        dag_node_id: u32, // DAG node for this contract
    };
    
    pub const Policy = struct {
        base_rate_bps: i32, // Interest rate in basis points
        tax_rate_bps: i32, // Tax rate in basis points
        
        pub const encoded_len: u32 = 8;
    };
    
    pub const ContractState = enum {
        pending, // Contract created, not yet executed
        active, // Contract active, accepting payments
        completed, // Contract completed successfully
        failed, // Contract execution failed
    };
    
    pub const Payment = struct {
        id: u64, // Unique payment ID
        contract_id: u64, // Contract this payment belongs to
        amount: u128, // Payment amount
        from_npub: [32]u8, // Sender's Nostr public key
        to_npub: [32]u8, // Recipient's Nostr public key
        timestamp: u64, // Unix timestamp
        state: PaymentState,
        dag_event_id: u64, // DAG event for this payment
    };
    
    pub const PaymentState = enum {
        pending, // Payment initiated, not yet confirmed
        confirmed, // Payment confirmed and executed
        failed, // Payment failed
    };
    
    pub const Action = union(enum) {
        mint: u128, // Mint currency (increase supply)
        burn: u128, // Burn currency (decrease supply)
        transfer: Transfer, // Transfer between users
        collect_tax: u128, // Collect tax
    };
    
    pub const Transfer = struct {
        amount: u128,
        to_npub: [32]u8,
    };
    
    pub fn init(allocator: std.mem.Allocator, dag: *DagCore) !AuroraGrainBank {
        // Assert: Allocator and DAG must be valid
        std.debug.assert(allocator.ptr != null);
        _ = dag; // DAG is owned by caller
        
        const browser_dag = BrowserDagIntegration.init(allocator, dag);
        
        return AuroraGrainBank{
            .allocator = allocator,
            .dag = dag,
            .browser_dag = browser_dag,
            .active_contracts = std.ArrayList(Contract).init(allocator),
            .pending_payments = std.ArrayList(Payment).init(allocator),
        };
    }
    
    pub fn deinit(self: *AuroraGrainBank) void {
        // Free contract titles
        for (self.active_contracts.items) |*contract| {
            self.allocator.free(contract.title);
        }
        self.active_contracts.deinit();
        
        self.pending_payments.deinit();
        self.browser_dag.deinit();
        self.* = undefined;
    }
    
    /// Create new GrainBank contract (MMT-style currency).
    pub fn create_contract(
        self: *AuroraGrainBank,
        npub: [32]u8,
        title: []const u8,
        policy: Policy,
    ) !u64 {
        // Assert: Title must be valid
        std.debug.assert(title.len > 0);
        std.debug.assert(title.len <= 96); // Bounded title length
        
        // Assert: Bounded contracts
        std.debug.assert(self.active_contracts.items.len < MAX_ACTIVE_CONTRACTS);
        
        // Create DAG node for contract
        var node_data = std.ArrayList(u8).init(self.allocator);
        defer node_data.deinit();
        
        const writer = node_data.writer();
        try writer.print("grainbank:{s}:", .{title});
        try writer.print("npub:{d}:", .{npub[0]});
        try writer.print("rate:{d}:tax:{d}", .{ policy.base_rate_bps, policy.tax_rate_bps });
        
        const dag_node_id = try self.dag.addNode(
            .dom_node, // Use dom_node for browser contracts
            try node_data.toOwnedSlice(),
            .{},
        );
        
        // Create contract
        const contract_id = @intCast(self.active_contracts.items.len + 1);
        const title_copy = try self.allocator.dupe(u8, title);
        errdefer self.allocator.free(title_copy);
        
        try self.active_contracts.append(Contract{
            .id = contract_id,
            .npub = npub,
            .title = title_copy,
            .policy = policy,
            .state = .pending,
            .balance = 0,
            .dag_node_id = dag_node_id,
        });
        
        // Assert: Contract created successfully
        std.debug.assert(self.active_contracts.items.len <= MAX_ACTIVE_CONTRACTS);
        
        return contract_id;
    }
    
    /// Execute contract action (mint, burn, transfer, collect_tax).
    pub fn execute_action(
        self: *AuroraGrainBank,
        contract_id: u64,
        action: Action,
    ) !void {
        // Assert: Contract ID must be valid
        std.debug.assert(contract_id > 0);
        std.debug.assert(contract_id <= self.active_contracts.items.len);
        
        const contract = &self.active_contracts.items[contract_id - 1];
        
        // Assert: Contract must be active
        std.debug.assert(contract.state == .active or contract.state == .pending);
        
        // Execute action based on type
        switch (action) {
            .mint => |amount| {
                // Assert: Amount must be valid
                std.debug.assert(amount > 0);
                
                // Mint currency (increase balance)
                contract.balance +%= amount;
                
                // Create DAG event for mint
                const parent_events = try self.get_latest_parent_events();
                _ = try self.dag.addEvent(
                    .web_request, // Use web_request for payment events
                    contract.dag_node_id,
                    try std.fmt.allocPrint(self.allocator, "mint:{d}", .{amount}),
                    parent_events,
                );
            },
            .burn => |amount| {
                // Assert: Amount must be valid
                std.debug.assert(amount > 0);
                std.debug.assert(amount <= contract.balance);
                
                // Burn currency (decrease balance)
                contract.balance -%= amount;
                
                // Create DAG event for burn
                const parent_events = try self.get_latest_parent_events();
                _ = try self.dag.addEvent(
                    .web_request,
                    contract.dag_node_id,
                    try std.fmt.allocPrint(self.allocator, "burn:{d}", .{amount}),
                    parent_events,
                );
            },
            .transfer => |transfer| {
                // Assert: Transfer amount must be valid
                std.debug.assert(transfer.amount > 0);
                std.debug.assert(transfer.amount <= contract.balance);
                
                // Create peer-to-peer payment
                _ = try self.create_payment(
                    contract_id,
                    transfer.amount,
                    contract.npub,
                    transfer.to_npub,
                );
                
                // Decrease balance (transfer out)
                contract.balance -%= transfer.amount;
            },
            .collect_tax => |amount| {
                // Assert: Tax amount must be valid
                std.debug.assert(amount > 0);
                std.debug.assert(amount <= contract.balance);
                
                // Collect tax (decrease balance, tax goes to issuer)
                contract.balance -%= amount;
                
                // Create DAG event for tax collection
                const parent_events = try self.get_latest_parent_events();
                _ = try self.dag.addEvent(
                    .web_request,
                    contract.dag_node_id,
                    try std.fmt.allocPrint(self.allocator, "tax:{d}", .{amount}),
                    parent_events,
                );
            },
        }
        
        // Activate contract if pending
        if (contract.state == .pending) {
            contract.state = .active;
        }
    }
    
    /// Create peer-to-peer payment.
    pub fn create_payment(
        self: *AuroraGrainBank,
        contract_id: u64,
        amount: u128,
        from_npub: [32]u8,
        to_npub: [32]u8,
    ) !u64 {
        // Assert: Contract ID and amount must be valid
        std.debug.assert(contract_id > 0);
        std.debug.assert(contract_id <= self.active_contracts.items.len);
        std.debug.assert(amount > 0);
        
        // Assert: Bounded pending payments
        std.debug.assert(self.pending_payments.items.len < MAX_PENDING_PAYMENTS);
        
        const contract = &self.active_contracts.items[contract_id - 1];
        
        // Assert: Contract must be active
        std.debug.assert(contract.state == .active);
        std.debug.assert(amount <= contract.balance);
        
        // Create payment
        const payment_id = @intCast(self.pending_payments.items.len + 1);
        const timestamp = std.time.timestamp();
        std.debug.assert(timestamp >= 0);
        const timestamp_u64 = @intCast(timestamp);
        
        // Create DAG event for payment
        const parent_events = try self.get_latest_parent_events();
        const dag_event_id = try self.dag.addEvent(
            .web_request,
            contract.dag_node_id,
            try std.fmt.allocPrint(
                self.allocator,
                "payment:{d}:from:{d}:to:{d}",
                .{ amount, from_npub[0], to_npub[0] },
            ),
            parent_events,
        );
        
        try self.pending_payments.append(Payment{
            .id = payment_id,
            .contract_id = contract_id,
            .amount = amount,
            .from_npub = from_npub,
            .to_npub = to_npub,
            .timestamp = timestamp_u64,
            .state = .pending,
            .dag_event_id = dag_event_id,
        });
        
        // Execute payment immediately (deterministic state machine)
        try self.process_payment(payment_id);
        
        // Assert: Payment created successfully
        std.debug.assert(self.pending_payments.items.len <= MAX_PENDING_PAYMENTS);
        
        return payment_id;
    }
    
    /// Process payment (TigerBeetle-style deterministic state machine).
    fn process_payment(self: *AuroraGrainBank, payment_id: u64) !void {
        // Assert: Payment ID must be valid
        std.debug.assert(payment_id > 0);
        std.debug.assert(payment_id <= self.pending_payments.items.len);
        
        const payment = &self.pending_payments.items[payment_id - 1];
        
        // Assert: Payment must be pending
        std.debug.assert(payment.state == .pending);
        
        // Execute payment (deterministic)
        // In a real implementation, this would:
        // 1. Verify sender has sufficient balance
        // 2. Transfer amount from sender to recipient
        // 3. Update contract balance
        // 4. Confirm payment
        
        // For now, mark as confirmed (deterministic execution)
        payment.state = .confirmed;
        
        // Assert: Payment must be confirmed
        std.debug.assert(payment.state == .confirmed);
    }
    
    /// Process all pending payments (batch processing).
    pub fn process_pending_payments(self: *AuroraGrainBank) !void {
        // Assert: Payments must be within bounds
        std.debug.assert(self.pending_payments.items.len <= MAX_PENDING_PAYMENTS);
        
        // Process payments in order (deterministic)
        for (self.pending_payments.items) |*payment| {
            if (payment.state == .pending) {
                try self.process_payment(payment.id);
            }
        }
        
        // Process DAG events (TigerBeetle-style state machine)
        try self.dag.processEvents();
    }
    
    /// Get contract by ID.
    pub fn get_contract(self: *AuroraGrainBank, contract_id: u64) ?*Contract {
        // Assert: Contract ID must be valid
        if (contract_id == 0 or contract_id > self.active_contracts.items.len) {
            return null;
        }
        
        return &self.active_contracts.items[contract_id - 1];
    }
    
    /// Get payment by ID.
    pub fn get_payment(self: *AuroraGrainBank, payment_id: u64) ?*Payment {
        // Assert: Payment ID must be valid
        if (payment_id == 0 or payment_id > self.pending_payments.items.len) {
            return null;
        }
        
        return &self.pending_payments.items[payment_id - 1];
    }
    
    /// Get latest parent events for HashDAG-style ordering.
    fn get_latest_parent_events(self: *AuroraGrainBank) ![]const u64 {
        // Get latest events from DAG (for parent references)
        // Bounded: Max 10 parent events
        const max_parents: u32 = 10;
        var parents = std.ArrayList(u64).init(self.allocator);
        errdefer parents.deinit();
        
        // Get latest events (simplified: get from pending events)
        const count = @min(self.dag.pending_events_len, max_parents);
        for (0..count) |i| {
            const event = self.dag.pending_events[i];
            try parents.append(event.id);
        }
        
        return try parents.toOwnedSlice();
    }
    
    /// Get all active contracts (for browser display).
    pub fn get_active_contracts(self: *AuroraGrainBank) []const Contract {
        return self.active_contracts.items;
    }
    
    /// Get all pending payments (for browser display).
    pub fn get_pending_payments(self: *AuroraGrainBank) []const Payment {
        return self.pending_payments.items;
    }
};

test "grainbank lifecycle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    // Assert: GrainBank initialized
    std.debug.assert(grainbank.active_contracts.items.len == 0);
    std.debug.assert(grainbank.pending_payments.items.len == 0);
}

test "grainbank create contract" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    var npub: [32]u8 = undefined;
    @memset(&npub, 0x42);
    
    const contract_id = try grainbank.create_contract(
        npub,
        "TestCurrency",
        .{ .base_rate_bps = 100, .tax_rate_bps = 50 },
    );
    
    // Assert: Contract created
    std.debug.assert(contract_id > 0);
    std.debug.assert(grainbank.active_contracts.items.len == 1);
    
    const contract = grainbank.get_contract(contract_id);
    std.debug.assert(contract != null);
    std.debug.assert(contract.?.state == .pending);
}

test "grainbank execute mint" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    var npub: [32]u8 = undefined;
    @memset(&npub, 0x42);
    
    const contract_id = try grainbank.create_contract(
        npub,
        "TestCurrency",
        .{ .base_rate_bps = 100, .tax_rate_bps = 50 },
    );
    
    // Execute mint action
    try grainbank.execute_action(contract_id, .{ .mint = 1000 });
    
    // Assert: Balance increased
    const contract = grainbank.get_contract(contract_id);
    std.debug.assert(contract != null);
    std.debug.assert(contract.?.balance == 1000);
    std.debug.assert(contract.?.state == .active);
}

