# Implementation Plan: Provider-Agnostic Transfer Core

**Branch**: `002-provider-agnostic-core` | **Date**: 2026-05-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/002-provider-agnostic-core/spec.md`

## Summary

Remove all Firebase Storage and Cloud Firestore dependencies from TransferKit's core, introduce a `TransferDriver` abstract interface that any provider can implement, ship two built-in drivers (`HttpDownloadDriver` and `LocalFileCopyDriver`), provide a `FakeTransferDriver` for tests, and release as version `3.0.0` with a complete migration guide. The driver receives auth configuration at construction time; `DownloadRequest` and `UploadRequest` contain no credential fields. All task lifecycle states, stream sharing, and caching behavior are preserved through generic abstractions.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x (existing SDK constraint preserved)
**Primary Dependencies** (after this task): `get_storage` (task persistence), `path_provider` (local paths), `collection` (batch utilities), `http` (HttpDownloadDriver HTTP client), `logger` (logging)
**Removed Dependencies**: `firebase_storage ^12.0.0`, `cloud_firestore ^5.0.0`
**Storage**: `get_storage` for task persistence; local filesystem via `path_provider` for cached files
**Testing**: `flutter_test` with `FakeTransferDriver` — no Firebase emulator, no network required
**Target Platform**: Flutter (iOS, Android, Web, Desktop)
**Project Type**: Flutter package (library)
**Performance Goals**: No additional latency vs current; stream sharing preserved (one underlying stream per logical task regardless of subscriber count)
**Constraints**: Zero Firebase transitive dependencies after this task; all tests pass offline; all provider-agnostic public APIs preserved; `FileTask`, `FileTaskState`, `FileManagementConfig`, and widget API surface unchanged except removal of Firebase-typed fields
**Scale/Scope**: Version 2.1.0+1 → **3.0.0** (current version is already past 2.x; next major is 3.0.0)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
| --- | --- | --- |
| I — Public Package Stability | **JUSTIFIED DEVIATION** | Firebase-specific public members (`FileTask.reference`, `FileTask.firebaseTask()`) are removed. Migration guide, CHANGELOG, README, and version bump (3.0.0) satisfy the deviation requirements. |
| II — Correct Transfer Lifecycle | PASS | All states preserved through generic abstractions. |
| III — Single Source of Truth | PASS | Task state still managed through `FileTaskRepository`; driver events map to the same `FileTask` model. |
| IV — Stream Sharing & Resource Safety | PASS | Stream sharing pattern preserved; driver streams subscribed once per task. |
| V — Cache Correctness | PASS | Cache system unchanged; Firebase-specific cache integration points removed only. |
| VI — Firebase Storage Integration Boundary | **PLANNED OBSOLESCENCE** | Principle VI will be amended after this task completes — Firebase is no longer the primary provider. The constitution must be updated to replace Principle VI with "Provider Abstraction Boundary." |
| VII — Background Transfer Honesty | PASS | `supportsBackgroundTransfer` kept as flag; no built-in driver claims it in 3.0.0; documented as provider-dependent. |
| VIII — Metadata Extraction Safety | PASS | Not touched by this task. |
| IX — Error Handling and Logging | PASS | `UnsupportedCapabilityException` is a typed exception with chaining. |
| X — Performance & Memory | PASS | Stream sharing preserved; no new O(n²) paths introduced. |
| XI — Testing Requirements | PASS | All lifecycle states covered by fake-driver tests. |
| XII — Documentation & Release | PASS | README, CHANGELOG, migration guide all required by spec. |

**Post-task follow-up (mandatory)**: Amend Principle VI of the constitution to replace "Firebase Storage Integration Boundary" with "Provider Abstraction Boundary," reflecting the new provider-agnostic model.

## Project Structure

### Documentation (this feature)

```text
specs/002-provider-agnostic-core/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   ├── transfer_driver_api.md    # TransferDriver interface contract
│   └── public_api_changes.md    # Removed vs preserved public API surface
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code

```text
lib/
├── transfer_kit.dart                    # Main barrel export (updated)
└── src/
    ├── core/
    │   ├── driver/                      # NEW — generic transfer contracts
    │   │   ├── transfer_driver.dart
    │   │   ├── transfer_capabilities.dart
    │   │   ├── download_request.dart
    │   │   ├── upload_request.dart
    │   │   └── transfer_progress_event.dart
    │   ├── exception/
    │   │   └── unsupported_capability_exception.dart   # NEW
    │   ├── extension/
    │   │   ├── date_time_extension.dart     # MODIFIED: remove Firestore Timestamp methods
    │   │   ├── dynamic_extension.dart       # MODIFIED: remove Firestore Timestamp methods
    │   │   ├── map_extension.dart           # MODIFIED: remove Firestore/GeoPoint methods
    │   │   ├── geo_point_extension.dart     # DELETED (GeoPoint is a Firestore type)
    │   │   ├── file_path_extension.dart     # unchanged
    │   │   ├── list_extension.dart          # unchanged
    │   │   ├── num_extension.dart           # unchanged
    │   │   └── string_extension.dart        # unchanged
    │   ├── file_management_config.dart      # unchanged
    │   ├── get_storage_repository.dart      # unchanged
    │   └── get_storage_value_notifier.dart  # unchanged
    ├── drivers/                         # NEW — built-in driver implementations
    │   ├── http_download_driver.dart        # HttpDownloadDriver (HTTP/HTTPS download)
    │   └── local_file_copy_driver.dart      # LocalFileCopyDriver (on-device copy)
    ├── model/
    │   ├── file_task.dart               # MODIFIED: remove task: Task?, reference, firebaseTask(), upload(UploadTask?)
    │   ├── file_exception.dart          # unchanged
    │   ├── file_model.dart              # unchanged
    │   ├── file_path_and_url.dart       # unchanged
    │   ├── file_task_extensions.dart    # REVIEW for Firebase refs
    │   ├── media_metadata.dart          # unchanged
    │   ├── multi_download_file_task.dart # unchanged
    │   └── multi_upload_file_task.dart  # unchanged
    ├── repository/
    │   ├── file_task_repository.dart    # MODIFIED: use TransferDriver instead of Firebase
    │   ├── file_path_and_url_repository.dart  # unchanged
    │   ├── background_task_repository.dart    # unchanged
    │   ├── firebase_file_repository.dart      # DELETED
    │   └── firebase_storage_factory.dart      # DELETED
    ├── service/
    │   ├── task_management_service.dart   # REVIEW for Firebase refs
    │   ├── background_transfer_service.dart   # REVIEW for Firebase refs
    │   └── metadata_extraction_service.dart   # unchanged
    ├── widget/                          # unchanged (no Firebase-specific assumptions expected)
    ├── media_widgets/                   # unchanged
    └── transfer_kit.dart                # MODIFIED: accept TransferDriver injection

test/
└── src/
    ├── fake/
    │   └── fake_transfer_driver.dart    # FakeTransferDriver (test utility — exported from test/)
    ├── driver/
    │   ├── http_download_driver_test.dart
    │   └── local_file_copy_driver_test.dart
    ├── lifecycle/
    │   └── task_lifecycle_test.dart
    ├── cache/
    │   └── cache_without_firebase_test.dart
    └── capabilities/
        └── unsupported_capability_test.dart
```

**Structure Decision**: Single Flutter package. New driver abstraction lives under `lib/src/core/driver/`. Built-in driver implementations live under `lib/src/drivers/`. Test utilities live under `test/src/fake/` (not exported from the main barrel — consumers write their own fakes or copy the reference fake).

## Implementation Phases

### Phase 1 — Introduce generic transfer contracts (non-breaking addition)

Add new files without removing any existing code:

- `lib/src/core/driver/transfer_driver.dart`
- `lib/src/core/driver/transfer_capabilities.dart`
- `lib/src/core/driver/download_request.dart`
- `lib/src/core/driver/upload_request.dart`
- `lib/src/core/driver/transfer_progress_event.dart`
- `lib/src/core/exception/unsupported_capability_exception.dart`

Export all new types from `lib/transfer_kit.dart`.

**Gate**: All existing tests still pass. No Firebase files touched.

### Phase 2 — Redirect FileTaskRepository through TransferDriver

- Add `TransferDriver driver` parameter to `TransferKit` / `TransferKitConfig.init()`.
- Update `file_task_repository.dart` to call `driver.download()` / `driver.upload()` / `driver.pause()` / `driver.resume()` / `driver.cancel()` instead of `FirebaseFileRepository`.
- Map `TransferProgressEvent` stream events to `FileTask` state transitions.
- `FileTask` retains its Firebase fields temporarily (they are not yet removed).
- Implement a temporary internal `_FirebaseTransferDriverAdapter` that wraps `FirebaseFileRepository` — used as the default driver so existing callers that don't pass a driver still work during migration.

**Gate**: All existing tests still pass. Firebase-coupled behavior still works through the adapter.

### Phase 3 — Remove Firebase fields from FileTask model

- Remove `task: Task?` field and constructor parameter from `FileTask`.
- Remove `firebaseTask({bool justCheck})` method from `FileTask`.
- Remove `reference` property from `FileTask`.
- Remove `.upload(UploadTask? task)` named constructor override.
- Remove Firebase imports from `file_task.dart`.
- Update `file_task_extensions.dart` if it references removed fields.

**Gate**: `flutter analyze` clean. Tests pass.

### Phase 4 — Remove Firebase implementation files and imports

- Delete `lib/src/repository/firebase_file_repository.dart`.
- Delete `lib/src/repository/firebase_storage_factory.dart`.
- Delete the internal `_FirebaseTransferDriverAdapter`.
- Remove `firebase_storage` and `cloud_firestore` from `pubspec.yaml`.
- Remove Firestore-specific methods from extensions:
  - `date_time_extension.dart`: remove `toTimestamp()`.
  - `dynamic_extension.dart`: remove `objectToTimestamp()`, `objectToDateTime()` (Firestore overloads).
  - `map_extension.dart`: remove `getDocumentReference()`, `getTimestamp()`, `mapCanConvertToFirebase()`, Firebase-specific branches of `mapCanConvertToJson()`.
  - Delete `geo_point_extension.dart` entirely.
- Remove those deleted extensions from `lib/transfer_kit.dart` barrel export.
- Review `task_management_service.dart` and `background_transfer_service.dart` for any remaining Firebase references; purge them.

**Gate**: `flutter pub get` succeeds with no Firebase packages. `flutter analyze` clean. Tests pass.

### Phase 5 — Add built-in drivers

- Implement `HttpDownloadDriver` in `lib/src/drivers/http_download_driver.dart`:
  - Capabilities: `supportsDownload: true`, `supportsCancel: true`, `supportsProgress: true`. All others false.
  - Constructor accepts optional `Map<String, String> headers` (for auth tokens etc.).
  - Uses `http` package for download with chunked progress reporting.
- Implement `LocalFileCopyDriver` in `lib/src/drivers/local_file_copy_driver.dart`:
  - Capabilities: `supportsUpload: true`, `supportsDownload: true`, `supportsCancel: true`, `supportsProgress: true`. All others false.
  - Copies source file to destination path on-device; emits synthetic progress events.
  - Serves as canonical reference implementation for custom driver authors.
- Export both from `lib/transfer_kit.dart`.
- Add `FakeTransferDriver` to `test/src/fake/fake_transfer_driver.dart` (configurable: succeed / fail / pause / slow-progress).

**Gate**: Driver tests pass. `flutter analyze` clean.

### Phase 6 — Tests

Write tests covering:

- `task_lifecycle_test.dart`: All 8 states (`waiting`, `running`, `paused`, `completed`, `error`, `cancelled`, `cached`, retry-eligible) via fake driver.
- `unsupported_capability_test.dart`: Calling `pause()` / `resume()` on a driver with those capabilities `false` throws `UnsupportedCapabilityException`.
- `cache_without_firebase_test.dart`: Cache hit returns local file without invoking driver a second time.
- `http_download_driver_test.dart`: Progress events emitted; final `TransferCompleted` event with local path.
- `local_file_copy_driver_test.dart`: Copy emits progress; cancel stops the copy.

**Gate**: Full test suite passes offline with `flutter test`.

### Phase 7 — Migration guide and documentation

- Write `MIGRATION.md` at package root documenting:
  - What was removed and why.
  - How to implement a `TransferDriver` (with a Firebase example).
  - How to inject a driver: `TransferKitConfig.init(driver: MyDriver())`.
  - Removed public API members and their replacements.
  - New version number (3.0.0).
- Update `README.md`: remove Firebase-only framing; add provider-agnostic quickstart using `HttpDownloadDriver`.
- Update `CHANGELOG.md`: 3.0.0 breaking change entry with link to MIGRATION.md.

**Gate**: README quickstart compiles. CHANGELOG entry references MIGRATION.md.

### Phase 8 — Constitution amendment

Update `.specify/memory/constitution.md` Principle VI: rename from "Firebase Storage Integration Boundary" to "Provider Abstraction Boundary" and rewrite to describe the `TransferDriver` interface model.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| Principle I deviation (public API removal) | Firebase-typed public members (`FileTask.reference`, `FileTask.firebaseTask()`) cannot be made provider-agnostic — they must be removed | Deprecation without removal would still pull Firebase as a transitive dependency, defeating the primary goal |
| Principle VI obsolescence | This task's purpose is to remove Firebase as the primary provider | No simpler path; Firebase integration boundary principle is being replaced, not violated |
