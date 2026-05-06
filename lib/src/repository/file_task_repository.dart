import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../core/extension/file_path_extension.dart';
import '../core/extension/string_extension.dart';
import '../core/file_management_config.dart';
import '../core/get_storage_repository.dart';
import '../model/file_exception.dart';
import '../model/file_path_and_url.dart';
import '../model/file_task.dart';
import 'file_path_and_url_repository.dart';

part 'firebase_storage_factory.dart';

extension TaskStateExtension on TaskState {
  FileTaskState get fileTaskState => switch (this) {
    TaskState.running => FileTaskState.running,
    TaskState.paused => FileTaskState.paused,
    TaskState.success => FileTaskState.completed,
    TaskState.error => FileTaskState.error,
    TaskState.canceled => FileTaskState.cancelled,
  };
}

/// A singleton repository for managing file upload and download tasks.
///
/// This class extends [GetStorageRepository] to provide persistent storage
/// and management of [FileTask] objects. It handles both upload and download
/// operations with support for task state management, progress tracking,
/// and batch operations.
///
/// The repository uses a singleton pattern to ensure a single source of truth
/// for all file tasks across the application. Tasks are automatically
/// persisted to local storage and can be queried by various criteria.
///
/// ## Features
///
/// * **Task Management**: Create, start, pause, resume, cancel, and retry tasks
/// * **Querying**: Find tasks by ID, path, URL, group, type, or state
/// * **Streaming**: Real-time updates via streams for reactive UI
/// * **Batch Operations**: Perform operations on multiple tasks
/// * **Persistence**: Automatic storage and retrieval of tasks
/// * **Caching**: Intelligent handling of already uploaded/downloaded files
///
/// ## Usage Example
///
/// ```dart
/// // Get the singleton instance
/// final repo = FileTaskRepository();
///
/// // Create an upload task
/// final uploadTask = await repo.createUploadTask(
///   taskId: 'upload_001',
///   filePath: '/path/to/file.jpg',
///   destinationPath: 'uploads/file.jpg',
///   group: FileGroupInfo(id: 'photos', name: 'Photos'),
///   autoStart: true,
/// );
///
/// // Create a download task
/// final downloadTask = await repo.createDownloadTask(
///   taskId: 'download_001',
///   url: 'https://example.com/file.pdf',
///   group: FileGroupInfo(id: 'documents', name: 'Documents'),
///   autoStart: false,
/// );
///
/// // Listen to task changes
/// repo.getTaskStreamById('upload_001').listen((task) {
///   if (task != null) {
///     print('Task progress: ${task.progress.percentage}%');
///   }
/// });
///
/// // Control task execution
/// await repo.startTask('download_001');
/// await repo.pauseTask('upload_001');
/// await repo.resumeTask('upload_001');
///
/// // Query tasks
/// final activeTasks = repo.getActiveTasks();
/// final groupTasks = repo.getTasksByGroupId('photos');
///
/// // Batch operations
/// await repo.pauseAllRunningTasks();
/// await repo.cancelTasksByGroupId('documents');
/// ```
class FileTaskRepository extends GetStorageRepository<FileTask> {
  static final FileTaskRepository instance = FileTaskRepository._internal();

  /// Private constructor for singleton pattern.
  FileTaskRepository._internal() : super('file_task_storage2', {});

  /// Factory constructor that returns the singleton instance.
  factory FileTaskRepository() => instance;

  /// Converts a set of [FileTask] objects to JSON string for storage.
  @override
  @protected
  String inputConverter(Set<FileTask> val) =>
      json.encode(val.map((value) => value.toMap()).toList());

  /// Converts a JSON string to a set of [FileTask] objects from storage.
  @override
  @protected
  Set<FileTask> outputConverter(String? value) =>
      value?.toListMap().map((value) => FileTask.fromMap(value)).toSet() ??
      <FileTask>{};

  // MARK: - Remove Operations

  /// Removes a task from the repository by its unique ID.
  ///
  /// Returns `1` if the task was found and removed, `0` if not found.
  ///
  /// ## Parameters
  ///
  /// * [id] - The unique identifier of the task to remove
  /// * [notify] - Whether to trigger change notifications (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = repo.removeById('task_123');
  /// if (result == 1) {
  ///   print('Task removed successfully');
  /// } else {
  ///   print('Task not found');
  /// }
  /// ```
  int removeById(String id, {bool notify = true}) {
    final item = firstWhereOrNull((task) => task.id == id);
    if (item != null) return remove(item, notify: notify);
    return 0;
  }

  /// Removes all tasks belonging to a specific group.
  ///
  /// Returns the number of tasks that were removed.
  ///
  /// ## Parameters
  ///
  /// * [groupId] - The group identifier of tasks to remove
  /// * [notify] - Whether to trigger change notifications (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final removedCount = repo.removeByGroupId('photos_group');
  /// print('Removed $removedCount tasks from photos group');
  /// ```
  int removeByGroupId(String groupId, {bool notify = true}) {
    final items = value.where((task) => task.groupId == groupId).toSet();
    if (items.isNotEmpty) return removeAll(items, notify: notify);
    return 0;
  }

  /// Removes multiple tasks by their IDs.
  ///
  /// Returns the number of tasks that were actually removed.
  ///
  /// ## Parameters
  ///
  /// * [ids] - Collection of task IDs to remove
  /// * [notify] - Whether to trigger change notifications (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final idsToRemove = ['task_1', 'task_2', 'task_3'];
  /// final removedCount = repo.removeAllByIds(idsToRemove);
  /// print('Removed $removedCount out of ${idsToRemove.length} tasks');
  /// ```
  int removeAllByIds(Iterable<String> ids, {bool notify = true}) {
    final items = value.where((task) => ids.contains(task.id)).toSet();
    if (items.isNotEmpty) return removeAll(items, notify: notify);
    return 0;
  }

  /// Removes all tasks belonging to multiple groups.
  ///
  /// Returns the number of tasks that were removed.
  ///
  /// ## Parameters
  ///
  /// * [groupIds] - Collection of group IDs whose tasks should be removed
  /// * [notify] - Whether to trigger change notifications (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final groupsToRemove = ['temp_files', 'old_uploads'];
  /// final removedCount = repo.removeAllByGroupIds(groupsToRemove);
  /// print('Cleaned up $removedCount tasks from temporary groups');
  /// ```
  int removeAllByGroupIds(Iterable<String> groupIds, {bool notify = true}) {
    final items =
        value.where((task) => groupIds.contains(task.groupId)).toSet();
    if (items.isNotEmpty) return removeAll(items, notify: notify);
    return 0;
  }

  /// Removes tasks based on flexible filtering criteria.
  ///
  /// If no criteria are provided, all tasks will be removed (equivalent to clear).
  /// Returns the number of tasks that were removed.
  ///
  /// ## Parameters
  ///
  /// * [groupId] - Filter by group ID
  /// * [type] - Filter by task type (upload/download)
  /// * [states] - Filter by task states
  /// * [url] - Filter by download URL
  /// * [filePath] - Filter by file path
  /// * [destinationPath] - Filter by destination path
  /// * [notify] - Whether to trigger change notifications (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Remove all completed upload tasks
  /// final removed = repo.removeBy(
  ///   type: FileTaskType.upload,
  ///   states: {FileTaskState.completed},
  /// );
  ///
  /// // Remove all tasks for a specific file
  /// final removed2 = repo.removeBy(filePath: '/path/to/file.jpg');
  ///
  /// // Clear all tasks (no parameters)
  /// final cleared = repo.removeBy();
  /// ```
  int removeBy({
    String? groupId,
    FileTaskType? type,
    Set<FileTaskState>? states,
    String? url,
    String? filePath,
    String? destinationPath,
    bool notify = true,
  }) {
    if (groupId != null ||
        type != null ||
        states?.isNotEmpty == true ||
        url != null ||
        filePath != null ||
        destinationPath != null) {
      final items =
          value.where((task) {
            return (groupId == null || task.groupId == groupId) &&
                (type == null || task.type == type) &&
                (states == null || states.contains(task.state)) &&
                (url == null || task.downloadUrl == url) &&
                (filePath == null || task.filePath == filePath) &&
                (destinationPath == null ||
                    task.destinationPath == destinationPath);
          }).toSet();
      if (items.isNotEmpty) return removeAll(items, notify: notify);
      return 0;
    } else {
      return clear(notify: notify);
    }
  }

  // MARK: - Stream Operations

  /// Returns a stream of tasks filtered by the specified criteria.
  ///
  /// The stream emits a new set of tasks whenever the repository changes
  /// and the tasks match the provided filters.
  ///
  /// ## Parameters
  ///
  /// * [groupId] - Filter by group ID (optional)
  /// * [type] - Filter by task type (optional)
  /// * [states] - Filter by task states (optional)
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Stream of all active upload tasks
  /// repo.streamTasksBy(
  ///   type: FileTaskType.upload,
  ///   states: {FileTaskState.running, FileTaskState.waiting},
  /// ).listen((tasks) {
  ///   print('Active uploads: ${tasks.length}');
  /// });
  ///
  /// // Stream of all tasks in a specific group
  /// repo.streamTasksBy(groupId: 'photos').listen((tasks) {
  ///   updateUI(tasks);
  /// });
  /// ```
  Stream<Set<FileTask>> streamTasksBy({
    String? groupId,
    FileTaskType? type,
    Set<FileTaskState>? states,
  }) {
    // Pre-compute conditions once instead of per-task evaluation
    final hasGroupFilter = groupId != null;
    final hasTypeFilter = type != null;
    final hasStatesFilter = states != null && states.isNotEmpty;

    return streamWhere(
      (task) =>
          (!hasGroupFilter || task.groupId == groupId) &&
          (!hasTypeFilter || task.type == type) &&
          (!hasStatesFilter || states.contains(task.state)),
    );
  }

  /// Returns a stream for a specific task by its ID.
  ///
  /// The stream emits the task object whenever it changes, or `null` if
  /// the task doesn't exist or is removed.
  ///
  /// ## Parameters
  ///
  /// * [taskId] - The unique identifier of the task
  ///
  /// ## Example
  ///
  /// ```dart
  /// repo.getTaskStreamById('upload_001').listen((task) {
  ///   if (task != null) {
  ///     print('Progress: ${task.progress.percentage}%');
  ///     if (task.isComplete) {
  ///       print('Task completed!');
  ///     }
  ///   } else {
  ///     print('Task not found or removed');
  ///   }
  /// });
  /// ```
  Stream<FileTask?> getTaskStreamById(String taskId) =>
      streamFirstWhereOrNull((task) => task.id == taskId);

  /// Returns a stream for a task identified by its file path.
  ///
  /// ## Parameters
  ///
  /// * [filePath] - The file path to search for
  ///
  /// ## Example
  ///
  /// ```dart
  /// repo.getTaskStreamByFilePath('/photos/image.jpg').listen((task) {
  ///   if (task != null) {
  ///     print('File task state: ${task.state}');
  ///   }
  /// });
  /// ```
  Stream<FileTask?> getTaskStreamByFilePath(String filePath) =>
      streamFirstWhereOrNull((task) => task.filePath == filePath);

  /// Returns a stream for a task identified by its destination path.
  ///
  /// ## Parameters
  ///
  /// * [destinationPath] - The destination path to search for
  ///
  /// ## Example
  ///
  /// ```dart
  /// repo.getTaskStreamByDestinationPath('uploads/doc.pdf').listen((task) {
  ///   if (task != null) {
  ///     print('Upload task found: ${task.id}');
  ///   }
  /// });
  /// ```
  Stream<FileTask?> getTaskStreamByDestinationPath(String destinationPath) =>
      streamFirstWhereOrNull((task) => task.destinationPath == destinationPath);

  /// Returns a stream for a download task identified by its download URL.
  ///
  /// ## Parameters
  ///
  /// * [downloadUrl] - The download URL to search for
  ///
  /// ## Example
  ///
  /// ```dart
  /// repo.getDownloadTaskStreamByUrl('https://example.com/file.pdf').listen((task) {
  ///   if (task != null) {
  ///     print('Download progress: ${task.progress.percentage}%');
  ///   }
  /// });
  /// ```
  Stream<FileTask?> getDownloadTaskStreamByUrl(String downloadUrl) =>
      streamFirstWhereOrNull(
        (task) =>
            task.type == FileTaskType.download &&
            task.downloadUrl == downloadUrl,
      );

  /// Returns a stream for an upload task identified by its file path.
  ///
  /// ## Parameters
  ///
  /// * [filePath] - The file path to search for
  ///
  /// ## Example
  ///
  /// ```dart
  /// repo.getUploadTaskStreamByFilePath('/local/file.jpg').listen((task) {
  ///   if (task != null) {
  ///     print('Upload progress: ${task.progress.percentage}%');
  ///   }
  /// });
  /// ```
  Stream<FileTask?> getUploadTaskStreamByFilePath(String filePath) =>
      streamFirstWhereOrNull(
        (task) => task.type == FileTaskType.upload && task.filePath == filePath,
      );

  // MARK: - Query Operations

  /// Unified task search with multiple criteria
  ///
  /// Provides a unified way to search for tasks using different criteria
  ///
  /// ## Parameters
  ///
  /// * [id] - The unique task identifier
  /// * [url] - The download URL
  /// * [filePath] - The local file path
  /// * [destinationPath] - The destination path
  /// * [type] - The task type (upload/download)
  /// * [groupId] - The group identifier
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Search by ID
  /// final task = repo.getTaskBy(id: 'upload_001');
  ///
  /// // Search by URL and task type
  /// final downloadTask = repo.getTaskBy(
  ///   url: 'https://example.com/file.pdf',
  ///   type: FileTaskType.download,
  /// );
  /// ```
  FileTask? getTaskBy({
    String? id,
    String? url,
    String? filePath,
    String? destinationPath,
    FileTaskType? type,
    String? groupId,
  }) {
    return firstWhereOrNull(
      (task) =>
          (id == null || task.id == id) &&
          (url == null || task.downloadUrl == url) &&
          (filePath == null || task.filePath == filePath) &&
          (destinationPath == null ||
              task.destinationPath == destinationPath) &&
          (type == null || task.type == type) &&
          (groupId == null || task.groupId == groupId),
    );
  }

  /// Finds a task by its unique ID.
  ///
  /// Returns the task if found, or `null` if not found.
  ///
  /// ## Parameters
  ///
  /// * [id] - The unique identifier of the task
  ///
  /// ## Example
  ///
  /// ```dart
  /// final task = repo.getTaskById('upload_001');
  /// if (task != null) {
  ///   print('Task state: ${task.state}');
  /// } else {
  ///   print('Task not found');
  /// }
  /// ```
  FileTask? getTaskById(String id) => getTaskBy(id: id);

  /// Finds a task by its URL with optional filtering.
  ///
  /// Returns the first task matching the URL and optional criteria.
  ///
  /// ## Parameters
  ///
  /// * [url] - The URL to search for
  /// * [type] - Optional task type filter
  /// * [groupId] - Optional group ID filter
  ///
  /// ## Example
  ///
  /// ```dart
  /// final downloadTask = repo.getTaskByUrl(
  ///   'https://example.com/file.pdf',
  ///   type: FileTaskType.download,
  /// );
  /// ```
  FileTask? getTaskByUrl(String url, {FileTaskType? type, String? groupId}) =>
      getTaskBy(url: url, type: type, groupId: groupId);

  /// Finds a task by its file path with optional filtering.
  ///
  /// Returns the first task matching the file path and optional criteria.
  ///
  /// ## Parameters
  ///
  /// * [filePath] - The file path to search for
  /// * [type] - Optional task type filter
  /// * [groupId] - Optional group ID filter
  ///
  /// ## Example
  ///
  /// ```dart
  /// final uploadTask = repo.getTaskByFilePath(
  ///   '/photos/image.jpg',
  ///   type: FileTaskType.upload,
  ///   groupId: 'photos',
  /// );
  /// ```
  FileTask? getTaskByFilePath(
    String filePath, {
    FileTaskType? type,
    String? groupId,
  }) => getTaskBy(filePath: filePath, type: type, groupId: groupId);

  /// Finds a task by its destination path with optional filtering.
  ///
  /// Returns the first task matching the destination path and optional criteria.
  ///
  /// ## Parameters
  ///
  /// * [destinationPath] - The destination path to search for
  /// * [type] - Optional task type filter
  /// * [groupId] - Optional group ID filter
  ///
  /// ## Example
  ///
  /// ```dart
  /// final task = repo.getTaskByDestinationPath('uploads/document.pdf');
  /// ```
  FileTask? getTaskByDestinationPath(
    String destinationPath, {
    FileTaskType? type,
    String? groupId,
  }) =>
      getTaskBy(destinationPath: destinationPath, type: type, groupId: groupId);

  /// Returns a set of tasks filtered by the specified criteria.
  ///
  /// ## Parameters
  ///
  /// * [groupId] - Filter by group ID (optional)
  /// * [type] - Filter by task type (optional)
  /// * [states] - Filter by task states (optional)
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Get all running tasks
  /// final runningTasks = repo.getTasksBy(
  ///   states: {FileTaskState.running},
  /// );
  ///
  /// // Get all upload tasks in a group
  /// final groupUploads = repo.getTasksBy(
  ///   groupId: 'photos',
  ///   type: FileTaskType.upload,
  /// );
  /// ```
  Set<FileTask> getTasksBy({
    String? groupId,
    FileTaskType? type,
    Set<FileTaskState>? states,
  }) {
    // Pre-compute conditions once instead of per-task evaluation
    final hasGroupFilter = groupId != null;
    final hasTypeFilter = type != null;
    final hasStatesFilter = states != null && states.isNotEmpty;

    return where(
      (task) =>
          (!hasGroupFilter || task.groupId == groupId) &&
          (!hasTypeFilter || task.type == type) &&
          (!hasStatesFilter || states.contains(task.state)),
    );
  }

  /// Returns all upload tasks.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final uploads = repo.getUploadTasks();
  /// print('Total uploads: ${uploads.length}');
  /// ```
  Set<FileTask> getUploadTasks() => getTasksBy(type: FileTaskType.upload);

  /// Returns all download tasks.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final downloads = repo.getDownloadTasks();
  /// print('Total downloads: ${downloads.length}');
  /// ```
  Set<FileTask> getDownloadTasks() => getTasksBy(type: FileTaskType.download);

  /// Returns all active tasks (running or waiting).
  ///
  /// ## Example
  ///
  /// ```dart
  /// final activeTasks = repo.getActiveTasks();
  /// if (activeTasks.isEmpty) {
  ///   print('No active tasks');
  /// }
  /// ```
  Set<FileTask> getActiveTasks() =>
      getTasksBy(states: {FileTaskState.running, FileTaskState.waiting});

  /// Returns all completed tasks.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final completed = repo.getCompletedTasks();
  /// print('Completed tasks: ${completed.length}');
  /// ```
  Set<FileTask> getCompletedTasks() =>
      getTasksBy(states: {FileTaskState.completed});

  /// Returns all waiting tasks.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final waiting = repo.getWaitingTasks();
  /// print('Tasks in queue: ${waiting.length}');
  /// ```
  Set<FileTask> getWaitingTasks() =>
      getTasksBy(states: {FileTaskState.waiting});

  /// Returns all tasks in a specific group.
  ///
  /// ## Parameters
  ///
  /// * [groupId] - The group identifier
  ///
  /// ## Example
  ///
  /// ```dart
  /// final photoTasks = repo.getTasksByGroupId('photos');
  /// print('Photo tasks: ${photoTasks.length}');
  /// ```
  Set<FileTask> getTasksByGroupId(String groupId) =>
      getTasksBy(groupId: groupId);

  /// Returns all upload tasks in a specific group.
  ///
  /// ## Parameters
  ///
  /// * [groupId] - The group identifier
  ///
  /// ## Example
  ///
  /// ```dart
  /// final photoUploads = repo.getUploadTasksByGroupId('photos');
  /// ```
  Set<FileTask> getUploadTasksByGroupId(String groupId) =>
      getTasksBy(groupId: groupId, type: FileTaskType.upload);

  /// Returns all download tasks in a specific group.
  ///
  /// ## Parameters
  ///
  /// * [groupId] - The group identifier
  ///
  /// ## Example
  ///
  /// ```dart
  /// final documentDownloads = repo.getDownloadTasksByGroupId('documents');
  /// ```
  Set<FileTask> getDownloadTasksByGroupId(String groupId) =>
      getTasksBy(groupId: groupId, type: FileTaskType.download);

  /// Alias for [getTaskByFilePath].
  ///
  /// ## Parameters
  ///
  /// * [path] - The file path to search for
  FileTask? getTaskByPath(String path) => getTaskBy(filePath: path);

  /// Alias for [getTaskByUrl] for download URLs.
  ///
  /// ## Parameters
  ///
  /// * [downloadUrl] - The download URL to search for
  FileTask? getTaskByDownloadUrl(String downloadUrl) =>
      getTaskBy(url: downloadUrl);

  /// Returns an upload task for the specified file path.
  ///
  /// ## Parameters
  ///
  /// * [filePath] - The file path to search for
  ///
  /// ## Example
  ///
  /// ```dart
  /// final uploadTask = repo.getUploadTaskByFilePath('/photos/image.jpg');
  /// ```
  FileTask? getUploadTaskByFilePath(String filePath) =>
      getTaskBy(filePath: filePath, type: FileTaskType.upload);

  /// Returns a download task for the specified URL.
  ///
  /// ## Parameters
  ///
  /// * [url] - The download URL to search for
  ///
  /// ## Example
  ///
  /// ```dart
  /// final downloadTask = repo.getDownloadTaskByUrl('https://example.com/file.pdf');
  /// ```
  FileTask? getDownloadTaskByUrl(String url) =>
      getTaskBy(url: url, type: FileTaskType.download);

  /// Alias for [getTaskByUrl] for uploaded URLs.
  ///
  /// ## Parameters
  ///
  /// * [url] - The uploaded URL to search for
  FileTask? getTaskByUploadedUrl(String url) => getTaskBy(url: url);

  /// Returns a map of all tasks grouped by their group IDs.
  ///
  /// The keys are group IDs and values are sets of tasks in each group.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final groups = repo.getAllGroups();
  /// groups.forEach((groupId, tasks) {
  ///   print('Group $groupId has ${tasks.length} tasks');
  /// });
  /// ```
  Map<String, Set<FileTask>> getAllGroups() =>
      value.groupSetsBy((task) => task.groupId ?? '');

  // MARK: - Task Control Operations

  /// Starts a task that is currently waiting or paused.
  ///
  /// Returns `true` if the task was successfully started, `false` otherwise.
  ///
  /// ## Parameters
  ///
  /// * [taskId] - The unique identifier of the task to start
  ///
  /// ## Example
  ///
  /// ```dart
  /// final success = await repo.startTask('upload_001');
  /// if (success) {
  ///   print('Task started successfully');
  /// } else {
  ///   print('Task could not be started (not found or invalid state)');
  /// }
  /// ```
  Future<bool> startTask(String taskId) async {
    final task = getTaskById(taskId);
    if (task != null && (task.isWaiting || task.isPaused)) {
      addOrUpdate(task.copyWith(state: FileTaskState.running));
      return true;
    }
    return false;
  }

  /// Pauses a currently running task.
  ///
  /// Returns `true` if the task was successfully paused, `false` otherwise.
  ///
  /// ## Parameters
  ///
  /// * [taskId] - The unique identifier of the task to pause
  ///
  /// ## Example
  ///
  /// ```dart
  /// final success = await repo.pauseTask('download_001');
  /// if (success) {
  ///   print('Task paused successfully');
  /// }
  /// ```
  Future<bool> pauseTask(String taskId) async {
    final task = getTaskById(taskId);
    if (task != null && task.isRunning) {
      addOrUpdate(task.copyWith(state: FileTaskState.paused));
      return true;
    }
    return false;
  }

  /// Resumes a paused task.
  ///
  /// Returns `true` if the task was successfully resumed, `false` otherwise.
  ///
  /// ## Parameters
  ///
  /// * [taskId] - The unique identifier of the task to resume
  ///
  /// ## Example
  ///
  /// ```dart
  /// final success = await repo.resumeTask('upload_001');
  /// if (success) {
  ///   print('Task resumed successfully');
  /// }
  /// ```
  Future<bool> resumeTask(String taskId) async {
    final task = getTaskById(taskId);
    if (task != null && task.isPaused) {
      addOrUpdate(task.copyWith(state: FileTaskState.running));
      return true;
    }
    return false;
  }

  /// Cancels an active task.
  ///
  /// Returns `true` if the task was successfully cancelled, `false` otherwise.
  ///
  /// ## Parameters
  ///
  /// * [taskId] - The unique identifier of the task to cancel
  ///
  /// ## Example
  ///
  /// ```dart
  /// final success = await repo.cancelTask('upload_001');
  /// if (success) {
  ///   print('Task cancelled successfully');
  /// }
  /// ```
  Future<bool> cancelTask(String taskId) async {
    final task = getTaskById(taskId);
    if (task != null && !task.isComplete && !task.isCancelled) {
      addOrUpdate(task.copyWith(state: FileTaskState.cancelled));
      return true;
    }
    return false;
  }

  /// Retries a failed or cancelled task.
  ///
  /// Resets the task to waiting state with zero progress and clears any error message.
  /// Returns `true` if the task was successfully reset for retry, `false` otherwise.
  ///
  /// ## Parameters
  ///
  /// * [taskId] - The unique identifier of the task to retry
  ///
  /// ## Example
  ///
  /// ```dart
  /// final success = await repo.retryTask('failed_upload');
  /// if (success) {
  ///   print('Task reset for retry');
  /// }
  /// ```
  Future<bool> retryTask(String taskId) async {
    final task = getTaskById(taskId);
    if (task != null && (task.isError || task.isCancelled)) {
      addOrUpdate(
        task.copyWith(
          state: FileTaskState.waiting,
          progress: FileProgress(bytesTransferred: 0, totalBytes: 0),
          errorMessage: null,
        ),
      );
      return true;
    }
    return false;
  }

  // MARK: - Batch Operations

  /// Starts all tasks that are currently in waiting state.
  ///
  /// ## Example
  ///
  /// ```dart
  /// await repo.startAllWaitingTasks();
  /// print('All waiting tasks have been started');
  /// ```
  Future<void> startAllWaitingTasks() async {
    final waitingTasks = getWaitingTasks();
    for (var task in waitingTasks) {
      await startTask(task.id);
    }
  }

  /// Pauses all currently running tasks.
  ///
  /// ## Example
  ///
  /// ```dart
  /// await repo.pauseAllRunningTasks();
  /// print('All running tasks have been paused');
  /// ```
  Future<void> pauseAllRunningTasks() async {
    final runningTasks = getTasksBy(states: {FileTaskState.running});
    for (var task in runningTasks) {
      await pauseTask(task.id);
    }
  }

  /// Cancels all active tasks (running or waiting).
  ///
  /// ## Example
  ///
  /// ```dart
  /// await repo.cancelAllActiveTasks();
  /// print('All active tasks have been cancelled');
  /// ```
  Future<void> cancelAllActiveTasks() async {
    final activeTasks = getActiveTasks();
    for (var task in activeTasks) {
      await cancelTask(task.id);
    }
  }

  /// Removes a task from the repository.
  ///
  /// This is a convenience method that calls [removeById].
  ///
  /// ## Parameters
  ///
  /// * [taskId] - The unique identifier of the task to remove
  ///
  /// ## Example
  ///
  /// ```dart
  /// await repo.removeTask('completed_upload');
  /// ```
  Future<void> removeTask(String taskId) async {
    removeById(taskId);
  }

  /// Removes all completed tasks from the repository.
  ///
  /// Returns the number of tasks that were removed.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final cleanedCount = repo.clearCompletedTasks();
  /// print('Cleaned up $cleanedCount completed tasks');
  /// ```
  int clearCompletedTasks() => removeBy(states: {FileTaskState.completed});

  /// Pauses all running tasks in a specific group.
  ///
  /// ## Parameters
  ///
  /// * [groupId] - The group identifier
  ///
  /// ## Example
  ///
  /// ```dart
  /// await repo.pauseTasksByGroupId('photos');
  /// print('All photo tasks have been paused');
  /// ```
  Future<void> pauseTasksByGroupId(String groupId) async {
    final groupTasks =
        value
            .where((task) => task.groupId == groupId && task.isRunning)
            .toList();
    for (var task in groupTasks) {
      await pauseTask(task.id);
    }
  }

  /// Resumes all paused or waiting tasks in a specific group.
  ///
  /// ## Parameters
  ///
  /// * [groupId] - The group identifier
  ///
  /// ## Example
  ///
  /// ```dart
  /// await repo.resumeTasksByGroupId('documents');
  /// print('All document tasks have been resumed');
  /// ```
  Future<void> resumeTasksByGroupId(String groupId) async {
    final groupTasks =
        value
            .where(
              (task) =>
                  task.groupId == groupId && (task.isPaused || task.isWaiting),
            )
            .toList();
    for (var task in groupTasks) {
      await startTask(task.id);
    }
  }

  /// Cancels all active tasks in a specific group.
  ///
  /// ## Parameters
  ///
  /// * [groupId] - The group identifier
  ///
  /// ## Example
  ///
  /// ```dart
  /// await repo.cancelTasksByGroupId('temp_files');
  /// print('All temporary file tasks have been cancelled');
  /// ```
  Future<void> cancelTasksByGroupId(String groupId) async {
    final groupTasks =
        value
            .where(
              (task) =>
                  task.groupId == groupId &&
                  !task.isComplete &&
                  !task.isCancelled,
            )
            .toList();
    for (var task in groupTasks) {
      await cancelTask(task.id);
    }
  }

  // MARK: - Task Creation

  /// Creates a new upload task for the specified file.
  ///
  /// This method handles file validation, checks for existing tasks, and
  /// determines if the file is already uploaded (cached). If the file
  /// doesn't exist, an error task is created.
  ///
  /// Returns the created or existing [FileTask].
  ///
  /// ## Parameters
  ///
  /// * [taskId] - Unique identifier for the new task
  /// * [filePath] - Local path to the file to upload
  /// * [destinationPath] - Remote destination path for the upload
  /// * [group] - Group information for organizing tasks
  /// * [autoStart] - Whether to automatically start the task (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final uploadTask = await repo.createUploadTask(
  ///   taskId: 'upload_${DateTime.now().millisecondsSinceEpoch}',
  ///   filePath: '/storage/photos/image.jpg',
  ///   destinationPath: 'user_uploads/photos/image.jpg',
  ///   group: FileGroupInfo(id: 'photos', name: 'Photo Uploads'),
  ///   autoStart: false, // Start manually later
  /// );
  ///
  /// if (uploadTask.isError) {
  ///   print('Error: ${uploadTask.errorMessage}');
  /// } else if (uploadTask.isCached) {
  ///   print('File already uploaded');
  /// } else {
  ///   print('Upload task created successfully');
  /// }
  /// ```
  Future<FileTask> createUploadTask({
    required String taskId,
    required String filePath,
    required String destinationPath,
    required FileGroupInfo group,
    bool autoStart = true,
  }) async {
    final existingTask = getUploadTaskByFilePath(filePath);
    if (existingTask != null) return existingTask;

    var filePathAndUrl = await FilePathAndURLRepository.instance
        .getUploadFilePathAndURL(
          path: filePath,
          destinationPath: destinationPath,
        );
    if (filePathAndUrl == null) {
      final errorTask = FileTask.upload(
        id: taskId,
        filePath: filePath,
        destinationPath: destinationPath,
        downloadUrl: null,
        group: group,
        state: FileTaskState.error,
        errorMessage: 'File not found',
        progress: FileProgress(bytesTransferred: 0, totalBytes: 1),
      );
      addOrUpdate(errorTask);
      return errorTask;
    } else {
      final fileSize = await filePathAndUrl.file.length();

      // Create initial waiting task
      final firebaseTask = FirebaseStorageFactory.createUpload(
        filePathAndUrl.path,
        filePathAndUrl.destinationPath!,
        autoStart: autoStart,
      );

      final newTask = FileTask.upload(
        id: taskId,
        filePath: filePathAndUrl.path,
        destinationPath: filePathAndUrl.destinationPath!,
        downloadUrl: filePathAndUrl.url,
        state:
            filePathAndUrl.url != null
                ? FileTaskState.cached
                : firebaseTask.snapshot.state.fileTaskState,
        group: group,
        progress: FileProgress(
          bytesTransferred: filePathAndUrl.url != null ? fileSize : 0,
          totalBytes: fileSize,
        ),
        firebaseTask: firebaseTask,
      );
      addOrUpdate(newTask);
      return newTask;
    }
  }

  /// Creates a new download task for the specified URL.
  ///
  /// This method checks for existing tasks and cached files. If the file
  /// is already downloaded and cached, a cached task is created. Otherwise,
  /// a new download task is created with metadata from Firebase Storage.
  ///
  /// Returns the created or existing [FileTask].
  ///
  /// ## Parameters
  ///
  /// * [taskId] - Unique identifier for the new task
  /// * [url] - The download URL
  /// * [group] - Group information for organizing tasks
  /// * [autoStart] - Whether to automatically start the task (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final downloadTask = await repo.createDownloadTask(
  ///   taskId: 'download_${DateTime.now().millisecondsSinceEpoch}',
  ///   url: 'https://firebasestorage.googleapis.com/v0/b/project/o/file.pdf',
  ///   group: FileGroupInfo(id: 'documents', name: 'Document Downloads'),
  ///   autoStart: true,
  /// );
  ///
  /// if (downloadTask.isCached) {
  ///   print('File already downloaded and cached');
  /// } else {
  ///   print('Download task created successfully');
  /// }
  /// ```
  Future<FileTask> createDownloadTask({
    required String taskId,
    required String url,
    required FileGroupInfo group,
    bool autoStart = true,
  }) async {
    final existingTask = getDownloadTaskByUrl(url);
    if (existingTask != null) {
      return existingTask;
    }

    var filePathAndUrl = await FilePathAndURLRepository.instance
        .getCachedDownloadFilePathAndURL(url: url);

    if (filePathAndUrl != null) {
      final newTask = FileTask.download(
        id: taskId,
        downloadUrl: filePathAndUrl.url!,
        group: group,
        state: FileTaskState.cached,
        progress: FileProgress(
          bytesTransferred: filePathAndUrl.file.lengthSync(),
          totalBytes: filePathAndUrl.file.lengthSync(),
        ),
      );

      addOrUpdate(newTask);
      return newTask;
    } else {
      final fileTask = FileTaskRepository.instance.getTaskByUrl(url);
      if (fileTask != null) {
        return fileTask;
      }

      filePathAndUrl = FilePathAndURL.url(url: url);

      final fileSize =
          (await FirebaseStorage.instance.refFromURL(url).getMetadata()).size;

      // Create initial waiting task
      final firebaseTask = FirebaseStorageFactory.createDownload(
        url,
        autoStart: autoStart,
      );

      final newTask = FileTask.download(
        id: taskId,
        downloadUrl: filePathAndUrl.url!,
        state: firebaseTask.snapshot.state.fileTaskState,
        group: group,
        progress: FileProgress(bytesTransferred: 0, totalBytes: fileSize ?? 0),
        firebaseTask: firebaseTask,
      );

      addOrUpdate(newTask);
      return newTask;
    }
  }
}
