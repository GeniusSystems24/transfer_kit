# Contract: Public API Changes (2.1.0+1 → 3.0.0)

**Phase 1 output** | **Date**: 2026-05-07 | **Plan**: [../plan.md](../plan.md)

This document is the authoritative record of what is removed, what is added, and what is preserved. Use it to write the migration guide and CHANGELOG entry.

---

## Removed Public API Surface

### FileTask members

| Member | Type | Reason |
| --- | --- | --- |
| `task` field (`Task?`) | Firebase `UploadTask \| DownloadTask` | Firebase-specific; driver manages task internally |
| `firebaseTask({bool justCheck})` | Method returning Firebase `Task?` | Firebase-specific |
| `reference` | Property returning Firebase `Reference` | Firebase-specific |
| `.upload(UploadTask? task)` | Named constructor variant | Firebase-typed parameter |

### Extension methods

| Method | Extension | Reason |
| --- | --- | --- |
| `toTimestamp()` | `DateTimeExtension` | Firestore `Timestamp` type |
| `objectToTimestamp()` | `DynamicExtension` | Firestore `Timestamp` type |
| `objectToDateTime()` (Firestore overload) | `DynamicExtension` | Firestore `Timestamp` input |
| `getDocumentReference(tag)` | `MapExtension` | Firestore `DocumentReference` type |
| `getTimestamp(tag)` | `MapExtension` | Firestore `Timestamp` type |
| `mapCanConvertToFirebase()` | `MapExtension` | Firestore-specific serialization |
| Firebase branches of `mapCanConvertToJson()` | `MapExtension` | Firestore type handling |
| `GeoPointExtension` (entire extension) | — | Extends Firestore `GeoPoint` type |

### Deleted files (not exported, but removed from package)

| File | Replacement |
| --- | --- |
| `lib/src/repository/firebase_file_repository.dart` | `TransferDriver` interface |
| `lib/src/repository/firebase_storage_factory.dart` | `TransferDriver` interface |
| `lib/src/core/extension/geo_point_extension.dart` | No replacement (Firestore utility) |

### Removed pubspec.yaml dependencies

| Package | Version removed |
| --- | --- |
| `firebase_storage` | `^12.0.0` |
| `cloud_firestore` | `^5.0.0` |

---

## Added Public API Surface

### New types (all exported from `lib/transfer_kit.dart`)

| Type | Kind | Purpose |
| --- | --- | --- |
| `TransferDriver` | Abstract interface | Core provider abstraction |
| `TransferCapabilities` | Immutable class | Driver capability declaration |
| `DownloadRequest` | Immutable class | Describes a download operation |
| `UploadRequest` | Immutable class | Describes an upload operation |
| `TransferProgressEvent` | Sealed class | Base type for driver stream events |
| `TransferProgressUpdate` | Final class (subtype) | Intermediate progress event |
| `TransferCompleted` | Final class (subtype) | Terminal success event |
| `TransferFailed` | Final class (subtype) | Terminal failure event |
| `UnsupportedCapabilityException` | Exception class | Thrown for unsupported operations |
| `HttpDownloadDriver` | Concrete driver | Built-in HTTP/HTTPS download driver |
| `LocalFileCopyDriver` | Concrete driver | Built-in on-device file copy driver |

### Modified initialization API

Before (Firebase-coupled, no driver injection):
```dart
await TransferKitConfig.init(/* Firebase-coupled config */);
```

After (provider-agnostic, driver required):
```dart
await TransferKitConfig.init(
  driver: HttpDownloadDriver(
    headers: {'Authorization': 'Bearer $token'},
  ),
);
```

---

## Preserved Public API Surface

Everything below is unchanged in 3.0.0.

### Models

- `FileTask` (minus removed members above)
- `FileTaskState` enum (all values preserved: `waiting`, `running`, `paused`, `completed`, `error`, `cancelled`, `cached`)
- `FileException` and all subtypes
- `FilePathAndURL`
- `MediaMetadata`
- `MultiUploadFileTask`
- `MultiDownloadFileTask`

### Repositories

- `FileTaskRepository` (public method signatures unchanged)
- `FilePathAndURLRepository` (unchanged)
- `BackgroundTaskRepository` (unchanged)

### Services

- `TaskManagementService` (unchanged)
- `MetadataExtractionService` (unchanged)

### Configuration

- `FileManagementConfig` (driver injection added; all existing options preserved)

### Extensions (remaining methods)

- `DateTimeExtension` — all methods except `toTimestamp()`
- `DynamicExtension` — all methods except Firebase-specific overloads
- `MapExtension` — all methods except Firebase-specific methods
- `ListExtension`, `NumExtension`, `StringExtension`, `FilePathExtension` — unchanged

### Widgets (all preserved)

All widget exports in `lib/transfer_kit.dart` are unchanged. No widget has Firebase-specific constructor parameters.

---

## Migration Summary for CHANGELOG

```
## [3.0.0] - 2026-05-07

### Breaking Changes

- **Firebase removed**: `transfer_kit` no longer depends on `firebase_storage` or
  `cloud_firestore`. Remove these from your `pubspec.yaml` if added solely for TransferKit.
- **Driver injection required**: `TransferKitConfig.init()` now requires a `driver`
  parameter. There is no default Firebase driver. See MIGRATION.md.
- **FileTask**: Removed `task`, `firebaseTask()`, `reference`, and the
  `.upload(UploadTask?)` constructor.
- **Extensions**: Removed `toTimestamp()`, `objectToTimestamp()`,
  `getDocumentReference()`, `getTimestamp()`, `mapCanConvertToFirebase()`,
  and `GeoPointExtension`.

### Added

- `TransferDriver` abstract interface — implement to use any storage backend.
- `TransferCapabilities` — capability declaration for drivers.
- `DownloadRequest` / `UploadRequest` — generic transfer request types.
- `TransferProgressEvent` sealed class hierarchy (`TransferProgressUpdate`,
  `TransferCompleted`, `TransferFailed`).
- `UnsupportedCapabilityException` — thrown when a driver capability is not supported.
- `HttpDownloadDriver` — built-in HTTP/HTTPS download driver.
- `LocalFileCopyDriver` — built-in on-device file copy driver (also serves as
  reference implementation for custom driver authors).

### Migration

See [MIGRATION.md](MIGRATION.md) for a complete guide including Firebase adapter example.
```
