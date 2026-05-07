# Data Model: Provider-Agnostic Transfer Core

**Phase 1 output** | **Date**: 2026-05-07 | **Plan**: [plan.md](plan.md)

## New Entities

### TransferDriver

Abstract interface implemented by any storage provider.

```
TransferDriver
├── capabilities: TransferCapabilities          [read-only]
├── download(DownloadRequest) → Stream<TransferProgressEvent>
├── upload(UploadRequest) → Stream<TransferProgressEvent>
├── pause(taskId: String) → Future<void>
├── resume(taskId: String) → Future<void>
└── cancel(taskId: String) → Future<void>
```

**Constraints**:
- `download()` and `upload()` MUST throw `UnsupportedCapabilityException` if the respective capability flag is `false`.
- `pause()`, `resume()`, `cancel()` MUST throw `UnsupportedCapabilityException` if the respective flag is `false`.
- The returned stream MUST close after emitting a `TransferCompleted` or `TransferFailed` event.
- Auth credentials are NOT accepted as parameters — supplied at construction time.

---

### TransferCapabilities

Immutable value object attached to each `TransferDriver`. All fields default to `false`; drivers declare only what they support.

```
TransferCapabilities
├── supportsUpload: bool                  [default: false]
├── supportsDownload: bool                [default: false]
├── supportsPause: bool                   [default: false]
├── supportsResume: bool                  [default: false]
├── supportsCancel: bool                  [default: false]
├── supportsProgress: bool                [default: false]
├── supportsBackgroundTransfer: bool      [default: false, reserved for future]
└── supportsRetry: bool                   [default: false]
```

**Constraints**:
- `supportsResume` MUST NOT be `true` if `supportsPause` is `false` (resume is meaningless without pause).
- `supportsBackgroundTransfer` is a reserved extension point. No built-in driver declares it `true` in version 3.0.0.

---

### DownloadRequest

Describes a file to download. Contains no auth or credential fields.

```
DownloadRequest
├── taskId: String                        [required, unique per transfer]
├── source: Uri                           [required, remote location]
├── localPath: String?                    [optional, driver picks path if null]
├── cacheKey: String?                     [optional, defaults to source.toString()]
└── metadata: Map<String, Object?>        [optional, driver-specific passthrough]
```

**Constraints**:
- `taskId` MUST be unique within the active task set. Duplicate IDs produce undefined behavior.
- `metadata` MUST NOT contain credentials. Auth belongs in the driver's constructor.

---

### UploadRequest

Describes a local file to upload. Contains no auth or credential fields.

```
UploadRequest
├── taskId: String                        [required, unique per transfer]
├── localPath: String                     [required, source file on device]
├── destination: Uri?                     [optional, for URL-addressed drivers]
├── destinationPath: String?              [optional, for path-addressed drivers]
└── metadata: Map<String, Object?>        [optional, driver-specific passthrough]
```

**Constraints**:
- At least one of `destination` or `destinationPath` SHOULD be provided for drivers that need a remote target.
- `metadata` MUST NOT contain credentials.

---

### TransferProgressEvent (sealed class hierarchy)

Terminal/progress events emitted by `TransferDriver.download()` and `TransferDriver.upload()`.

```
TransferProgressEvent (sealed)
├── taskId: String                        [all subtypes]
│
├── TransferProgressUpdate
│   ├── bytesTransferred: int
│   ├── totalBytes: int
│   └── percentage: double               [derived: bytesTransferred / totalBytes]
│
├── TransferCompleted
│   ├── localPath: String?               [set for downloads]
│   ├── remoteIdentifier: String?        [set for uploads, e.g. download URL]
│   └── metadata: Map<String, Object?>   [driver-specific result data]
│
└── TransferFailed
    ├── error: Object
    └── stackTrace: StackTrace?
```

**Constraints**:
- A driver that declares `supportsProgress: false` MUST NOT emit `TransferProgressUpdate` events.
- After emitting `TransferCompleted` or `TransferFailed`, the stream MUST close.
- `TransferProgressUpdate.totalBytes` MAY be `0` if total size is unknown (e.g., chunked encoding).

---

### UnsupportedCapabilityException

Thrown synchronously when an operation is attempted on a driver that does not declare support.

```
UnsupportedCapabilityException
├── message: String                       [human-readable description]
└── capability: String?                   [e.g., "supportsPause", "supportsUpload"]
```

---

## Modified Entities

### FileTask (modified)

Fields and methods removed in 3.0.0:

| Removed member | Reason |
| --- | --- |
| `task: Task?` (Firebase `UploadTask \| DownloadTask`) | Firebase-specific; driver manages underlying task internally |
| `firebaseTask({bool justCheck})` | Firebase-specific method |
| `reference` → `Reference` | Firebase Storage reference; no generic equivalent |
| `.upload(UploadTask? task)` named constructor | Firebase-typed parameter |

All other `FileTask` fields are preserved unchanged.

---

## Built-in Driver Entities

### HttpDownloadDriver

```
HttpDownloadDriver
├── constructor(headers: Map<String, String>)    [optional auth headers]
└── capabilities:
    ├── supportsDownload: true
    ├── supportsCancel: true
    ├── supportsProgress: true
    └── all others: false
```

**Behavior**:
- Downloads from any `http://` or `https://` URI.
- Emits `TransferProgressUpdate` events as bytes arrive.
- Writes to `localPath` from `DownloadRequest`; if null, writes to a temp directory path derived from `taskId`.
- On cancel: terminates HTTP connection and emits `TransferFailed` with a cancellation error.
- `upload()` throws `UnsupportedCapabilityException`.

---

### LocalFileCopyDriver

```
LocalFileCopyDriver
└── capabilities:
    ├── supportsUpload: true      [copies localPath → destinationPath]
    ├── supportsDownload: true    [copies source (as local path) → localPath]
    ├── supportsCancel: true
    ├── supportsProgress: true
    └── all others: false
```

**Behavior**:
- Copies files on-device. No network I/O.
- For download: treats `DownloadRequest.source` as a local file URI (`file://...`) and copies to `localPath`.
- For upload: copies `UploadRequest.localPath` to `UploadRequest.destinationPath`.
- Emits synthetic progress events at configurable chunk intervals.
- Serves as the canonical reference implementation for custom driver authors.

---

### FakeTransferDriver (test utility — not in main barrel)

```
FakeTransferDriver
├── constructor(
│     shouldFail: bool,
│     supportsPause: bool,
│     progressSteps: int,
│     delay: Duration,
│   )
└── capabilities:
    ├── supportsDownload: true
    ├── supportsUpload: true
    ├── supportsCancel: true
    ├── supportsPause: configurable
    ├── supportsProgress: true
    └── supportsRetry: true
```

**Behavior**:
- Emits `progressSteps` `TransferProgressUpdate` events separated by `delay`.
- If `shouldFail: true`: emits `TransferFailed` instead of `TransferCompleted`.
- If `supportsPause: false` and `pause()` is called: throws `UnsupportedCapabilityException`.
- Tracks call counts for assertion in tests (`downloadCallCount`, `cancelCallCount`, etc.).

---

## State Transitions (preserved)

The `FileTask` lifecycle state machine is unchanged. Driver events map to states as follows:

| Driver event | FileTask state transition |
| --- | --- |
| Transfer queued (before driver called) | `waiting` |
| Driver `download()`/`upload()` called | `waiting → running` |
| `TransferProgressUpdate` received | `running` (progress updated) |
| `TransferCompleted` received | `running → completed` |
| `TransferFailed` received | `running → error` |
| `cancel()` called | `running → cancelled` |
| `pause()` called | `running → paused` |
| `resume()` called | `paused → running` |
| Cache hit on request | `waiting → cached` |
| Retry initiated | `error → waiting` |
