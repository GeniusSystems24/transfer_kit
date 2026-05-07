# Tasks: Provider-Agnostic Transfer Core (3.0.0)

**Input**: Design documents from `specs/002-provider-agnostic-core/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓
**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

**Organization**: Tasks are organized by user story. US1 and US2 are both P1 (foundational removal + built-in drivers). US3–US5 are P2. US6–US7 are P3.

> **Note on version**: `spec.md` Assumption says "2.0.0" but `pubspec.yaml` is already at `2.1.0+1`. The correct next major is **3.0.0** per `plan.md`, `research.md`, and `contracts/public_api_changes.md`. All tasks use 3.0.0.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no shared dependencies)
- **[Story]**: Which user story this task belongs to (US1–US7)
- Exact file paths included in every task

---

## Phase 1: Setup

**Purpose**: Create the new directory structure per `plan.md` before any files are written.

- [X] T001 Create `lib/src/core/driver/` directory for generic transfer contract files
- [X] T002 Create `lib/src/drivers/` directory for built-in driver implementations
- [X] T003 [P] Create `test/src/fake/`, `test/src/driver/`, `test/src/lifecycle/`, `test/src/cache/`, and `test/src/capabilities/` directories

**Checkpoint**: Directory structure matches `plan.md` Project Structure section.

---

## Phase 2: Foundational — Generic Transfer Contracts

**Purpose**: Core driver interface and supporting types. MUST compile before ANY user story can begin. `FakeTransferDriver` is also created here so it is available throughout implementation and testing.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T004 [P] Audit all Firebase imports in `lib/` — for each of the 8 affected files listed in `research.md`, produce an annotated list of what must change (no code change yet; this informs T014–T030)
- [X] T005 [P] Create `lib/src/core/driver/transfer_driver.dart` — `abstract interface class TransferDriver` with `capabilities`, `download(DownloadRequest)`, `upload(UploadRequest)`, `pause(String)`, `resume(String)`, `cancel(String)` per `contracts/transfer_driver_api.md` normative signatures
- [X] T006 [P] Create `lib/src/core/driver/transfer_capabilities.dart` — `@immutable class TransferCapabilities` with 8 boolean flags (all default `false`), `assert(!supportsResume || supportsPause, ...)` invariant, per `contracts/transfer_driver_api.md`
- [X] T007 [P] Create `lib/src/core/driver/download_request.dart` — `@immutable class DownloadRequest` with `taskId`, `source: Uri`, `localPath?`, `cacheKey?`, `metadata` fields per `contracts/transfer_driver_api.md`
- [X] T008 [P] Create `lib/src/core/driver/upload_request.dart` — `@immutable class UploadRequest` with `taskId`, `localPath`, `destination?`, `destinationPath?`, `metadata` fields per `contracts/transfer_driver_api.md`
- [X] T009 [P] Create `lib/src/core/driver/transfer_progress_event.dart` — `sealed class TransferProgressEvent`, `final class TransferProgressUpdate` (with `percentage` getter returning `bytesTransferred / totalBytes` or `0.0` when `totalBytes == 0`), `final class TransferCompleted`, `final class TransferFailed` per `contracts/transfer_driver_api.md`
- [X] T010 [P] Create `lib/src/core/exception/unsupported_capability_exception.dart` — `class UnsupportedCapabilityException implements Exception` with `message: String` and `capability: String?` fields; `toString()` formats as `UnsupportedCapabilityException[capability]: message` per `contracts/transfer_driver_api.md`
- [X] T011 Export `TransferDriver`, `TransferCapabilities`, `DownloadRequest`, `UploadRequest`, `TransferProgressEvent`, `TransferProgressUpdate`, `TransferCompleted`, `TransferFailed`, `UnsupportedCapabilityException` from `lib/transfer_kit.dart`
- [X] T012 [P] Create `test/src/fake/fake_transfer_driver.dart` — `FakeTransferDriver implements TransferDriver` with constructor params `shouldFail: bool = false`, `supportsPause: bool = true`, `progressSteps: int = 3`, `delay: Duration = Duration.zero`; capabilities reflect `supportsPause`; tracks `downloadCallCount`, `uploadCallCount`, `cancelCallCount` for test assertions; emits `progressSteps` `TransferProgressUpdate` events then `TransferCompleted` (or `TransferFailed` if `shouldFail`) per `data-model.md` FakeTransferDriver spec
- [X] T013 [P] Add `http: ^1.0.0` to `pubspec.yaml` dependencies (required for `HttpDownloadDriver`); run `flutter pub get` to confirm resolution

**Checkpoint**: `dart analyze lib/src/core/driver/ lib/src/core/exception/` returns zero errors. `test/src/fake/fake_transfer_driver.dart` compiles cleanly.

---

## Phase 3: US1 (P1) — Use TransferKit Without Firebase

**Goal**: Remove all Firebase dependency from the core package. Zero Firebase imports anywhere in `lib/`.

**Independent Test**: `flutter pub get` on a project with `transfer_kit` and no Firebase packages succeeds with no Firebase transitive dependencies. `flutter analyze lib/` shows zero Firebase-related errors.

- [X] T014 [US1] Add `required TransferDriver driver` parameter to `TransferKitConfig.init()` in `lib/src/core/file_management_config.dart`; store driver on the config singleton so `FileTaskRepository` can access it via `TransferKitConfig.instance.driver`
- [X] T015 [US1] (skipped — no adapter needed; migration went directly to driver-based implementation)
- [X] T016 [US1] Refactor the download flow in `lib/src/repository/file_task_repository.dart`: replace Firebase calls with `TransferKitConfig.instance.driver.download(DownloadRequest(...))` and map `TransferProgressEvent` stream to `FileTask` state transitions
- [X] T017 [US1] Refactor the upload flow in `lib/src/repository/file_task_repository.dart`: replace Firebase calls with `driver.upload(UploadRequest(...))` and map `TransferProgressEvent` stream events to state transitions
- [X] T018 [US1] Refactor `pauseTask()`, `resumeTask()`, `cancelTask()` in `lib/src/repository/file_task_repository.dart`: synchronous capability checks before any `await`; throw `UnsupportedCapabilityException` if flag is `false`; delegate to driver
- [X] T019 [US1] Remove from `lib/src/model/file_task.dart`: the `task: Task?` field, `firebaseTask()` method, `reference` property, `.upload(UploadTask?)` constructor, all `firebase_storage` imports
- [X] T020 [US1] Review `lib/src/model/file_task_extensions.dart` for removed `FileTask` fields; remove all found (none present)
- [X] T021 [US1] Delete `lib/src/repository/firebase_file_repository.dart`
- [X] T022 [US1] Delete `lib/src/repository/firebase_storage_factory.dart`
- [X] T023 [US1] (no adapter was introduced; nothing to remove)
- [X] T024 [P] [US1] Remove `toTimestamp()` and `cloud_firestore` import from `lib/src/core/extension/date_time_extension.dart`
- [X] T025 [P] [US1] Remove `objectToTimestamp()` and Firestore overload of `objectToDateTime()` from `lib/src/core/extension/dynamic_extension.dart`; remove Firestore imports
- [X] T026 [P] [US1] Remove `getDocumentReference(tag)`, `getTimestamp(tag)`, `mapCanConvertToFirebase()`, and Firestore branches of `mapCanConvertToJson()` from `lib/src/core/extension/map_extension.dart`; remove Firestore imports
- [X] T027 [US1] Delete `lib/src/core/extension/geo_point_extension.dart`; remove its export from `lib/transfer_kit.dart`
- [X] T028 [P] [US1] Review `lib/src/service/task_management_service.dart` for Firebase imports — none found
- [X] T029 [P] [US1] Review `lib/src/service/background_transfer_service.dart` for Firebase imports — none found
- [X] T030 [US1] Remove `firebase_storage: ^12.0.0` and `cloud_firestore: ^5.0.0` from `pubspec.yaml`; update library docstring in `lib/transfer_kit.dart`
- [X] T031 [US1] Run `flutter pub get` and confirm no Firebase transitive dependencies; run `flutter analyze` and confirm zero Firebase errors

**Checkpoint**: `flutter analyze` exits clean. Zero files under `lib/` import `firebase_storage` or `cloud_firestore`.

---

## Phase 4: US2 (P1) — Generic Upload and Download With Progress

**Goal**: Two built-in drivers so developers can use TransferKit without writing a custom driver.

- [X] T032 [P] [US2] Create `lib/src/drivers/http_download_driver.dart` with `HttpDownloadDriver implements TransferDriver`
- [X] T033 [US2] Implement `HttpDownloadDriver.download()` — streaming HTTP GET, write chunks to file, emit progress/completed/failed events
- [X] T034 [US2] Implement `HttpDownloadDriver.cancel()` — maintain `_activeClients` map; close client on cancel
- [X] T035 [US2] Implement `HttpDownloadDriver.upload()`, `pause()`, `resume()` — each throws `UnsupportedCapabilityException`
- [X] T036 [P] [US2] Create `lib/src/drivers/local_file_copy_driver.dart` with `LocalFileCopyDriver implements TransferDriver`
- [X] T037 [US2] Implement `LocalFileCopyDriver.download()` — file:// URI source, chunked copy, cancel flag, progress/completed/failed events
- [X] T038 [US2] Implement `LocalFileCopyDriver.upload()` — copy localPath to destinationPath, chunked, cancel flag
- [X] T039 [US2] Implement `LocalFileCopyDriver.cancel()`, `pause()`, `resume()`
- [X] T040 [US2] Export `HttpDownloadDriver` and `LocalFileCopyDriver` from `lib/transfer_kit.dart`

**Checkpoint**: Both drivers compile. `flutter analyze` returns zero errors.

---

## Phase 5: US3 (P2) — Full Task Lifecycle Through Generic Abstractions

- [X] T041 [US3] `waiting → running` transition verified: emitted when driver stream subscription begins
- [X] T042 [US3] `running → paused` transition verified: after `driver.pause()`, state persisted and emitted
- [X] T043 [US3] `paused → running` transition verified: after `driver.resume()`, state persisted and emitted
- [X] T044 [US3] `running → cancelled` transition verified: after `driver.cancel()`, state persisted and emitted
- [X] T045 [US3] Retry path `error → waiting` verified: progress reset to 0 before re-subscribing
- [X] T046 [US3] `waiting → cached` transition verified: cache hit detected before driver invocation

---

## Phase 6: US4 (P2) — Tests Using Fake Transfer Providers

- [X] T047 [P] [US4] Created `test/src/lifecycle/task_lifecycle_test.dart`
- [X] T048 [P] [US4] Created `test/src/capabilities/unsupported_capability_test.dart`
- [X] T049 [P] [US4] Created `test/src/cache/cache_without_firebase_test.dart`
- [X] T050 [P] [US4] Created `test/src/driver/http_download_driver_test.dart`
- [X] T051 [P] [US4] Created `test/src/driver/local_file_copy_driver_test.dart`

---

## Phase 7: US5 (P2) — Driver Capability Model

- [X] T052 [US5] `assert(!supportsResume || supportsPause, ...)` confirmed present in `TransferCapabilities`
- [X] T053 [US5] Capability checks confirmed synchronous before any `await` in `pauseTask()`, `resumeTask()`, `cancelTask()`
- [X] T054 [P] [US5] `createDownloadTask()` checks `supportsDownload` synchronously before first `await`
- [X] T055 [P] [US5] `createUploadTask()` checks `supportsUpload` synchronously before first `await`

---

## Phase 8: US6 (P3) — Cache System Works Without Firebase

- [X] T056 [US6] `file_path_and_url_repository.dart` audited — zero Firebase imports
- [X] T057 [US6] Cache hit/miss logic in `file_task_repository.dart` audited — uses only `FilePathAndURLRepository` backed by `get_storage`

---

## Phase 9: US7 (P3) — Migration Guide for Firebase Users

- [X] T058 [US7] Created `MIGRATION.md` with removed-API table, driver injection section, `FirebaseStorageDriver` adapter example
- [X] T059 [US7] Updated `README.md` — removed Firebase framing, updated setup section, added migration link
- [X] T060 [US7] Updated `CHANGELOG.md` — added `## [3.0.0] - 2026-05-07` entry with Breaking Changes, Added, Migration sections

---

## Phase 10: Polish & Validation

- [X] T061 Updated `version` in `pubspec.yaml` to `3.0.0`
- [X] T062 [P] Run `dart format .` in `packages/transfer_kit/`; fix any formatting issues
- [X] T063 [P] Run `flutter analyze` in `packages/transfer_kit/`; resolve all errors
- [X] T064 Run `flutter test` in `packages/transfer_kit/`; confirm full suite passes
- [X] T065 Zero Firebase imports confirmed in `lib/` (grep returns no matches for `firebase_storage` or `cloud_firestore`)
- [X] T066 Amended `.specify/memory/constitution.md` Principle VI to "Provider Abstraction Boundary"

**Checkpoint**: All 7 Success Criteria from `spec.md` (SC-001 through SC-007) are satisfied. Version 3.0.0 is ready to tag.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user story phases
- **US1 (Phase 3)**: Depends on Phase 2 — foundational contracts must compile first
- **US2 (Phase 4)**: Depends on Phase 2 — can run **in parallel with US1** (different files: `lib/src/drivers/`)
- **US3 (Phase 5)**: Depends on Phase 3 — lifecycle code is in `file_task_repository.dart` modified in US1
