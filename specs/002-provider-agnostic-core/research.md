# Research: Provider-Agnostic Transfer Core

**Phase 0 output** | **Date**: 2026-05-07 | **Plan**: [plan.md](plan.md)

## Firebase Coupling Audit

### Files with Firebase imports (8 files)

| File | Packages imported | Removal strategy |
| --- | --- | --- |
| `lib/src/repository/firebase_file_repository.dart` | `firebase_storage` | DELETE entirely — replaced by `TransferDriver` |
| `lib/src/repository/firebase_storage_factory.dart` | `firebase_storage` | DELETE entirely — replaced by `TransferDriver` |
| `lib/src/repository/file_task_repository.dart` | `firebase_storage` | MODIFY — replace Firebase calls with `TransferDriver` calls |
| `lib/src/model/file_task.dart` | `firebase_storage` | MODIFY — remove `task: Task?`, `reference`, `firebaseTask()`, `.upload(UploadTask?)` |
| `lib/src/core/extension/map_extension.dart` | `cloud_firestore` | MODIFY — remove `getDocumentReference()`, `getTimestamp()`, `mapCanConvertToFirebase()`, Firebase branches of `mapCanConvertToJson()` |
| `lib/src/core/extension/dynamic_extension.dart` | `cloud_firestore` | MODIFY — remove `objectToTimestamp()`, Firestore overload of `objectToDateTime()` |
| `lib/src/core/extension/date_time_extension.dart` | `cloud_firestore` | MODIFY — remove `toTimestamp()` |
| `lib/src/core/extension/geo_point_extension.dart` | `cloud_firestore` | DELETE entirely — `GeoPoint` is a Firestore type; no generic equivalent needed |

### Firebase-specific public API members (to be removed in 3.0.0)

| Member | Class | Replacement |
| --- | --- | --- |
| `task: Task?` field | `FileTask` | Removed — driver manages transfer task internally |
| `firebaseTask({bool justCheck})` | `FileTask` | Removed — no generic equivalent |
| `reference` property → `Reference` | `FileTask` | Removed — driver manages storage reference internally |
| `.upload(UploadTask? task)` named constructor | `FileTask` | Removed — use standard constructor |
| `toTimestamp()` | `DateTimeExtension` | Removed — Firestore-specific utility |
| `objectToTimestamp()` | `DynamicExtension` | Removed — Firestore-specific utility |
| `getDocumentReference()` | `MapExtension` | Removed — Firestore-specific utility |
| `getTimestamp()` | `MapExtension` | Removed — Firestore-specific utility |
| `mapCanConvertToFirebase()` | `MapExtension` | Removed — Firestore-specific utility |
| `GeoPointExtension` (entire extension) | — | Removed — Firestore type |

### Internal (non-exported) Firebase APIs deleted

- `FirebaseFileRepository` (all methods)
- `FirebaseStorageFactory` (all methods, Firebase task caches)

### Key finding: Most Firebase exposure is internal

`FirebaseFileRepository` and `FirebaseStorageFactory` are **not exported** from `lib/transfer_kit.dart`. The main public exposure is `FileTask`'s Firebase-typed fields and the Firestore conversion utilities in extensions. This means the blast radius on consumers is smaller than expected.

---

## Architecture Decisions

### Decision 1: TransferDriver stream design

- **Decision**: `Stream<TransferProgressEvent>` where `TransferProgressEvent` is a sealed class with three subtypes: `TransferProgressUpdate`, `TransferCompleted`, `TransferFailed`.
- **Rationale**: A sealed class forces exhaustive handling at the call site. Using a typed sealed hierarchy avoids stringly-typed events and eliminates the need for a separate result future. The stream closes after the terminal event (`TransferCompleted` or `TransferFailed`).
- **Alternatives considered**:
  - `(Stream<double>, Future<TransferResult>)` tuple — awkward to wire; stream and future can diverge on cancel.
  - `Stream<Map<String, dynamic>>` — untyped; loses exhaustiveness.

### Decision 2: Capability violations throw, not silently no-op

- **Decision**: Calling `pause()`, `resume()`, `cancel()`, `upload()`, or `download()` on a driver that declares the capability unsupported throws `UnsupportedCapabilityException` immediately — before any I/O.
- **Rationale**: Silent no-ops produce "stuck" tasks that are nearly impossible to debug. Typed throws give the caller a clear signal and appear in tests.
- **Alternatives considered**:
  - Return `false` — caller must check return value; easily ignored.
  - Transition task to `error` state — coupling capability check to task state machine complicates the driver contract.

### Decision 3: Auth credentials at driver constructor, not in requests

- **Decision**: `DownloadRequest` and `UploadRequest` contain no auth or credential fields. All auth is supplied at driver construction (e.g., `HttpDownloadDriver(headers: {'Authorization': 'Bearer $token'})`).
- **Rationale**: Keeps request objects generic and reusable across providers. Auth is a driver concern, not a transfer-description concern.
- **Alternatives considered**:
  - Per-request auth map — couples request model to auth concerns; makes `TransferRequest` provider-aware.
  - Both — adds complexity without clear benefit for the typical use case.

### Decision 4: TransferKit accepts driver via config / constructor injection

- **Decision**: `TransferKitConfig.init(driver: myDriver)` or `TransferKit(driver: myDriver)` — both are acceptable entry points. If no driver is supplied, a clear `AssertionError` is thrown at init time (not lazily at first transfer).
- **Rationale**: Failing fast at init time is better than a confusing null-related failure when the first transfer starts. The spec requires zero Firebase defaults.
- **Alternatives considered**:
  - Default to `HttpDownloadDriver` — would silently fail for upload consumers.
  - Lazy fail — harder to diagnose.

### Decision 5: Version number is 3.0.0 (not 2.0.0)

- **Decision**: Next published version is `3.0.0`.
- **Rationale**: Current `pubspec.yaml` version is `2.1.0+1`. Clarification Q2 answered "major version bump"; since the package is already in the 2.x line, the next major is 3.0.0.
- **Alternatives considered**: Publish as `2.2.0` — incorrect; removing public APIs is a breaking change.

### Decision 6: HttpDownloadDriver uses the `http` package

- **Decision**: Use `package:http` (not `dio`) for `HttpDownloadDriver`.
- **Rationale**: `http` is already a transitive dependency of many Flutter packages and is lighter. `dio` adds significant transitive weight for what is a single download driver. Consumers who need `dio`'s interceptor features can write their own driver.
- **Alternatives considered**: `dio` — heavier, not already present in the package graph.

### Decision 7: FakeTransferDriver lives in test/, not lib/

- **Decision**: `FakeTransferDriver` is placed in `test/src/fake/fake_transfer_driver.dart`, not exported from the main barrel.
- **Rationale**: Consumers who need a fake for their own tests should copy or subclass the reference implementation — or implement `TransferDriver` themselves. Exporting test utilities from a library barrel increases package surface unnecessarily.
- **Alternatives considered**: Export from lib/ under a `testing` subdirectory — precedent in some packages but adds to the public API footprint.

---

## Background Transfer: Reserved Flag

The `supportsBackgroundTransfer` capability flag is kept in `TransferCapabilities` as a future extension point. No built-in driver declares it `true` in 3.0.0. This is documented clearly in:
- `TransferCapabilities` dartdoc
- `HttpDownloadDriver` capabilities declaration
- `LocalFileCopyDriver` capabilities declaration
- README.md "Background Transfers" section

---

## Migration Impact Summary

### Breaking changes (consumers must update)

1. Remove `firebase_storage` and `cloud_firestore` from their `pubspec.yaml` if they were only pulled via TransferKit.
2. Stop using `FileTask.reference`, `FileTask.firebaseTask()`, `FileTask.task`.
3. Stop using `toTimestamp()`, `objectToTimestamp()`, `getDocumentReference()`, `getTimestamp()`, `mapCanConvertToFirebase()`, `GeoPointExtension`.
4. Supply a `TransferDriver` at `TransferKit` initialization — no default Firebase driver exists.

### Non-breaking preserved surface

- All `FileTask` state fields (`taskId`, `state`, `progress`, `localPath`, etc.)
- `FileTaskRepository` public API
- `FilePathAndURLRepository` public API
- `FileManagementConfig` API
- All widget exports
- Stream-sharing behavior
- Cache system behavior
- `FileException` hierarchy
- Batch and group operations
