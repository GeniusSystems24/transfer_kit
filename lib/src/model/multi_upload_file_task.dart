// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'file_task.dart';

/// Represents upload progress for multiple files
class MultiUploadFileTask {
  /// List of tasks, one for each file being uploaded
  final List<FileTask> tasks;

  int get length => tasks.length;

  /// The unique task ID for this operation
  final String taskId;

  /// Total bytes uploaded so far across all files
  final int totalBytesUploaded;

  /// Total bytes to upload across all files
  final int totalBytes;

  /// Overall progress percentage (0-100) across all files
  final double overallProgressPercentage;

  /// Whether all files have completed uploading
  final bool isComplete;

  /// List of completed file tasks
  List<FileTask> get completedTasks => tasks
      .where(
        (task) => task.isComplete || task.downloadUrl?.isNotEmpty == true,
      )
      .toList();

  /// Number of files that were retrieved from cache instead of uploaded
  int get cachedFileCount => tasks.where((task) => task.isCached).length;

  /// Whether all files were retrieved from cache
  bool get allFilesFromCache =>
      tasks.isNotEmpty && tasks.every((task) => task.isCached);

  /// Download URLs for all completed files (including cached ones)
  List<String> get downloadUrls {
    return tasks
        .where((task) => task.isComplete && task.downloadUrl != null)
        .map((task) => task.downloadUrl!)
        .toList();
  }

  /// Create a MultiUploadProgress
  MultiUploadFileTask({
    required this.tasks,
    required this.totalBytesUploaded,
    required this.totalBytes,
    required this.overallProgressPercentage,
    required this.isComplete,
    required this.taskId,
  });

  /// Calculate the overall progress from a list of tasks
  factory MultiUploadFileTask.fromTasks({
    required List<FileTask> tasks,
    required String taskId,
  }) {
    final totalBytes = tasks.fold<int>(0, (sum, task) => sum + task.totalBytes);
    final totalBytesUploaded = tasks.fold<int>(
      0,
      (sum, task) => sum + task.bytesTransferred,
    );
    final isComplete = tasks.isEmpty || tasks.every((task) => task.isComplete);

    final overallProgressPercentage = totalBytes > 0
        ? (totalBytesUploaded / totalBytes) * 100
        : (isComplete ? 100.0 : 0.0);

    return MultiUploadFileTask(
      tasks: tasks,
      totalBytesUploaded: totalBytesUploaded,
      totalBytes: totalBytes,
      overallProgressPercentage: overallProgressPercentage,
      isComplete: isComplete,
      taskId: taskId,
    );
  }

  @override
  String toString() {
    return 'MultiUploadProgress(tasks: $tasks, totalBytesUploaded: $totalBytesUploaded, totalBytes: $totalBytes, overallProgressPercentage: $overallProgressPercentage, isComplete: $isComplete, taskId: $taskId, cachedFileCount: $cachedFileCount)';
  }

  @override
  bool operator ==(Object other) =>
      other is MultiUploadFileTask && other.hashCode == hashCode;

  @override
  int get hashCode => taskId.hashCode;
}
