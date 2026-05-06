// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'file_task.dart';

/// Represents the progress of multiple file downloads
class MultiDownloadFileTask {
  /// List of tasks, one for each file being downloaded
  final List<FileTask> tasks;

  /// List of completed tasks
  List<FileTask> get fileStatuses => tasks;

  /// The unique task ID for this operation
  final String taskId;

  /// The total number of bytes downloaded so far across all files
  final int totalBytesDownloaded;

  /// The total number of bytes to download across all files
  final int totalBytes;

  /// The overall percentage of downloads completed (0-100)
  final double overallProgressPercentage;

  /// Whether all downloads have completed
  final bool isComplete;

  /// List of completed file tasks
  List<FileTask> get completedTasks =>
      tasks.where((task) => task.isComplete).toList();

  /// Create a MultiDownloadProgress
  MultiDownloadFileTask({
    required this.tasks,
    required this.totalBytesDownloaded,
    required this.totalBytes,
    required this.overallProgressPercentage,
    required this.isComplete,
    required this.taskId,
  });

  /// Calculate the overall progress from a list of tasks
  factory MultiDownloadFileTask.fromTasks({
    required List<FileTask> tasks,
    required String taskId,
  }) {
    final totalBytes = tasks.fold<int>(0, (sum, task) => sum + task.totalBytes);
    final totalBytesDownloaded = tasks.fold<int>(
      0,
      (sum, task) => sum + task.bytesTransferred,
    );
    final isComplete =
        tasks.every((task) => task.isComplete) && tasks.isNotEmpty;

    final overallProgressPercentage = totalBytes > 0
        ? (totalBytesDownloaded / totalBytes) * 100
        : (isComplete ? 100.0 : 0.0);

    return MultiDownloadFileTask(
      tasks: tasks,
      totalBytesDownloaded: totalBytesDownloaded,
      totalBytes: totalBytes,
      overallProgressPercentage: overallProgressPercentage,
      isComplete: isComplete,
      taskId: taskId,
    );
  }

  @override
  String toString() {
    return 'MultiDownloadProgress(tasks: $tasks, totalBytesDownloaded: $totalBytesDownloaded, totalBytes: $totalBytes, overallProgressPercentage: $overallProgressPercentage, isComplete: $isComplete, taskId: $taskId)';
  }

  @override
  bool operator ==(Object other) =>
      other is MultiDownloadFileTask && other.hashCode == hashCode;

  @override
  int get hashCode => taskId.hashCode;
}
