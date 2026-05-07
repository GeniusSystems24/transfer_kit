# Contract: TransferDriver API

**Phase 1 output** | **Date**: 2026-05-07 | **Plan**: [../plan.md](../plan.md)

This document defines the exact public interface contract for `TransferDriver` and its supporting types. Implementations MUST satisfy all constraints. The Dart signatures below are normative — the implementation files must match these exactly.

---

## TransferDriver

```dart
/// A provider-agnostic file transfer driver.
///
/// Implement this interface to integrate any storage backend with TransferKit.
/// Authentication and backend-specific configuration are supplied at driver
/// construction time. [DownloadRequest] and [UploadRequest] contain no
/// credential fields.
///
/// ## Implementing a driver
///
/// ```dart
/// class MyHttpUploadDriver implements TransferDriver {
///   MyHttpUploadDriver({required String apiToken})
///       : _headers = {'Authorization': 'Bearer $apiToken'};
///
///   final Map<String, String> _headers;
///
///   @override
///   TransferCapabilities get capabilities => const TransferCapabilities(
///         supportsUpload: true,
///         supportsProgress: true,
///         supportsCancel: true,
///       );
///
///   @override
///   Stream<TransferProgressEvent> upload(UploadRequest request) async* {
///     // emit TransferProgressUpdate events, then TransferCompleted or TransferFailed
///   }
///
///   @override
///   Stream<TransferProgressEvent> download(DownloadRequest request) =>
///       throw UnsupportedCapabilityException(
///         'This driver does not support download.',
///         capability: 'supportsDownload',
///       );
///
///   // ... pause/resume/cancel similarly throw UnsupportedCapabilityException
/// }
/// ```
abstract interface class TransferDriver {
  /// Declares which operations this driver supports.
  ///
  /// This value MUST be constant or effectively immutable after construction.
  TransferCapabilities get capabilities;

  /// Downloads a file and emits progress events until completion or failure.
  ///
  /// The returned stream MUST close after emitting a [TransferCompleted] or
  /// [TransferFailed] event. Intermediate [TransferProgressUpdate] events are
  /// emitted only if [capabilities.supportsProgress] is `true`.
  ///
  /// Throws [UnsupportedCapabilityException] synchronously if
  /// [capabilities.supportsDownload] is `false`.
  Stream<TransferProgressEvent> download(DownloadRequest request);

  /// Uploads a local file and emits progress events until completion or failure.
  ///
  /// The returned stream MUST close after emitting a [TransferCompleted] or
  /// [TransferFailed] event.
  ///
  /// Throws [UnsupportedCapabilityException] synchronously if
  /// [capabilities.supportsUpload] is `false`.
  Stream<TransferProgressEvent> upload(UploadRequest request);

  /// Pauses the transfer identified by [taskId].
  ///
  /// Throws [UnsupportedCapabilityException] if [capabilities.supportsPause]
  /// is `false`. Calling this on a task that is not running is a no-op (does
  /// not throw).
  Future<void> pause(String taskId);

  /// Resumes the transfer identified by [taskId].
  ///
  /// Throws [UnsupportedCapabilityException] if [capabilities.supportsResume]
  /// is `false`. Calling this on a task that is not paused is a no-op.
  Future<void> resume(String taskId);

  /// Cancels the transfer identified by [taskId].
  ///
  /// Throws [UnsupportedCapabilityException] if [capabilities.supportsCancel]
  /// is `false`. Calling this on a completed task is a no-op.
  Future<void> cancel(String taskId);
}
```

---

## TransferCapabilities

```dart
/// Declares which operations a [TransferDriver] supports.
///
/// All flags default to `false`. Drivers declare only what they support.
///
/// ## Invariants
///
/// - [supportsResume] MUST NOT be `true` when [supportsPause] is `false`.
/// - [supportsBackgroundTransfer] is a reserved extension point. No built-in
///   driver declares it `true` in version 3.0.0.
@immutable
class TransferCapabilities {
  const TransferCapabilities({
    this.supportsUpload = false,
    this.supportsDownload = false,
    this.supportsPause = false,
    this.supportsResume = false,
    this.supportsCancel = false,
    this.supportsProgress = false,
    this.supportsBackgroundTransfer = false,
    this.supportsRetry = false,
  }) : assert(
          !supportsResume || supportsPause,
          'supportsResume requires supportsPause to be true',
        );

  final bool supportsUpload;
  final bool supportsDownload;
  final bool supportsPause;
  final bool supportsResume;
  final bool supportsCancel;

  /// Whether the driver emits [TransferProgressUpdate] events.
  final bool supportsProgress;

  /// Reserved for OS-level background transfer (WorkManager / NSURLSession).
  /// No built-in driver declares this `true` in version 3.0.0.
  /// Custom drivers that implement background transfer may set this to `true`.
  final bool supportsBackgroundTransfer;

  final bool supportsRetry;
}
```

---

## DownloadRequest

```dart
/// A request to download a file to a local path.
///
/// Contains no authentication or credential fields — those belong in the
/// [TransferDriver] constructor.
@immutable
class DownloadRequest {
  const DownloadRequest({
    required this.taskId,
    required this.source,
    this.localPath,
    this.cacheKey,
    this.metadata = const {},
  });

  /// Unique identifier for this transfer task.
  ///
  /// MUST be unique within the active task set. Reusing a [taskId] for a
  /// different transfer produces undefined behavior.
  final String taskId;

  /// Remote location to download from.
  ///
  /// Interpretation is driver-specific (e.g., `https://`, `gs://`, `file://`).
  final Uri source;

  /// Desired local file path after download completes.
  ///
  /// If `null`, the driver chooses a path (typically in the app's temp
  /// directory). The chosen path is reported in [TransferCompleted.localPath].
  final String? localPath;

  /// Cache lookup key. Defaults to [source.toString()] when `null`.
  final String? cacheKey;

  /// Arbitrary passthrough metadata for the driver.
  ///
  /// MUST NOT contain credentials or tokens.
  final Map<String, Object?> metadata;
}
```

---

## UploadRequest

```dart
/// A request to upload a local file to a remote destination.
///
/// Contains no authentication or credential fields.
@immutable
class UploadRequest {
  const UploadRequest({
    required this.taskId,
    required this.localPath,
    this.destination,
    this.destinationPath,
    this.metadata = const {},
  });

  /// Unique identifier for this transfer task.
  final String taskId;

  /// Absolute path to the local file to upload.
  final String localPath;

  /// Remote URI destination (for URL-addressed drivers).
  final Uri? destination;

  /// Remote path string (for path-addressed drivers).
  final String? destinationPath;

  /// Arbitrary passthrough metadata for the driver.
  ///
  /// MUST NOT contain credentials or tokens.
  final Map<String, Object?> metadata;
}
```

---

## TransferProgressEvent

```dart
/// An event emitted by [TransferDriver.download] or [TransferDriver.upload].
///
/// The stream closes after a [TransferCompleted] or [TransferFailed] event.
sealed class TransferProgressEvent {
  const TransferProgressEvent(this.taskId);
  final String taskId;
}

/// An intermediate progress update.
///
/// Only emitted when [TransferCapabilities.supportsProgress] is `true`.
final class TransferProgressUpdate extends TransferProgressEvent {
  const TransferProgressUpdate({
    required String taskId,
    required this.bytesTransferred,
    required this.totalBytes,
  }) : super(taskId);

  final int bytesTransferred;

  /// Total expected bytes. May be `0` if size is unknown (e.g., chunked).
  final int totalBytes;

  /// Transfer completion fraction in `[0.0, 1.0]`.
  ///
  /// Returns `0.0` when [totalBytes] is `0`.
  double get percentage =>
      totalBytes > 0 ? bytesTransferred / totalBytes : 0.0;
}

/// Emitted when the transfer completes successfully.
///
/// This is the terminal success event. The stream closes after this event.
final class TransferCompleted extends TransferProgressEvent {
  const TransferCompleted({
    required String taskId,
    this.localPath,
    this.remoteIdentifier,
    this.metadata = const {},
  }) : super(taskId);

  /// Local file path where the downloaded file was written.
  /// Set for downloads; `null` for uploads (unless the driver provides it).
  final String? localPath;

  /// Remote identifier for the uploaded file (e.g., a download URL or storage path).
  /// Set for uploads; `null` for downloads.
  final String? remoteIdentifier;

  /// Driver-specific result metadata.
  final Map<String, Object?> metadata;
}

/// Emitted when the transfer fails.
///
/// This is the terminal failure event. The stream closes after this event.
final class TransferFailed extends TransferProgressEvent {
  const TransferFailed({
    required String taskId,
    required this.error,
    this.stackTrace,
  }) : super(taskId);

  final Object error;
  final StackTrace? stackTrace;
}
```

---

## UnsupportedCapabilityException

```dart
/// Thrown when an operation is attempted on a [TransferDriver] that does not
/// declare support for it via [TransferCapabilities].
///
/// Always thrown synchronously — never async.
class UnsupportedCapabilityException implements Exception {
  const UnsupportedCapabilityException(
    this.message, {
    this.capability,
  });

  /// Human-readable description of the unsupported operation.
  final String message;

  /// The capability flag name that was `false`, e.g. `'supportsPause'`.
  final String? capability;

  @override
  String toString() {
    final cap = capability != null ? ' [$capability]' : '';
    return 'UnsupportedCapabilityException$cap: $message';
  }
}
```

---

## Built-in Driver Capability Declarations

### HttpDownloadDriver

```dart
static const TransferCapabilities _capabilities = TransferCapabilities(
  supportsDownload: true,
  supportsCancel: true,
  supportsProgress: true,
);
```

### LocalFileCopyDriver

```dart
static const TransferCapabilities _capabilities = TransferCapabilities(
  supportsUpload: true,
  supportsDownload: true,
  supportsCancel: true,
  supportsProgress: true,
);
```
