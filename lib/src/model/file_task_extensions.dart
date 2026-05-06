import '../core/extension/file_path_extension.dart';

import 'file_model.dart';
import 'file_task.dart';

/// Extensions on FileTask to provide compatibility with legacy code
/// that was using DownloadProgress, UploadProgress, FileDownloadStatus, and FileUploadStatus
extension FileTaskProgressExtension on FileTask {
  // === For DownloadProgress compatibility ===

  /// Get the number of bytes downloaded
  int get bytesDownloaded => bytesTransferred;

  /// Check if the download is complete
  bool get isDownloadComplete => isComplete;

  /// Get the download URL
  String get downloadURL => downloadUrl ?? '';

  /// Get the size of the downloaded data in MB
  double get downloadedSizeMB => bytesTransferred / (1024 * 1024);

  /// Get the total size of the file in MB
  double get totalSizeMB => totalBytes / (1024 * 1024);

  // === For UploadProgress compatibility ===

  /// Get the number of bytes uploaded
  int get bytesUploaded => bytesTransferred;

  /// Check if the upload is complete
  bool get isUploadComplete => isComplete;

  /// Get the size of the uploaded data in MB
  double get uploadedSizeMB => bytesTransferred / (1024 * 1024);

  /// The FileType of the file
  FileTypeEnum get fileType => filePath.getFileType() ?? FileTypeEnum.file;

  /// Check if the task has started (compatibility with FileUploadStatus/FileDownloadStatus)
  bool get hasStarted => state != FileTaskState.waiting;
}

/// Extension to create tasks with specific indices for list views
extension IndexedFileTaskExtension on FileTask {
  /// Create a task with an index
  static FileTaskWithIndex withIndex(FileTask task, int index) {
    return FileTaskWithIndex(task: task, index: index);
  }
}

/// A FileTask with an associated index for tracking in multi-file operations
class FileTaskWithIndex extends FileTask {
  /// The index of this task in a batch operation
  final int index;

  /// Create a FileTaskWithIndex
  FileTaskWithIndex({required this.index, required super.task})
    : super.fromTask();

  /// Create a FileTaskWithIndex from a FileTask with an index
  static FileTaskWithIndex withIndex(FileTask task, int index) {
    return FileTaskWithIndex(task: task, index: index);
  }

  @override
  String toString() {
    return 'FileTaskWithIndex(fileIndex: $index, task: ${super.toString()})';
  }

  @override
  bool operator ==(Object other) =>
      other is FileTaskWithIndex && other.hashCode == hashCode;

  @override
  int get hashCode => Object.hash(id, index);
}
