# Grain Database File Format Specification

**Version**: 1.0  
**Date**: 2025-12-07-042255-pst  
**Agent**: Grain Silo Agent

---

## Overview

The Grain Database file format provides a page-based storage system for persistent database files. The format supports ACID transactions, efficient queries via indexes, and data protection via backups.

---

## File Structure

### File Header (64 bytes)

Located at the start of the database file:

```
Offset  Size  Field           Description
------  ----  --------------  -----------------------------------------
0       4     magic           Magic number: "GDBF" (0x47444246)
4       4     version         Format version (currently 1)
8       4     page_size       Page size in bytes (4096)
12      4     total_pages     Total number of pages in file
16      32    checksum        SHA-256 checksum of header
48      8     created_at      Unix timestamp of file creation
56      8     updated_at      Unix timestamp of last update
```

**Total Header Size**: 64 bytes

### Page Layout

Each page is 4096 bytes (4KB) with the following structure:

```
Offset  Size  Field           Description
------  ----  --------------  -----------------------------------------
0       4     page_id         Page identifier (0-based)
4       4     page_type       Page type (data, index, free)
8       4     record_count    Number of records in page
12      4     free_space      Free space in bytes
16      4076  data            Page data (records or index entries)
4080    16    reserved        Reserved for future use
```

**Page Types**:
- `0x00`: Data page (contains records)
- `0x01`: Index page (contains index entries)
- `0x02`: Free page (available for allocation)

### Record Format

Records are stored in binary format within data pages:

```
Offset  Size  Field           Description
------  ----  --------------  -----------------------------------------
0       8     record_id       Unique record identifier
8       4     key_len         Length of key in bytes
12      8     value_len       Length of value in bytes
20      8     created_at      Unix timestamp of creation
28      8     updated_at      Unix timestamp of last update
36      N     key             Key data (variable length)
36+N    M     value           Value data (variable length)
```

**Record Header Size**: 36 bytes  
**Total Record Size**: 36 + key_len + value_len bytes

---

## File Operations

### Creating a Database File

1. Write file header with magic number "GDBF"
2. Set version to 1
3. Set page_size to 4096
4. Initialize total_pages to 0
5. Calculate and store header checksum
6. Set created_at and updated_at timestamps

### Opening a Database File

1. Read and validate file header
2. Verify magic number matches "GDBF"
3. Verify version is supported (currently 1)
4. Verify page_size matches expected value (4096)
5. Verify header checksum
6. Load page metadata

### Writing Records

1. Serialize record to binary format
2. Find available page with sufficient free space
3. Write record to page at appropriate offset
4. Update page record_count and free_space
5. Mark page as dirty
6. Calculate and update page checksum
7. Update file header updated_at timestamp

### Reading Records

1. Locate record by record_id (via index or page scan)
2. Read record from page at calculated offset
3. Deserialize record from binary format
4. Verify record integrity (checksum validation)

---

## Index File Format

Index files use the same page structure but store index entries:

```
Offset  Size  Field           Description
------  ----  --------------  -----------------------------------------
0       8     record_id       Record identifier
8       4     key_len         Length of index key
12      4     value_len       Length of index value
16      N     key             Index key data
16+N    M     value           Index value data
```

---

## Backup File Format

Backup files contain:
1. Backup metadata header
2. Complete database file copy
3. WAL log entries (if incremental)
4. Backup checksum

---

## Constraints

- Maximum file size: 1TB (256 million pages)
- Maximum page size: 4096 bytes
- Maximum records per page: Variable (depends on record size)
- Maximum key length: 1024 bytes
- Maximum value length: 1GB (stored across multiple pages)

---

## Version History

- **Version 1.0** (2025-12-07-042255-pst): Initial specification

---

## References

- Grain Core File Storage: `src/grain_core/file_storage.zig`
- Record Serialization: `src/grain_database/record_serialization.zig`
- Persistence Manager: `src/grain_database/persistence.zig`

