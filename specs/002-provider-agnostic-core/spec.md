# Feature Specification: Provider-Agnostic Transfer Core

**Feature Branch**: `002-provider-agnostic-core`
**Created**: 2026-05-07
**Status**: Draft
**Input**: User description: "Remove direct Firebase handling from TransferKit and redesign the transfer core to be provider-agnostic."

## Clarifications

### Session 2026-05-07

- Q: Should Firebase support be completely removed from this package, or should a temporarily deprecated Firebase adapter remain within the package itself? → A: Complete removal — zero Firebase code in this package in any form (no adapters, deprecated paths, or compatibility wrappers). The migration guide is the bridge for existing users.
- Q: Is this a breaking change requiring a major version bump? → A: Yes — this is a breaking change. The package version advances to `2.0.0`.
- Q: Should the package ship any built-in driver implementations, or provide only the abstract interface? → A: Ship two built-in drivers: an HTTP download driver and a local file copy driver (on-device source-to-destination copy).
- Q: How should authentication credentials be supplied to a driver? → A: Driver constructor configuration only. Each driver is instantiated with its own auth setup (headers, tokens, signing logic). `TransferRequest` contains no auth fields and remains fully generic.
- Q: How should background transfer capability be handled in this version? → A: The `supportsBackgroundTransfer` flag is kept in the `TransferCapabilities` interface as a future extension point. No built-in driver in `2.0.0` declares support for it. Background transfer is documented as provider-dependent and out of scope for this version.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Use TransferKit Without Firebase (Priority: P1)

A Flutter developer who wants to integrate file transfer into their app without adding Firebase as a dependency. They use TransferKit and plug in their own backend provider (HTTP, custom server, etc.). The package does not force them to set up Firebase.

**Why this priority**: The core goal of this feature — if TransferKit's core still imports Firebase, all other stories are blocked. Removing that coupling is the prerequisite for everything else.

**Independent Test**: A developer creates a minimal Flutter app with `transfer_kit` in `pubspec.yaml` and no Firebase packages. They implement a simple `TransferDriver` using an HTTP backend. The app compiles, uploads a file, and receives a completion result — all without any Firebase dependency.

**Acceptance Scenarios**:

1. **Given** a Flutter project with `transfer_kit` and no Firebase packages, **When** a developer runs `flutter pub get`, **Then** no Firebase-related packages are pulled as transitive dependencies from `transfer_kit`.
2. **Given** a `TransferDriver` implemented using an HTTP client, **When** the developer passes it to `TransferKit`, **Then** uploads and downloads execute through that driver without any error.
3. **Given** the core `transfer_kit` source files, **When** static analysis runs, **Then** no imports of `firebase_storage` or `cloud_firestore` appear in any core file.

---

### User Story 2 - Generic Upload and Download With Progress (Priority: P1)

A developer uses the TransferKit upload and download APIs and receives real-time progress updates through a provider-neutral interface.

**Why this priority**: Upload and download are the primary operations the package exists to perform. Without functional generic transfer, the package has no value.

**Independent Test**: A developer uploads a file using a fake/test `TransferDriver`. They observe progress events (0% → 50% → 100%) emitted during the upload, and receive a `TransferResult` on completion. The same applies to downloads.

**Acceptance Scenarios**:

1. **Given** a `TransferDriver` that emits synthetic progress updates, **When** an upload is initiated, **Then** the transfer task stream emits `TransferProgress` events reflecting bytes transferred and total bytes.
2. **Given** an upload via any driver, **When** the upload completes successfully, **Then** the task stream emits a final `TransferResult` with a success state and generic output data.
3. **Given** a download via any driver, **When** the download completes, **Then** the caller receives the file at the expected local path.
4. **Given** a driver that reports an error mid-transfer, **When** the error occurs, **Then** the task stream transitions to an error state with the error captured.

---

### User Story 3 - Full Task Lifecycle Through Generic Abstractions (Priority: P2)

A developer uses the complete task lifecycle — waiting, running, paused, completed, error, cancelled, retry, grouped, and batch — without touching any Firebase API.

**Why this priority**: Task lifecycle management is a key differentiating feature of TransferKit. Removing Firebase must not break any of these states.

**Independent Test**: A developer creates a fake `TransferDriver` that supports pause and cancel signals. They initiate a task, pause it, resume it, and cancel it — observing all expected state transitions via the task stream.

**Acceptance Scenarios**:

1. **Given** a task that has not started, **When** it is queued, **Then** the task state is `waiting`.
2. **Given** a running task with a driver that supports pause, **When** `pause()` is called, **Then** the task transitions to the `paused` state.
3. **Given** a paused task, **When** `resume()` is called, **Then** the task transitions back to `running`.
4. **Given** any running task, **When** `cancel()` is called, **Then** the task transitions to `cancelled`.
5. **Given** a task that has failed, **When** the developer calls retry, **Then** the task re-enters `waiting` and is re-executed.
6. **Given** a group of tasks, **When** batch operations are triggered, **Then** all tasks in the group respond accordingly.
7. **Given** a driver that does not support pause, **When** `pause()` is called, **Then** the task throws a clear capability error rather than silently failing.

---

### User Story 4 - Tests Using Fake Transfer Providers (Priority: P2)

A package maintainer writes and runs unit tests for TransferKit's transfer logic using a fake/mock `TransferDriver` — no Firebase credentials or network required.

**Why this priority**: Testability validates the architecture. If the core depends on Firebase, testing without a live Firebase project is impractical.

**Independent Test**: The test suite runs with `flutter test` using only in-process fake drivers. No emulator, no network, no Firebase credentials are required. All task lifecycle states, progress events, and result values are exercised through the fake.

**Acceptance Scenarios**:

1. **Given** the fake `TransferDriver` is configured to succeed, **When** the test initiates an upload, **Then** the task progresses through `running → completed` and the result is verified.
2. **Given** the fake `TransferDriver` is configured to fail, **When** the test initiates a transfer, **Then** the task transitions to `error` and the captured error message matches expectations.
3. **Given** the fake driver that does not support pause, **When** `pause()` is called in a test, **Then** the test receives a capability error — not a silent no-op.
4. **Given** the full test suite, **When** it runs offline without any Firebase config, **Then** all provider-agnostic tests pass.

---

### User Story 5 - Driver Capability Model (Priority: P2)

A developer queries a driver's capabilities before calling unsupported operations, enabling them to adapt their UI or logic accordingly.

**Why this priority**: This is the mechanism that makes unsupported features explicit instead of silently broken.

**Independent Test**: A developer calls `driver.capabilities.supportsPause` before showing a pause button. On a driver that returns `false`, the pause button is hidden. When they call `pause()` on a driver that doesn't support it, they receive a clear error.

**Acceptance Scenarios**:

1. **Given** a driver, **When** a developer reads `driver.capabilities`, **Then** all capability flags (`supportsUpload`, `supportsDownload`, `supportsPause`, `supportsResume`, `supportsCancel`, `supportsBackgroundTransfer`, `supportsProgress`, `supportsRetry`) are present and have boolean values.
2. **Given** a driver with `supportsPause: false`, **When** `pause()` is called on a task managed by that driver, **Then** the operation throws a `UnsupportedCapabilityException` or equivalent typed error.
3. **Given** a driver with `supportsProgress: false`, **When** a transfer runs, **Then** the task stream emits only start and completion events — no intermediate progress events — without crashing.

---

### User Story 6 - Cache System Works Without Firebase (Priority: P3)

A developer uses TransferKit's URL/path cache to avoid re-downloading already-fetched files, and the cache operates independently of any transfer provider.

**Why this priority**: Cache behavior is a supporting feature. The core transfer must be provider-agnostic first; cache provider-agnosticism follows naturally.

**Independent Test**: A developer downloads a file using a fake driver, then queries the cache. The cached entry is found and returned without hitting the driver again. This works with no Firebase packages present.

**Acceptance Scenarios**:

1. **Given** a completed download, **When** the same file is requested again, **Then** the cache returns the locally stored path without invoking the driver.
2. **Given** a cached entry, **When** the entry is invalidated or expires, **Then** the next request re-triggers the driver.
3. **Given** the cache system with no Firebase packages, **When** it is initialized and queried, **Then** it operates correctly.

---

### User Story 7 - Migration Guide for Firebase Users (Priority: P3)

A developer who was using the Firebase-coupled version of TransferKit needs to migrate their app. They read the migration guide and understand what changed, why, and exactly how to adapt their code.

**Why this priority**: Migration guidance is documentation — valuable but not blocking the core implementation.

**Independent Test**: A team member who has not seen this project reads the migration guide and is able to update their code to use a custom HTTP driver in place of the Firebase driver — without asking for help.

**Acceptance Scenarios**:

1. **Given** the migration guide, **When** a developer reads it, **Then** they can identify every Firebase-specific class or method they were using and find the equivalent provider-agnostic replacement.
2. **Given** the migration guide, **When** a developer follows the "plug in a provider" instructions, **Then** their existing uploads/downloads resume working with their own backend.
3. **Given** the README.md, **When** a developer reads it, **Then** no text describes TransferKit as Firebase-only and the quickstart uses a generic driver.

---

### Edge Cases

- What happens when a driver is provided that supports neither upload nor download?
- How does the system handle a driver that reports `supportsProgress: true` but never emits progress events?
- What happens when `cancel()` is called on a task that has already completed?
- How does the cache behave when the driver returns a result with no stable identifier (e.g., no URL)?
- What happens when a batch operation partially fails — some tasks complete and others error?
- How does retry behave when a driver does not declare `supportsRetry`?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The package MUST contain zero Firebase code — no imports, no deprecated adapters, no compatibility wrappers, no conditional Firebase paths. Firebase is fully absent from this package in all forms.
- **FR-002**: The package MUST define a `TransferDriver` interface (or equivalent abstract type) that any provider can implement.
- **FR-003**: The `TransferDriver` interface MUST expose a `TransferCapabilities` object declaring: `supportsUpload`, `supportsDownload`, `supportsPause`, `supportsResume`, `supportsCancel`, `supportsBackgroundTransfer`, `supportsProgress`, `supportsRetry`. The `supportsBackgroundTransfer` flag is a reserved extension point — no built-in driver in `2.0.0` declares it `true`, and it is documented as provider-dependent for future implementors.
- **FR-004**: The package MUST define generic `UploadSource` and `DownloadSource` abstractions that are not tied to any storage provider.
- **FR-005**: The package MUST define a generic `TransferRequest` (describing what to transfer) and `TransferResult` (describing the outcome).
- **FR-006**: The package MUST define a `TransferProgress` type that carries bytes transferred, total bytes, and percentage.
- **FR-007**: Each transfer task MUST support the following lifecycle states: `waiting`, `running`, `paused`, `completed`, `error`, `cancelled`, `cached`, and retry-eligible.
- **FR-008**: Calling an operation not supported by the current driver (e.g., `pause()` on a driver with `supportsPause: false`) MUST throw a typed `UnsupportedCapabilityException`.
- **FR-009**: The cache system MUST operate without any Firebase dependency and MUST work with any driver.
- **FR-010**: The package MUST include a `FakeTransferDriver` (or equivalent test double) in the test utilities for use in automated tests.
- **FR-011**: All automated tests MUST pass without Firebase credentials, a Firebase emulator, or a network connection.
- **FR-012**: The package MUST include a migration guide document explaining what was removed, what replaces it, and how to create or plug in a custom provider.
- **FR-013**: Grouped and batch transfer operations MUST continue to work through the generic `TransferDriver` interface.
- **FR-014**: The package MUST preserve all previously public API surface that can be made provider-agnostic; only Firebase-specific APIs may be removed or moved to an optional adapter.
- **FR-015**: README.md MUST be updated to remove any Firebase-only framing and to document the generic driver approach.
- **FR-019**: `TransferRequest` MUST contain no authentication or credential fields. All auth configuration MUST be supplied to a driver at construction time (e.g., HTTP headers, tokens, signing callbacks). This keeps `TransferRequest` generic and reusable across any driver.
- **FR-017**: The package MUST ship a built-in `HttpDownloadDriver` that downloads files from any HTTP/HTTPS URL, emits progress updates, and writes the file to a caller-specified local path.
- **FR-018**: The package MUST ship a built-in `LocalFileCopyDriver` that copies a file from one on-device path to another, emits progress updates, and supports cancel. This driver also serves as the canonical reference implementation for custom driver authors.
- **FR-016**: CHANGELOG.md MUST document this as a major version (`2.0.0`), list every removed public API, and include a link to the migration guide.

### Key Entities

- **TransferDriver**: The abstract interface that any file transfer provider must implement. Declares capabilities and executes upload/download operations.
- **TransferCapabilities**: A data object attached to each `TransferDriver` listing which operations the driver supports.
- **UploadSource**: Describes what to upload (local file path, bytes, stream) in a provider-neutral way.
- **DownloadSource**: Describes what to download (remote identifier, URL, path) in a provider-neutral way.
- **TransferRequest**: A complete description of a transfer operation combining source, destination, and metadata. Contains no authentication or credential fields — those belong to the driver's constructor configuration.
- **TransferResult**: The outcome of a completed transfer — success state, output location or identifier, and any relevant metadata.
- **TransferProgress**: A snapshot of transfer progress: bytes transferred, total bytes, percentage complete.
- **TransferTask**: The running record of a transfer operation, including current state, progress stream, and result future.
- **HttpDownloadDriver**: A built-in driver that downloads files from any HTTP/HTTPS URL with progress reporting. Supports cancel; does not support upload, pause, or resume.
- **LocalFileCopyDriver**: A built-in driver that copies files between on-device paths with progress reporting. Supports cancel; serves as the canonical reference implementation for custom drivers.
- **FakeTransferDriver**: A test-only driver that simulates transfer behavior without any network or storage I/O.
- **UnsupportedCapabilityException**: Thrown when an operation is attempted on a driver that does not declare support for it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The core package passes static import analysis with zero imports of `firebase_storage` or `cloud_firestore` in non-adapter files.
- **SC-002**: All task lifecycle states (waiting, running, paused, completed, error, cancelled, cached, retry) are exercised in the automated test suite using only fake drivers — no Firebase project required.
- **SC-003**: A developer can integrate a custom HTTP-based driver and complete an upload/download in under 30 minutes by following the README alone.
- **SC-004**: Calling any unsupported driver capability always produces a typed exception — zero cases where unsupported operations silently succeed or fail without feedback.
- **SC-005**: The cache system returns locally stored files for previously completed transfers without invoking the driver — verified by test that confirms the driver is called exactly once per unique file.
- **SC-006**: The migration guide enables a developer familiar with the previous Firebase-coupled API to fully migrate their code without additional external help, as validated by a walkthrough review.
- **SC-007**: The full automated test suite passes with no network access and no Firebase credentials configured.

## Assumptions

- The package will continue to target Flutter (not pure Dart) as its primary runtime environment.
- Firebase support is completely absent from this package — no code, no deprecated wrappers, no conditional paths. Developers who need Firebase integration must implement their own `TransferDriver` adapter externally. A future sibling package may provide one, but that is out of scope for this task.
- The existing local caching mechanism (using `get_storage` and `path_provider`) will be retained as-is; only Firebase-specific cache integration points will be removed.
- Notification behavior is out of scope for this task and will not be redesigned.
- UI widgets that do not have Firebase-specific assumptions will not be changed.
- The package will continue to support the same minimum Flutter SDK version as before.
- This task is a breaking change. The package advances to version `2.0.0`. Provider-agnostic public APIs are preserved; all Firebase-specific APIs are removed immediately with no deprecation period.
- A full Firebase adapter package is out of scope for this task; the migration guide will explain how developers can build one themselves.
- Background transfer (OS-level WorkManager/NSURLSession integration) is out of scope for `2.0.0`. The `supportsBackgroundTransfer` capability flag is present in the interface as a future extension point but always returns `false` for all built-in drivers in this version.
