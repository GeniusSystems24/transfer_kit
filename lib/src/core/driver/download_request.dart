import 'package:flutter/foundation.dart';

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
