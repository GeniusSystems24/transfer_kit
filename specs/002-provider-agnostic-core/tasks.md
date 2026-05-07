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

- [ ] T001 Create `lib/src/core/driver/` directory for generic transfer contract files
- [ ] T002 Create `lib/src/drivers/` directory for built-in driver implementations
- [ ] T003 [P] Create `test/src/fake/`, `test/src/driver/`, `test/src/lifecycle/`, `test/src/cache/`, and `test/src/capabilities/` directories

**Checkpoint**: Directory structure matches `plan.md` Project Structure section.

---

## Phase 2: Foundational — Generic Transfer Contracts

**Purpose**: Core driver interface and supporting types. MUST compile before ANY user story can begin. `FakeTransferDriver` is also created here so it is available throughout implementation and testing.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T004 [P] Audit all Firebase imports in `lib/` — for each of the 8 affected files listed in `research.md`, produce an annotated list of what must change (no code change yet; this informs T014–T030)
- [ ] T005 [P] Create `lib/src/core/driver/transfer_driver.dart` — `abstract interface class TransferDriver` with `capabilities`, `download(DownloadRequest)`, `upload(UploadRequest)`, `pause(String)`, `resume(String)`, `cancel(String)` per `contracts/transfer_driver_api.md` normative signatures
- [ ] T006 [P] Create `lib/src/core/driver/transfer_capabilities.dart` — `@immutable class TransferCapabilities` with 8 boolean flags (all default `false`), `assert(!supportsResume || supportsPause, ...)` invariant, per `contracts/transfer_driver_api.md`
- [ ] T007 [P] Create `lib/src/core/driver/download_request.dart` — `@immutable class DownloadRequest` with `taskId`, `source: Uri`, `localPath?`, `cacheKey?`, `metadata` fields per `contracts/transfer_driver_api.md`
- [ ] T008 [P] Create `lib/src/core/driver/upload_request.dart` — `@immutable class UploadRequest` with `taskId`, `localPath`, `destination?`, `destinationPath?`, `metadata` fields per `contracts/transfer_driver_api.md`
- [ ] T009 [P] Create `lib/src/core/driver/transfer_progress_event.dart` — `sealed class TransferProgressEvent`, `final class TransferProgressUpdate` (with `percentage` getter returning `bytesTransferred / totalBytes` or `0.0` when `totalBytes == 0`), `final class TransferCompleted`, `final class TransferFailed` per `contracts/transfer_driver_api.md`
- [ ] T010 [P] Create `lib/src/core/exception/unsupported_capability_exception.dart` — `class UnsupportedCapabilityException implements Exception` with `message: String` and `capability: String?` fields; `toString()` formats as `UnsupportedCapabilityException[capability]: message` per `contracts/transfer_driver_api.md`
- [ ] T011 Export `TransferDriver`, `TransferCapabilities`, `DownloadRequest`, `UploadRequest`, `TransferProgressEvent`, `TransferProgressUpdate`, `TransferCompleted`, `TransferFailed`, `UnsupportedCapabilityException` from `lib/transfer_kit.dart`
- [ ] T012 [P] Create `test/src/fake/fake_transfer_driver.dart` — `FakeTransferDriver implements TransferDriver` with constructor params `shouldFail: bool = false`, `supportsPause: bool = true`, `progressSteps: int = 3`, `delay: Duration = Duration.zero`; capabilities reflect `supportsPause`; tracks `downloadCallCount`, `uploadCallCount`, `cancelCallCount` for test assertions; emits `progressSteps` `TransferProgressUpdate` events then `TransferCompleted` (or `TransferFailed` if `shouldFail`) per `data-model.md` FakeTransferDriver spec
- [ ] T013 [P] Add `http: ^1.0.0` to `pubspec.yaml` dependencies (required for `HttpDownloadDriver`); run `flutter pub get` to confirm resolution

**Checkpoint**: `dart analyze lib/src/core/driver/ lib/src/core/exception/` returns zero errors. `test/src/fake/fake_transfer_driver.dart` compiles cleanly.

---

## Phase 3: US1 (P1) — Use TransferKit Without Firebase

**Goal**: Remove all Firebase dependency from the core package. Zero Firebase imports anywhere in `lib/`.

**Independent Test**: `flutter pub get` on a project with `transfer_kit` and no Firebase packages succeeds with no Firebase transitive dependencies. `flutter analyze lib/` shows zero Firebase-related errors.

- [ ] T014 [US1] Add `required TransferDriver driver` parameter to `TransferKitConfig.init()` in `lib/src/transfer_kit.dart`; store driver on the config singleton so `FileTaskRepository` can access it via `TransferKitConfig.instance.driver`
- [ ] T015 [US1] Add temporary internal `_FirebaseTransferDriverAdapter` class in `lib/src/repository/file_task_repository.dart` implementing `TransferDriver` by delegating to `FirebaseFileRepository` — keeps the package compiling during migration; will be deleted in T023
- [ ] T016 [US1] Refactor the download flow in `lib/src/repository/file_task_repository.dart`: replace the `FirebaseFileRepository.download()` call with `TransferKitConfig.instance.driver.download(DownloadRequest(taskId: ..., source: ..., localPath: ..., cacheKey: ...))` and map the returned `TransferProgressEvent` stream to `FileTask` state transitions (`FileTaskState.running` on first event, `FileTaskState.completed` on `TransferCompleted`, `FileTaskState.error` on `TransferFailed`)
- [ ] T017 [US1] Refactor the upload flow in `lib/src/repository/file_task_repository.dart`: replace `FirebaseFileRepository.upload()` with `driver.upload(UploadRequest(taskId: ..., localPath: ..., destinationPath: ...))` and map `TransferProgressEvent` stream events to state transitions
- [ ] T018 [US1] Refactor `pauseTask()`, `resumeTask()`, `cancelTask()` in `lib/src/repository/file_task_repository.dart`: check `driver.capabilities.supportsPause` / `supportsResume` / `supportsCancel` synchronously before any `await`; throw `UnsupportedCapabilityException(message, capability: 'supportsPause')` if the flag is `false`; otherwise delegate to `driver.pause(taskId)` / `driver.resume(taskId)` / `driver.cancel(taskId)`
- [ ] T019 [US1] Remove from `lib/src/model/file_task.dart`: the `task: Task?` field and its constructor parameter; the `firebaseTask({bool justCheck})` method; the `reference` property (returning `firebase_storage.Reference`); the `.upload(UploadTask? task)` named constructor variant; all `firebase_storage` imports
- [ ] T020 [US1] Review `lib/src/model/file_task_extensions.dart` for references to the removed `FileTask` fields (`task`, `reference`, `firebaseTask`); remove all found
- [ ] T021 [US1] Delete `lib/src/repository/firebase_file_repository.dart`
- [ ] T022 [US1] Delete `lib/src/repository/firebase_storage_factory.dart`
- [ ] T023 [US1] Remove the internal `_FirebaseTransferDriverAdapter` class from `lib/src/repository/file_task_repository.dart` (Firebase files deleted in T021–T022; adapter no longer compiles)
- [ ] T024 [P] [US1] Remove `toTimestamp()` extension method from `lib/src/core/extension/date_time_extension.dart`; remove any `cloud_firestore` import from that file
- [ ] T025 [P] [US1] Remove `objectToTimestamp()` and the Firestore-specific `objectToDateTime()` overload (accepting a `Timestamp` argument) from `lib/src/core/extension/dynamic_extension.dart`; remove Firestore imports
- [ ] T026 [P] [US1] Remove `getDocumentReference(tag)`, `getTimestamp(tag)`, `mapCanConvertToFirebase()`, and the Firestore type-handling branches inside `mapCanConvertToJson()` from `lib/src/core/extension/map_extension.dart`; remove Firestore imports
- [ ] T027 [US1] Delete `lib/src/core/extension/geo_point_extension.dart`; remove its export line from `lib/transfer_kit.dart`
- [ ] T028 [P] [US1] Review `lib/src/service/task_management_service.dart` for Firebase imports or Firebase-specific calls; remove all found
- [ ] T029 [P] [US1] Review `lib/src/service/background_transfer_service.dart` for Firebase imports or Firebase-specific calls; remove all found
- [ ] T030 [US1] Remove `firebase_storage: ^12.0.0` and `cloud_firestore: ^5.0.0` from `pubspec.yaml` dependencies; remove any Firebase-specific export lines from `lib/transfer_kit.dart`
- [ ] T031 [US1] Run `flutter pub get` and confirm no Firebase transitive dependencies appear in `.dart_tool/package_config.json`; run `flutter analyze` and confirm zero unresolved Firebase reference errors

**Checkpoint**: `flutter analyze` exits clean. Zero files under `lib/` import `firebase_storage` or `cloud_firestore`.

---

## Phase 4: US2 (P1) — Generic Upload and Download With Progress

**Goal**: Two built-in drivers so developers can use TransferKit without writing a custom driver.

**Independent Test**: `TransferKitConfig.init(driver: HttpDownloadDriver())` and `TransferKitConfig.init(driver: LocalFileCopyDriver())` both compile. Offline tests using `FakeTransferDriver` emit progress events and reach `TransferCompleted`.

- [ ] T032 [P] [US2] Create `lib/src/drivers/http_download_driver.dart` — declare `class HttpDownloadDriver implements TransferDriver` with `static const _capabilities = TransferCapabilities(supportsDownload: true, supportsCancel: true, supportsProgress: true)` and constructor `HttpDownloadDriver({Map<String, String> headers = const {}})` per `contracts/transfer_driver_api.md` Built-in Driver declarations
- [ ] T033 [US2] Implement `HttpDownloadDriver.download(DownloadRequest request)` in `lib/src/drivers/http_download_driver.dart`: open a streaming HTTP GET to `request.source` using the `http` package `Client`, passing constructor `headers`; write response chunks to `request.localPath` (or a temp directory path derived from `request.taskId` if `localPath` is null); emit `TransferProgressUpdate(taskId, bytesTransferred, totalBytes)` per chunk (use Content-Length header for `totalBytes`; `0` if unknown); emit `TransferCompleted(taskId: ..., localPath: ...)` on success; catch HTTP errors and emit `TransferFailed(taskId: ..., error: ..., stackTrace: ...)`; close stream after terminal event
- [ ] T034 [US2] Implement `HttpDownloadDriver.cancel(String taskId)` in `lib/src/drivers/http_download_driver.dart`: maintain a `Map<String, Client> _activeClients`; close the client for the given `taskId`; the download stream's catch block detects the closed client and emits `TransferFailed` with a cancellation message; if `taskId` is not active, `cancel()` is a no-op
- [ ] T035 [US2] Implement `HttpDownloadDriver.upload()`, `pause()`, `resume()` in `lib/src/drivers/http_download_driver.dart` — each throws `UnsupportedCapabilityException` with the appropriate `capability` name (`'supportsUpload'`, `'supportsPause'`, `'supportsResume'`)
- [ ] T036 [P] [US2] Create `lib/src/drivers/local_file_copy_driver.dart` — declare `class LocalFileCopyDriver implements TransferDriver` with `static const _capabilities = TransferCapabilities(supportsUpload: true, supportsDownload: true, supportsCancel: true, supportsProgress: true)` per `contracts/transfer_driver_api.md` Built-in Driver declarations; this driver serves as the canonical reference implementation for custom driver authors
- [ ] T037 [US2] Implement `LocalFileCopyDriver.download(DownloadRequest request)` in `lib/src/drivers/local_file_copy_driver.dart`: treat `request.source` as a local `file://` URI; open source file for reading; create destination at `request.localPath`; read in 64 KB chunks; emit `TransferProgressUpdate` per chunk; check `_cancelFlags[request.taskId]` between chunks and emit `TransferFailed` with cancellation message if set; emit `TransferCompleted(taskId: ..., localPath: ...)` on completion
- [ ] T038 [US2] Implement `LocalFileCopyDriver.upload(UploadRequest request)` in `lib/src/drivers/local_file_copy_driver.dart`: copy `request.localPath` to `request.destinationPath`; emit synthetic `TransferProgressUpdate` events per chunk; check cancel flag between chunks; emit `TransferCompleted` on success
- [ ] T039 [US2] Implement `LocalFileCopyDriver.cancel(String taskId)` in `lib/src/drivers/local_file_copy_driver.dart`: set `_cancelFlags[taskId] = true`; the read loops in `download()`/`upload()` check this flag and terminate the stream; implement `pause()` and `resume()` each throwing `UnsupportedCapabilityException`
- [ ] T040 [US2] Export `HttpDownloadDriver` and `LocalFileCopyDriver` from `lib/transfer_kit.dart`

**Checkpoint**: `TransferKitConfig.init(driver: HttpDownloadDriver())` and `TransferKitConfig.init(driver: LocalFileCopyDriver())` compile. `flutter analyze` returns zero errors.

---

## Phase 5: US3 (P2) — Full Task Lifecycle Through Generic Abstractions

**Goal**: All 8 `FileTaskState` transitions (`waiting`, `running`, `paused`, `completed`, `error`, `cancelled`, `cached`, retry) flow through the `TransferDriver` interface with zero Firebase involvement.

**Independent Test**: Using `FakeTransferDriver(supportsPause: true)`, initiate a task, pause it, resume it, and cancel it — each `FileTaskState` transition is observed on the task stream. All transitions happen offline.

- [ ] T041 [US3] In `lib/src/repository/file_task_repository.dart`, verify the `waiting → running` transition is emitted at the moment the driver's stream subscription begins (not when the task is enqueued); add or fix if the state update fires at the wrong time
- [ ] T042 [US3] In `lib/src/repository/file_task_repository.dart`, verify the `running → paused` transition: after `driver.pause(taskId)` returns without throwing, persist `FileTaskState.paused` and emit the updated `FileTask` on the task stream
- [ ] T043 [US3] In `lib/src/repository/file_task_repository.dart`, verify the `paused → running` transition: after `driver.resume(taskId)` returns without throwing, persist `FileTaskState.running` and emit the updated `FileTask`
- [ ] T044 [US3] In `lib/src/repository/file_task_repository.dart`, verify the `running → cancelled` transition: after `driver.cancel(taskId)` returns, persist `FileTaskState.cancelled` and emit the updated `FileTask`
- [ ] T045 [US3] In `lib/src/repository/file_task_repository.dart`, verify the retry path `error → waiting`: re-subscribe to `driver.download()` / `driver.upload()` for the same `taskId`; reset `FileTask.progress` to `0` before re-subscribing
- [ ] T046 [US3] In `lib/src/repository/file_task_repository.dart`, verify the `waiting → cached` transition: when a cache hit is detected in `FilePathAndURLRepository` before invoking the driver, transition directly to `FileTaskState.cached` without calling `driver.download()` at all

**Checkpoint**: A code review of `file_task_repository.dart` shows each of T041–T046's state transitions is handled by a code path containing no Firebase import or call.

---

## Phase 6: US4 (P2) — Tests Using Fake Transfer Providers

**Goal**: Full automated test suite passes offline using only `FakeTransferDriver`. No Firebase credentials, no emulator, no network.

**Independent Test**: `flutter test test/src/` exits with code 0. All 5 test files run without any network requests or Firebase initialization.

- [ ] T047 [P] [US4] Create `test/src/lifecycle/task_lifecycle_test.dart`: using `FakeTransferDriver`, test all 8 `FileTaskState` values — `waiting` (before start), `running` (after start), `paused` (via `FakeTransferDriver(supportsPause: true)` + `repo.pauseTask()`), `completed` (after `TransferCompleted`), `error` (via `FakeTransferDriver(shouldFail: true)`), `cancelled` (via `repo.cancelTask()`), `cached` (cache hit before driver call), and retry (`error → waiting → running → completed`)
- [ ] T048 [P] [US4] Create `test/src/capabilities/unsupported_capability_test.dart`: test that `repo.pauseTask(taskId)` throws `UnsupportedCapabilityException` when the driver has `supportsPause: false`; test same for `resumeTask()` (`supportsResume: false`) and `cancelTask()` (`supportsCancel: false`); test that `createDownloadTask()` throws when `supportsDownload: false`; test that `createUploadTask()` throws when `supportsUpload: false`
- [ ] T049 [P] [US4] Create `test/src/cache/cache_without_firebase_test.dart`: initiate a download with `FakeTransferDriver` and await completion; initiate the identical download again (same `taskId`, same URL); assert `FakeTransferDriver.downloadCallCount == 1` (cache hit prevented second driver invocation)
- [ ] T050 [P] [US4] Create `test/src/driver/http_download_driver_test.dart` using a mock HTTP client (e.g., `http` package `MockClient`): assert that `TransferProgressUpdate` events are emitted during download; assert the terminal event is `TransferCompleted` with a non-null `localPath`; assert that calling `cancel(taskId)` causes the stream to terminate with `TransferFailed`
- [ ] T051 [P] [US4] Create `test/src/driver/local_file_copy_driver_test.dart`: write a source file to a temp path; initiate a download via `LocalFileCopyDriver`; assert `TransferProgressUpdate` events are emitted; assert destination file exists and matches source after `TransferCompleted`; assert that calling `cancel(taskId)` mid-copy terminates the stream with `TransferFailed` and leaves no partial file

**Checkpoint**: `flutter test test/src/` exits with code 0 on a machine with no Firebase config and no network access.

---

## Phase 7: US5 (P2) — Driver Capability Model

**Goal**: Capability flags enforced at the contract level; unsupported operations throw `UnsupportedCapabilityException` **synchronously** (before any `await`).

**Independent Test**: A driver with `supportsPause: false` — calling `repo.pauseTask()` throws `UnsupportedCapabilityException` without awaiting anything. The exception is caught in a synchronous `try/catch`.

- [ ] T052 [US5] In `lib/src/core/driver/transfer_capabilities.dart`, confirm the `assert(!supportsResume || supportsPause, 'supportsResume requires supportsPause to be true')` is present in the const constructor; add it if missing
- [ ] T053 [US5] In `lib/src/repository/file_task_repository.dart`, confirm `pauseTask()`, `resumeTask()`, and `cancelTask()` perform their capability checks synchronously — before the first `await` in the method body — and throw `UnsupportedCapabilityException` immediately if the flag is `false`
- [ ] T054 [P] [US5] In `lib/src/repository/file_task_repository.dart`, confirm `createDownloadTask()` checks `driver.capabilities.supportsDownload` and throws `UnsupportedCapabilityException(message, capability: 'supportsDownload')` synchronously if `false`
- [ ] T055 [P] [US5] In `lib/src/repository/file_task_repository.dart`, confirm `createUploadTask()` checks `driver.capabilities.supportsUpload` and throws `UnsupportedCapabilityException(message, capability: 'supportsUpload')` synchronously if `false`

**Checkpoint**: All capability-guard `throw` statements appear before any `await` keyword in their respective methods. The `capability` field is populated in every thrown `UnsupportedCapabilityException`.

---

## Phase 8: US6 (P3) — Cache System Works Without Firebase

**Goal**: `FilePathAndURLRepository` and all cache integration points in `FileTaskRepository` operate through `get_storage` only — zero Firebase dependency.

**Independent Test**: `FilePathAndURLRepository` stores and retrieves a `FilePathAndURL` without any Firebase import in scope.

- [ ] T056 [US6] Audit `lib/src/repository/file_path_and_url_repository.dart` for Firebase imports; remove all found; confirm the file uses only `get_storage` for persistence
- [ ] T057 [US6] Audit the cache hit/miss logic in `lib/src/repository/file_task_repository.dart` for Firebase-specific cache keys, Firestore references, or Firebase Storage URL patterns; remove all found; ensure the cache path uses only `FilePathAndURLRepository` backed by `get_storage`

**Checkpoint**: `grep -r "firebase" lib/src/repository/file_path_and_url_repository.dart` returns no matches. The cache test in T049 passes.

---

## Phase 9: US7 (P3) — Migration Guide for Firebase Users

**Goal**: A developer who used the Firebase-coupled API can migrate entirely by following `MIGRATION.md` without asking for help.

**Independent Test**: A team member who has not seen this PR reads `MIGRATION.md` and can identify every removed API and find its provider-agnostic replacement.

- [ ] T058 [US7] Create `MIGRATION.md` at `packages/transfer_kit/MIGRATION.md`: include a "What was removed" table (all 10 removed public members from `contracts/public_api_changes.md`); include "Why" column; include "Driver injection" section showing `TransferKitConfig.init(driver: HttpDownloadDriver(...))` per `quickstart.md`; include the complete `FirebaseStorageDriver` adapter implementation from `quickstart.md` as a migration path for Firebase users; note that the package version is 3.0.0
- [ ] T059 [US7] Update `README.md` at `packages/transfer_kit/README.md`: remove Firebase-only framing from the introduction and setup sections; replace the Firebase quickstart with the provider-agnostic `HttpDownloadDriver` quickstart from `quickstart.md`; add a "Migration from 2.x" section linking to `MIGRATION.md`
- [ ] T060 [US7] Update `CHANGELOG.md` at `packages/transfer_kit/CHANGELOG.md`: add a `## [3.0.0] - 2026-05-07` entry using the paste-ready template from `contracts/public_api_changes.md` (Breaking Changes, Added, Migration sections); link to `MIGRATION.md`

**Checkpoint**: `MIGRATION.md`, `README.md`, and `CHANGELOG.md` all reference version 3.0.0. `MIGRATION.md` includes the `FirebaseStorageDriver` example from `quickstart.md`.

---

## Phase 10: Polish & Validation

**Purpose**: Final formatting, analysis, test run, version bump, and mandatory constitution amendment.

- [ ] T061 Update `version` field in `pubspec.yaml` from `2.1.0+1` to `3.0.0`
- [ ] T062 [P] Run `dart format .` in `packages/transfer_kit/`; fix any formatting issues reported
- [ ] T063 [P] Run `flutter analyze` in `packages/transfer_kit/`; resolve all errors and confirm zero Firebase-related warnings
- [ ] T064 Run `flutter test` in `packages/transfer_kit/`; confirm full suite passes with zero failures and zero skipped tests
- [ ] T065 Search for `firebase_storage` and `cloud_firestore` in all Dart source files under `packages/transfer_kit/lib/`; if any matches remain, fix them before proceeding; document "zero Firebase imports" result
- [ ] T066 Amend `.specify/memory/constitution.md` Principle VI: replace the "Firebase Storage Integration Boundary" heading and all body text with "Provider Abstraction Boundary" describing the `TransferDriver` interface model as the abstraction boundary; record this as the mandatory post-task follow-up from `plan.md`

**Checkpoint**: All 7 Success Criteria from `spec.md` (SC-001 through SC-007) are satisfied. Version 3.0.0 is ready to tag.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user story phases
- **US1 (Phase 3)**: Depends on Phase 2 — foundational contracts must compile first
- **US2 (Phase 4)**: Depends on Phase 2 — can run **in parallel with US1** (different files: `lib/src/drivers/`)
- **US3 (Phase 5)**: Depends on Phase 3 — lifecycle code is in `file_task_repository.dart` modified in US1
- **US4 (Phase 6)**: Depends on Phase 2 (`FakeTransferDriver` in T012) and Phase 3 (Firebase removed; tests run offline)
- **US5 (Phase 7)**: Depends on Phase 2 (contracts) and Phase 3 (capability checks in `file_task_repository.dart`)
- **US6 (Phase 8)**: Depends on Phase 3 (Firebase removed from repository layer)
- **US7 (Phase 9)**: Depends on Phases 3–8 complete (documentation describes final state)
- **Polish (Phase 10)**: Depends on all phases complete

### User Story Dependencies

- **US1 (P1)**: Depends on Foundational — implement first
- **US2 (P1)**: Depends on Foundational — parallel with US1 (entirely different file tree)
- **US3 (P2)**: Depends on US1 (same file: `file_task_repository.dart`)
- **US4 (P2)**: Depends on Foundational (T012) and US1 (Firebase removed before tests run offline)
- **US5 (P2)**: Depends on Foundational (T006, T010) and US1 (T018, T054, T055)
- **US6 (P3)**: Depends on US1 (T030 removes Firebase from pubspec)
- **US7 (P3)**: Depends on all P1–P2 stories

### Within Each Phase

- All `[P]`-marked tasks in a phase touch different files — launch together
- Contract files T005–T010 are fully independent — launch all six at once
- Driver tasks T032–T035 (HTTP) and T036–T039 (local copy) are independent of each other — launch both groups together
- Test files T047–T051 are all independent — launch all five at once
- Firebase extension cleanup T024–T026 and service reviews T028–T029 are independent — launch all together after T023

### Parallel Opportunities

```bash
# Phase 2: All contract files at once
T005: lib/src/core/driver/transfer_driver.dart
T006: lib/src/core/driver/transfer_capabilities.dart
T007: lib/src/core/driver/download_request.dart
T008: lib/src/core/driver/upload_request.dart
T009: lib/src/core/driver/transfer_progress_event.dart
T010: lib/src/core/exception/unsupported_capability_exception.dart

# Phase 3 cleanup (after T023 deletes Firebase files):
T024: date_time_extension.dart
T025: dynamic_extension.dart
T026: map_extension.dart
T028: task_management_service.dart
T029: background_transfer_service.dart

# Phase 4: Both drivers in parallel
T032–T035: lib/src/drivers/http_download_driver.dart
T036–T039: lib/src/drivers/local_file_copy_driver.dart

# Phase 6: All test files in parallel
T047: test/src/lifecycle/task_lifecycle_test.dart
T048: test/src/capabilities/unsupported_capability_test.dart
T049: test/src/cache/cache_without_firebase_test.dart
T050: test/src/driver/http_download_driver_test.dart
T051: test/src/driver/local_file_copy_driver_test.dart
```

---

## Implementation Strategy

### MVP First (US1 + US2 Only — Firebase Removed, Built-in Drivers Working)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational — contracts compile, `FakeTransferDriver` available
3. Complete Phase 3: US1 — remove Firebase; `flutter analyze` clean
4. Complete Phase 4: US2 — add `HttpDownloadDriver` and `LocalFileCopyDriver`
5. **STOP and VALIDATE**: `flutter pub get` + `flutter analyze` + zero Firebase imports
6. Release 3.0.0-alpha for early adopters

### Incremental Delivery

1. Foundation ready (Phase 1–2) → contracts compile, fake driver available
2. Firebase removed (Phase 3) → package is provider-agnostic ← **breaking point**
3. Built-in drivers added (Phase 4) → usable without custom driver
4. Lifecycle + tests (Phase 5–6) → full confidence in migration correctness
5. Capabilities + cache hardened (Phase 7–8) → production-safe
6. Docs complete (Phase 9) → 3.0.0 ready to tag
7. Polish (Phase 10) → release

### Parallel Team Strategy

After Foundational (Phase 2) is complete:
- **Developer A**: Phase 3 (US1 — Firebase removal in `lib/src/repository/` and `lib/src/model/`)
- **Developer B**: Phase 4 (US2 — built-in drivers in `lib/src/drivers/`)
- Both merge, then Phase 5–7 proceed sequentially (shared `file_task_repository.dart`)

---

## Notes

- `[P]` tasks touch different files with no mutual dependencies
- `[Story]` label maps each task to a user story for traceability
- `FakeTransferDriver` (T012) lives only in `test/src/fake/` — it is **NOT** exported from `lib/transfer_kit.dart`; consumers write their own fakes or copy the reference implementation
- The temporary `_FirebaseTransferDriverAdapter` introduced in T015 is deleted in T023; it exists only to keep the package compiling during the Phase 3 migration window
- Firebase repository files deleted in T021–T022 are internal (never exported); their deletion does not directly break the public API
- The version discrepancy in `spec.md` Assumption ("2.0.0") is a spec artifact; all implementation tasks use **3.0.0** per `plan.md`, `research.md`, and `contracts/public_api_changes.md`
- Constitution amendment (T066) is **mandatory** per `plan.md` Post-task follow-up; do not skip it
- Task Group mapping from user prompt: Group 1 → T004; Group 2 → T005–T011; Group 3 → T012, T047–T051; Group 4 → T016–T018; Group 5 → T021–T031; Group 6 → T052–T055; Group 7 → T058–T060; Group 8 → T062–T065
