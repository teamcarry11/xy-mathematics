# Payment/Vault/Bank Storage Schema Design

**Date**: 2025-12-28-230000-pst  
**Agent**: Grain Silo Agent (Database)  
**Status**: Design Complete — Ready for Core Agent Coordination

---

## Overview

This document defines the storage schema design for Grain Passwords, Grain Pay, and Grainbank modules. The design follows the same pattern as SLC integration helpers (`NostrProfileStorage`, `DagWebsiteStorage`, `WorkspaceFileStorage`) with key-value storage, validation, and helper functions.

**Modules**:
1. **Grain Passwords** (`grain_passwords`): Encrypted secret storage
2. **Grain Pay** (`grain_pay`): Payment processing and transaction history
3. **Grainbank** (`grainbank`): Currency issuance and account balances

---

## Design Principles

**Key-Value Storage Pattern**:
- All data stored as key-value pairs in Silo Agent database
- Key format: `{prefix}:{type}:{identifier}` (e.g., `password:secret:{secret_id}`)
- Value format: JSON-encoded data structures
- Encryption handled by Grain Passwords module (encrypted before storage)

**Helper Functions**:
- Storage helpers similar to SLC integration helpers
- Full CRUD operations (store, get, update, delete)
- List and count operations
- Pagination support for large datasets
- Search functionality
- Batch operations for bulk loading
- Validation helpers for identifiers

**Grain Style Compliance**:
- `grain_case` function names
- Explicit `u32`/`u64` types (not `usize`/`isize`)
- Bounded allocations (`MAX_` constants)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 103 characters per line

---

## Module 1: Grain Passwords Storage Schema

### Key Formats

**Encrypted Secrets**:
- Key format: `password:secret:{secret_id}`
- `secret_id`: Hex string (max 64 chars), unique identifier for secret
- Example: `password:secret:abc123def456...`

**Key Derivation Parameters**:
- Key format: `password:key:{key_id}`
- `key_id`: Hex string (max 64 chars), unique identifier for key
- Example: `password:key:key123def456...`

**Audit Logs**:
- Key format: `password:audit:{audit_id}`
- `audit_id`: Hex string (max 64 chars), unique identifier for audit entry
- Example: `password:audit:audit123def456...`

### Data Structures

**Encrypted Secret Value** (JSON):
```json
{
  "encrypted_data": "base64_encoded_encrypted_data",
  "metadata": {
    "name": "secret_name",
    "type": "api_key|password|token|credential",
    "version": 1,
    "created_at": "2025-12-28T23:00:00Z",
    "updated_at": "2025-12-28T23:00:00Z"
  },
  "encryption_params": {
    "algorithm": "AEAD",
    "key_id": "key123def456...",
    "nonce": "base64_encoded_nonce"
  }
}
```

**Key Derivation Parameters Value** (JSON):
```json
{
  "key_id": "key123def456...",
  "derivation_params": {
    "algorithm": "PBKDF2|Argon2",
    "iterations": 100000,
    "salt": "base64_encoded_salt",
    "key_length": 32
  },
  "created_at": "2025-12-28T23:00:00Z"
}
```

**Audit Log Value** (JSON):
```json
{
  "audit_id": "audit123def456...",
  "secret_id": "abc123def456...",
  "action": "access|create|update|delete",
  "user_id": "user123...",
  "timestamp": "2025-12-28T23:00:00Z",
  "ip_address": "192.168.1.1",
  "result": "success|failure"
}
```

### Storage Helper API

**PasswordStorage Helper**:
```zig
pub const PasswordStorage = struct {
    storage_engine: *storage_engine.StorageEngine,
    
    // Initialize password storage
    pub fn init(storage: *storage_engine.StorageEngine) PasswordStorage;
    
    // Store encrypted secret
    pub fn store_secret(
        self: *PasswordStorage,
        secret_id: []const u8,
        encrypted_data: []const u8,
        metadata: []const u8,
    ) !u64;
    
    // Retrieve encrypted secret
    pub fn get_secret(
        self: *PasswordStorage,
        secret_id: []const u8,
    ) ?*storage_engine.Record;
    
    // Update encrypted secret
    pub fn update_secret(
        self: *PasswordStorage,
        secret_id: []const u8,
        encrypted_data: []const u8,
        metadata: []const u8,
    ) !void;
    
    // Delete encrypted secret
    pub fn delete_secret(
        self: *PasswordStorage,
        secret_id: []const u8,
    ) !void;
    
    // List all secrets (paginated)
    pub fn list_secrets_paginated(
        self: *PasswordStorage,
        page: u32,
        page_size: u32,
        output_secrets: []*storage_engine.Record,
    ) !u32;
    
    // Count secrets
    pub fn count_secrets(self: *PasswordStorage) !u64;
    
    // Search secrets by name or type
    pub fn search_secrets(
        self: *PasswordStorage,
        query: []const u8,
        output_secrets: []*storage_engine.Record,
    ) !u32;
    
    // Batch store secrets
    pub fn batch_store_secrets(
        self: *PasswordStorage,
        secret_ids: []const []const u8,
        encrypted_data: []const []const u8,
        metadata: []const []const u8,
        output_record_ids: []u64,
    ) !u32;
    
    // Store key derivation parameters
    pub fn store_key_params(
        self: *PasswordStorage,
        key_id: []const u8,
        derivation_params: []const u8,
    ) !u64;
    
    // Retrieve key derivation parameters
    pub fn get_key_params(
        self: *PasswordStorage,
        key_id: []const u8,
    ) ?*storage_engine.Record;
    
    // Store audit log entry
    pub fn store_audit_log(
        self: *PasswordStorage,
        audit_id: []const u8,
        secret_id: []const u8,
        action: []const u8,
        user_id: []const u8,
        audit_data: []const u8,
    ) !u64;
    
    // List audit logs for secret (paginated)
    pub fn list_audit_logs_paginated(
        self: *PasswordStorage,
        secret_id: []const u8,
        page: u32,
        page_size: u32,
        output_logs: []*storage_engine.Record,
    ) !u32;
};
```

### Validation Constants

```zig
pub const MAX_SECRET_ID_LEN: u32 = 64;
pub const MAX_KEY_ID_LEN: u32 = 64;
pub const MAX_AUDIT_ID_LEN: u32 = 64;
pub const MAX_SECRET_NAME_LEN: u32 = 256;
pub const MAX_SECRET_TYPE_LEN: u32 = 32;
```

### Validation Functions

```zig
pub fn validate_secret_id(secret_id: []const u8) bool;
pub fn validate_key_id(key_id: []const u8) bool;
pub fn validate_audit_id(audit_id: []const u8) bool;
pub fn validate_secret_name(name: []const u8) bool;
pub fn validate_secret_type(secret_type: []const u8) bool;
```

---

## Module 2: Grain Pay Storage Schema

### Key Formats

**Payment Methods**:
- Key format: `pay:method:{method_id}`
- `method_id`: Hex string (max 64 chars), unique identifier for payment method
- Example: `pay:method:method123def456...`

**Transactions**:
- Key format: `pay:transaction:{transaction_id}`
- `transaction_id`: Hex string (max 64 chars), unique identifier for transaction
- Example: `pay:transaction:tx123def456...`

**Webhook Logs**:
- Key format: `pay:webhook:{webhook_id}`
- `webhook_id`: Hex string (max 64 chars), unique identifier for webhook event
- Example: `pay:webhook:webhook123def456...`

### Data Structures

**Payment Method Value** (JSON):
```json
{
  "method_id": "method123def456...",
  "user_id": "user123...",
  "type": "card|bank_account|digital_wallet",
  "encrypted_credentials": "base64_encoded_encrypted_credentials",
  "metadata": {
    "last4": "1234",
    "brand": "visa|mastercard|amex",
    "exp_month": 12,
    "exp_year": 2025
  },
  "created_at": "2025-12-28T23:00:00Z",
  "updated_at": "2025-12-28T23:00:00Z"
}
```

**Transaction Value** (JSON):
```json
{
  "transaction_id": "tx123def456...",
  "method_id": "method123def456...",
  "user_id": "user123...",
  "amount": 10000,
  "currency": "USD",
  "status": "pending|completed|failed|refunded",
  "type": "charge|refund|transfer",
  "processor": "stripe|paypal|square",
  "processor_transaction_id": "processor_tx_123",
  "metadata": {
    "description": "Payment for service",
    "invoice_id": "inv123..."
  },
  "created_at": "2025-12-28T23:00:00Z",
  "updated_at": "2025-12-28T23:00:00Z",
  "completed_at": "2025-12-28T23:01:00Z"
}
```

**Webhook Log Value** (JSON):
```json
{
  "webhook_id": "webhook123def456...",
  "transaction_id": "tx123def456...",
  "event_type": "payment.succeeded|payment.failed|refund.completed",
  "processor": "stripe|paypal|square",
  "payload": "base64_encoded_webhook_payload",
  "processed": true,
  "timestamp": "2025-12-28T23:00:00Z"
}
```

### Storage Helper API

**PaymentStorage Helper**:
```zig
pub const PaymentStorage = struct {
    storage_engine: *storage_engine.StorageEngine,
    
    // Initialize payment storage
    pub fn init(storage: *storage_engine.StorageEngine) PaymentStorage;
    
    // Store payment method
    pub fn store_payment_method(
        self: *PaymentStorage,
        method_id: []const u8,
        user_id: []const u8,
        method_data: []const u8,
    ) !u64;
    
    // Retrieve payment method
    pub fn get_payment_method(
        self: *PaymentStorage,
        method_id: []const u8,
    ) ?*storage_engine.Record;
    
    // Update payment method
    pub fn update_payment_method(
        self: *PaymentStorage,
        method_id: []const u8,
        method_data: []const u8,
    ) !void;
    
    // Delete payment method
    pub fn delete_payment_method(
        self: *PaymentStorage,
        method_id: []const u8,
    ) !void;
    
    // List payment methods for user (paginated)
    pub fn list_payment_methods_paginated(
        self: *PaymentStorage,
        user_id: []const u8,
        page: u32,
        page_size: u32,
        output_methods: []*storage_engine.Record,
    ) !u32;
    
    // Store transaction
    pub fn store_transaction(
        self: *PaymentStorage,
        transaction_id: []const u8,
        transaction_data: []const u8,
    ) !u64;
    
    // Retrieve transaction
    pub fn get_transaction(
        self: *PaymentStorage,
        transaction_id: []const u8,
    ) ?*storage_engine.Record;
    
    // Update transaction status
    pub fn update_transaction_status(
        self: *PaymentStorage,
        transaction_id: []const u8,
        status: []const u8,
        updated_data: []const u8,
    ) !void;
    
    // List transactions for user (paginated)
    pub fn list_transactions_paginated(
        self: *PaymentStorage,
        user_id: []const u8,
        page: u32,
        page_size: u32,
        output_transactions: []*storage_engine.Record,
    ) !u32;
    
    // Search transactions by status, type, or date range
    pub fn search_transactions(
        self: *PaymentStorage,
        user_id: []const u8,
        query: []const u8,
        output_transactions: []*storage_engine.Record,
    ) !u32;
    
    // Count transactions for user
    pub fn count_transactions(
        self: *PaymentStorage,
        user_id: []const u8,
    ) !u64;
    
    // Batch store transactions
    pub fn batch_store_transactions(
        self: *PaymentStorage,
        transaction_ids: []const []const u8,
        transaction_data: []const []const u8,
        output_record_ids: []u64,
    ) !u32;
    
    // Store webhook log
    pub fn store_webhook_log(
        self: *PaymentStorage,
        webhook_id: []const u8,
        webhook_data: []const u8,
    ) !u64;
    
    // Retrieve webhook log
    pub fn get_webhook_log(
        self: *PaymentStorage,
        webhook_id: []const u8,
    ) ?*storage_engine.Record;
    
    // List webhook logs for transaction (paginated)
    pub fn list_webhook_logs_paginated(
        self: *PaymentStorage,
        transaction_id: []const u8,
        page: u32,
        page_size: u32,
        output_logs: []*storage_engine.Record,
    ) !u32;
};
```

### Validation Constants

```zig
pub const MAX_METHOD_ID_LEN: u32 = 64;
pub const MAX_TRANSACTION_ID_LEN: u32 = 64;
pub const MAX_WEBHOOK_ID_LEN: u32 = 64;
pub const MAX_PAYMENT_TYPE_LEN: u32 = 32;
pub const MAX_TRANSACTION_STATUS_LEN: u32 = 32;
pub const MAX_CURRENCY_LEN: u32 = 8;
```

### Validation Functions

```zig
pub fn validate_method_id(method_id: []const u8) bool;
pub fn validate_transaction_id(transaction_id: []const u8) bool;
pub fn validate_webhook_id(webhook_id: []const u8) bool;
pub fn validate_payment_type(payment_type: []const u8) bool;
pub fn validate_transaction_status(status: []const u8) bool;
pub fn validate_currency(currency: []const u8) bool;
```

---

## Module 3: Grainbank Storage Schema

### Key Formats

**Accounts**:
- Key format: `bank:account:{account_id}`
- `account_id`: Hex string (max 64 chars), unique identifier for account
- Example: `bank:account:account123def456...`

**Currencies**:
- Key format: `bank:currency:{currency_id}`
- `currency_id`: Hex string (max 64 chars), unique identifier for currency
- Example: `bank:currency:currency123def456...`

**Transfers**:
- Key format: `bank:transfer:{transfer_id}`
- `transfer_id`: Hex string (max 64 chars), unique identifier for transfer
- Example: `bank:transfer:transfer123def456...`

**Account Balances** (by currency):
- Key format: `bank:balance:{account_id}:{currency_id}`
- `account_id`: Hex string (max 64 chars)
- `currency_id`: Hex string (max 64 chars)
- Example: `bank:balance:account123def456...:currency123def456...`

### Data Structures

**Account Value** (JSON):
```json
{
  "account_id": "account123def456...",
  "user_id": "user123...",
  "created_at": "2025-12-28T23:00:00Z",
  "updated_at": "2025-12-28T23:00:00Z",
  "metadata": {
    "name": "Primary Account",
    "type": "personal|business|community"
  }
}
```

**Currency Value** (JSON):
```json
{
  "currency_id": "currency123def456...",
  "issuer_id": "user123...",
  "name": "Community Coin",
  "symbol": "CC",
  "decimals": 2,
  "total_supply": 1000000,
  "metadata": {
    "description": "Community currency for local economy",
    "icon": "base64_encoded_icon",
    "website": "https://example.com"
  },
  "created_at": "2025-12-28T23:00:00Z",
  "updated_at": "2025-12-28T23:00:00Z"
}
```

**Transfer Value** (JSON):
```json
{
  "transfer_id": "transfer123def456...",
  "from_account": "account123def456...",
  "to_account": "account456def789...",
  "currency_id": "currency123def456...",
  "amount": 10000,
  "status": "pending|completed|failed",
  "metadata": {
    "description": "Payment for service",
    "reference": "ref123..."
  },
  "created_at": "2025-12-28T23:00:00Z",
  "completed_at": "2025-12-28T23:01:00Z"
}
```

**Account Balance Value** (JSON):
```json
{
  "account_id": "account123def456...",
  "currency_id": "currency123def456...",
  "balance": 50000,
  "updated_at": "2025-12-28T23:00:00Z"
}
```

### Storage Helper API

**BankStorage Helper**:
```zig
pub const BankStorage = struct {
    storage_engine: *storage_engine.StorageEngine,
    
    // Initialize bank storage
    pub fn init(storage: *storage_engine.StorageEngine) BankStorage;
    
    // Store account
    pub fn store_account(
        self: *BankStorage,
        account_id: []const u8,
        user_id: []const u8,
        account_data: []const u8,
    ) !u64;
    
    // Retrieve account
    pub fn get_account(
        self: *BankStorage,
        account_id: []const u8,
    ) ?*storage_engine.Record;
    
    // List accounts for user (paginated)
    pub fn list_accounts_paginated(
        self: *BankStorage,
        user_id: []const u8,
        page: u32,
        page_size: u32,
        output_accounts: []*storage_engine.Record,
    ) !u32;
    
    // Store currency
    pub fn store_currency(
        self: *BankStorage,
        currency_id: []const u8,
        currency_data: []const u8,
    ) !u64;
    
    // Retrieve currency
    pub fn get_currency(
        self: *BankStorage,
        currency_id: []const u8,
    ) ?*storage_engine.Record;
    
    // List currencies (paginated)
    pub fn list_currencies_paginated(
        self: *BankStorage,
        page: u32,
        page_size: u32,
        output_currencies: []*storage_engine.Record,
    ) !u32;
    
    // Search currencies by name or issuer
    pub fn search_currencies(
        self: *BankStorage,
        query: []const u8,
        output_currencies: []*storage_engine.Record,
    ) !u32;
    
    // Store transfer
    pub fn store_transfer(
        self: *BankStorage,
        transfer_id: []const u8,
        transfer_data: []const u8,
    ) !u64;
    
    // Retrieve transfer
    pub fn get_transfer(
        self: *BankStorage,
        transfer_id: []const u8,
    ) ?*storage_engine.Record;
    
    // Update transfer status
    pub fn update_transfer_status(
        self: *BankStorage,
        transfer_id: []const u8,
        status: []const u8,
        updated_data: []const u8,
    ) !void;
    
    // List transfers for account (paginated)
    pub fn list_transfers_paginated(
        self: *BankStorage,
        account_id: []const u8,
        page: u32,
        page_size: u32,
        output_transfers: []*storage_engine.Record,
    ) !u32;
    
    // Store account balance
    pub fn store_balance(
        self: *BankStorage,
        account_id: []const u8,
        currency_id: []const u8,
        balance: i64,
    ) !u64;
    
    // Retrieve account balance
    pub fn get_balance(
        self: *BankStorage,
        account_id: []const u8,
        currency_id: []const u8,
    ) ?*storage_engine.Record;
    
    // Update account balance (atomic operation)
    pub fn update_balance(
        self: *BankStorage,
        account_id: []const u8,
        currency_id: []const u8,
        balance: i64,
    ) !void;
    
    // List balances for account (paginated)
    pub fn list_balances_paginated(
        self: *BankStorage,
        account_id: []const u8,
        page: u32,
        page_size: u32,
        output_balances: []*storage_engine.Record,
    ) !u32;
    
    // Batch store transfers
    pub fn batch_store_transfers(
        self: *BankStorage,
        transfer_ids: []const []const u8,
        transfer_data: []const []const u8,
        output_record_ids: []u64,
    ) !u32;
};
```

### Validation Constants

```zig
pub const MAX_ACCOUNT_ID_LEN: u32 = 64;
pub const MAX_CURRENCY_ID_LEN: u32 = 64;
pub const MAX_TRANSFER_ID_LEN: u32 = 64;
pub const MAX_CURRENCY_NAME_LEN: u32 = 256;
pub const MAX_CURRENCY_SYMBOL_LEN: u32 = 16;
pub const MAX_TRANSFER_STATUS_LEN: u32 = 32;
```

### Validation Functions

```zig
pub fn validate_account_id(account_id: []const u8) bool;
pub fn validate_currency_id(currency_id: []const u8) bool;
pub fn validate_transfer_id(transfer_id: []const u8) bool;
pub fn validate_currency_name(name: []const u8) bool;
pub fn validate_currency_symbol(symbol: []const u8) bool;
pub fn validate_transfer_status(status: []const u8) bool;
```

---

## Encryption Requirements

**Grain Passwords Module**:
- All secrets encrypted before storage using authenticated encryption (AEAD)
- Encryption keys derived from master secrets (never stored)
- Encrypted data stored as base64-encoded strings in JSON values
- Encryption parameters (algorithm, key_id, nonce) stored in metadata

**Grain Pay Module**:
- Payment credentials encrypted by Grain Passwords before storage
- Transaction data stored in plaintext (non-sensitive metadata only)
- Webhook payloads stored as base64-encoded strings

**Grainbank Module**:
- Account and currency data stored in plaintext (non-sensitive)
- Transfer data stored in plaintext (non-sensitive metadata)
- Balance data stored in plaintext (public information)

---

## Integration Patterns

**Grain Passwords Integration**:
- Grain Passwords encrypts secrets before calling Silo Agent
- Silo Agent stores encrypted data as-is (no additional encryption)
- Grain Passwords retrieves encrypted data and decrypts after retrieval

**Grain Pay Integration**:
- Grain Pay uses Grain Passwords to encrypt payment credentials
- Grain Pay stores encrypted credentials via PasswordStorage helper
- Grain Pay stores transaction metadata via PaymentStorage helper

**Grainbank Integration**:
- Grainbank stores account, currency, and transfer data via BankStorage helper
- Balance updates use atomic operations (ACID transactions)
- Transfer processing requires balance validation before completion

---

## Index Recommendations

**Grain Passwords**:
- Index on `password:secret:*` keys for fast secret lookup
- Index on metadata fields (name, type) for search operations
- Index on audit log keys for chronological access

**Grain Pay**:
- Index on `pay:method:*` keys for user payment method lookup
- Index on `pay:transaction:*` keys for transaction history
- Index on user_id in transaction metadata for user transaction queries
- Index on status in transaction metadata for status-based queries

**Grainbank**:
- Index on `bank:account:*` keys for account lookup
- Index on `bank:currency:*` keys for currency lookup
- Index on `bank:balance:*` keys for balance queries
- Index on user_id in account metadata for user account queries
- Index on issuer_id in currency metadata for issuer currency queries

---

## Implementation Timeline

**Phase 1: Storage Schema Design** (Current):
- ✅ Storage schema design complete
- ⏳ Core Agent coordination on schema approval
- ⏳ Storage helper API design review

**Phase 2: Storage Helpers Implementation** (After Core Agent Phase 1):
- Implement `PasswordStorage` helper
- Implement `PaymentStorage` helper
- Implement `BankStorage` helper
- Comprehensive tests for all helpers

**Phase 3: Integration Testing** (After Core Agent Phase 2):
- Integration testing with Grain Passwords module
- Integration testing with Grain Pay module
- Integration testing with Grainbank module

---

## Next Steps

1. **IMMEDIATE**: Coordinate with Core Agent on storage schema design approval
2. **SHORT-TERM**: Review storage helper API design with Core Agent
3. **MEDIUM-TERM**: Implement storage helpers once Core Agent begins Phase 1
4. **MEDIUM-TERM**: Integration testing with Core Agent modules

---

**Date**: 2025-12-28-230000-pst  
**Status**: Design Complete — Ready for Core Agent Coordination
