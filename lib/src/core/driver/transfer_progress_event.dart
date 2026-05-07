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
