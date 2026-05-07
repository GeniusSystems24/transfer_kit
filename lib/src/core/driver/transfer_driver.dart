import 'download_request.dart';
import 'transfer_capabilities.dart';
import 'transfer_progress_event.dart';
import 'upload_request.dart';
import '../exception/unsupported_capability_exception.dart';

export 'download_request.dart';
export 'transfer_capabilities.dart';
export 'transfer_progress_event.dart';
export 'upload_request.dart';
export '../exception/unsupported_capability_exception.dart';

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
  /// is `false`. Calling this on a task that is not running is a no-op.
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
