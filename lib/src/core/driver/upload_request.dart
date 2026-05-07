import 'package:flutter/foundation.dart';

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
