import 'dart:async';

import 'package:uuid/uuid.dart';

import '../model/file_task.dart';
import '../repository/file_task_repository.dart';

class TaskManagementService {
  // Singleton instance
  static final TaskManagementService instance =
      TaskManagementService._internal();
  TaskManagementService._internal();

  /// In-memory task list
  Set<FileTask> get tasks => FileTaskRepository.instance.value;

  /// Task status stream controller
  // StreamController<Set<FileTask>> get controller => FileTaskRepository.instance._controller;
  Stream<Set<FileTask>> get stream => FileTaskRepository.instance.stream;

  /// Get a task stream by ID
  Stream<FileTask?> getTaskStreamById(String taskId) =>
      FileTaskRepository.instance.getTaskStreamById(taskId);

  /// Get a task stream by file path
  Stream<FileTask?> getTaskStreamByFilePath(String filePath) =>
      FileTaskRepository.instance.getTaskStreamByFilePath(filePath);

  /// Get a task stream by destination path
  Stream<FileTask?> getTaskStreamByDestinationPath(String destinationPath) =>
      FileTaskRepository.instance.getTaskStreamByDestinationPath(
        destinationPath,
      );

  /// Get a download task stream by download url
  Stream<FileTask?> getDownloadTaskStreamByUrl(String downloadUrl) =>
      FileTaskRepository.instance.getDownloadTaskStreamByUrl(downloadUrl);

  /// Get a upload task stream by file path
  Stream<FileTask?> getUploadTaskStreamByFilePath(String filePath) =>
      FileTaskRepository.instance.getUploadTaskStreamByFilePath(filePath);

  // Task filters

  /// Get upload tasks
  Set<FileTask> getUploadTasks() =>
      FileTaskRepository.instance.getUploadTasks();

  /// Get download tasks
  Set<FileTask> getDownloadTasks() =>
      FileTaskRepository.instance.getDownloadTasks();

  /// Get active tasks
  Set<FileTask> getActiveTasks() =>
      FileTaskRepository.instance.getActiveTasks();

  /// Get completed tasks
  Set<FileTask> getCompletedTasks() =>
      FileTaskRepository.instance.getCompletedTasks();

  /// Get waiting tasks
  Set<FileTask> getWaitingTasks() =>
      FileTaskRepository.instance.getWaitingTasks();

  /// Get a task by ID
  FileTask? getTaskById(String taskId) =>
      FileTaskRepository.instance.getTaskById(taskId);

  /// Get tasks by group ID
  Set<FileTask> getTasksByGroupId(String groupId) =>
      FileTaskRepository.instance.getTasksByGroupId(groupId);

  /// Get upload tasks by group ID
  Set<FileTask> getUploadTasksByGroupId(String groupId) =>
      FileTaskRepository.instance.getUploadTasksByGroupId(groupId);

  /// Get download tasks by group ID
  Set<FileTask> getDownloadTasksByGroupId(String groupId) =>
      FileTaskRepository.instance.getDownloadTasksByGroupId(groupId);

  /// Get all unique group IDs
  Set<String> getAllGroupIds() =>
      FileTaskRepository.instance.getAllGroups().keys.toSet();

  /// Get task by path
  FileTask? getTaskByPath(String path) =>
      FileTaskRepository.instance.getTaskByPath(path);

  /// Get task by file path
  FileTask? getTaskByFilePath(String filePath) =>
      FileTaskRepository.instance.getTaskByFilePath(filePath);

  /// Get task by destination path
  FileTask? getTaskByDestinationPath(String destinationPath) =>
      FileTaskRepository.instance.getTaskByDestinationPath(destinationPath);

  /// Get task by download url
  FileTask? getTaskByDownloadUrl(String downloadUrl) =>
      FileTaskRepository.instance.getTaskByDownloadUrl(downloadUrl);

  /// Get a upload task by file path
  FileTask? getUploadTaskByFilePath(String filePath) {
    return FileTaskRepository.instance.getUploadTaskByFilePath(filePath);
  }

  /// Get a download task by URL
  FileTask? getDownloadTaskByUrl(String url) =>
      FileTaskRepository.instance.getDownloadTaskByUrl(url);

  /// Get a task by uploaded URL
  FileTask? getTaskByUploadedUrl(String url) =>
      FileTaskRepository.instance.getTaskByUploadedUrl(url);

  // Create a new upload task
  FileTask uploadFileTask(FileTask task) {
    if (task.type != FileTaskType.upload) {
      throw ArgumentError('Task is not an upload task');
    }
    task = task.copyWith();
    FileTaskRepository.instance.addOrUpdate(task);
    return task;
  }

  // Create a new download task
  FileTask downloadFileTask(FileTask task) {
    if (task.type != FileTaskType.download) {
      throw ArgumentError('Task is not a download task');
    }
    task = task.copyWith();
    FileTaskRepository.instance.addOrUpdate(task);
    return task;
  }

  // Create a pre-completed download task (for files we already have)
  FileTask createCompletedDownloadTask({
    required String url,
    required String localPath,
    required int fileSize,
    String? destinationPath,
    bool isCached = true,
    String? taskId,
    FileGroupInfo? group,
  }) {
    taskId ??= const Uuid().v4();

    // Create group info
    group ??= FileGroupInfo(id: taskId);

    // Create progress
    final progress = FileProgress(
      bytesTransferred: fileSize,
      totalBytes: fileSize,
    );

    // Create task
    final task = FileTask(
      id: taskId,
      downloadUrl: url,
      filePath: localPath,
      destinationPath: destinationPath,
      type: FileTaskType.download,
      state: FileTaskState.completed,
      progress: progress,
      group: group,
      createdAt: DateTime.now(),
    );

    FileTaskRepository.instance.addOrUpdate(task);

    return task;
  }

  // Add a new task
  Future<void> addTask(FileTask task) async {
    // Check if task with same ID already exists
    if (tasks.any((t) => t.id == task.id)) {
      return;
    }

    FileTaskRepository.instance.addOrUpdate(task);
  }

  // Update an existing task in the list
  Future<void> updateTaskObject(FileTask updatedTask) async {
    FileTaskRepository.instance.addOrUpdate(updatedTask);
  }

  // Remove a task
  Future<void> removeTask(String taskId) async {
    FileTaskRepository.instance.removeById(taskId);
  }

  // Task control operations

  // Start a task
  Future<bool> startTask(String taskId) async {
    final task = getTaskById(taskId);
    if (task == null ||
        !(task.isWaiting ||
            task.isPaused ||
            task.isError ||
            task.isCancelled)) {
      return false;
    }

    // Update task state
    task.state = FileTaskState.running;
    return true;
  }

  // Pause a running task
  Future<bool> pauseTask(String taskId) async {
    final task = getTaskById(taskId);
    if (task == null || !task.isRunning) {
      return false;
    }

    // Update task state
    task.state = FileTaskState.paused;
    return true;
  }

  // Resume a paused task
  Future<bool> resumeTask(String taskId) async {
    final task = getTaskById(taskId);
    if (task == null || !task.isPaused) {
      return false;
    }

    // Update task state
    task.state = FileTaskState.running;
    return true;
  }

  // Cancel a task
  Future<bool> cancelTask(String taskId) async {
    final task = getTaskById(taskId);
    if (task == null || task.isComplete || task.isCancelled) {
      return false;
    }

    // Update task state
    task.state = FileTaskState.cancelled;
    return true;
  }

  // Retry a failed or cancelled task
  Future<bool> retryTask(String taskId) async {
    final task = getTaskById(taskId);
    if (task == null || !(task.isError || task.isCancelled)) {
      return false;
    }

    // Update task state
    task.state = FileTaskState.running;
    task.progress.bytesTransferred = 0;

    return true;
  }

  // Batch operations

  // Start all waiting tasks
  Future<int> startAllWaitingTasks() async {
    final waitingTasks = getWaitingTasks();
    var started = 0;

    for (var task in waitingTasks) {
      if (await startTask(task.id)) {
        started++;
      }
    }

    return started;
  }

  // Pause all running tasks
  Future<int> pauseAllRunningTasks() async {
    final runningTasks = tasks.where((task) => task.isRunning).toList();
    var paused = 0;

    for (var task in runningTasks) {
      if (await pauseTask(task.id)) {
        paused++;
      }
    }

    return paused;
  }

  // Cancel all active tasks
  Future<int> cancelAllActiveTasks() async {
    final activeTasks = tasks
        .where((task) => task.isRunning || task.isPaused || task.isWaiting)
        .toList();
    var cancelled = 0;

    for (var task in activeTasks) {
      if (await cancelTask(task.id)) {
        cancelled++;
      }
    }

    return cancelled;
  }

  /// Clear completed tasks
  int clearCompletedTasks() =>
      FileTaskRepository.instance.clearCompletedTasks();

  // Persistence operations

  // Clear all tasks
  int clearAllTasks() => FileTaskRepository.instance.clear();

  /// Pause all running tasks in a group
  Future<void> pauseTasksByGroupId(String groupId) async {
    final groupTasks = tasks
        .where((task) => task.groupId == groupId && task.isRunning)
        .toList();
    for (var task in groupTasks) {
      await pauseTask(task.id);
    }
  }

  /// Resume all paused tasks in a group
  Future<void> resumeTasksByGroupId(String groupId) async {
    final groupTasks = tasks
        .where(
          (task) =>
              task.groupId == groupId && (task.isPaused || task.isWaiting),
        )
        .toList();
    for (var task in groupTasks) {
      await startTask(task.id);
    }
  }

  /// Cancel all tasks in a group
  Future<void> cancelTasksByGroupId(String groupId) async {
    final groupTasks = tasks
        .where(
          (task) =>
              task.groupId == groupId && !task.isComplete && !task.isCancelled,
        )
        .toList();
    for (var task in groupTasks) {
      await cancelTask(task.id);
    }
  }
}
