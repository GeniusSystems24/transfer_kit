import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'core/extension/file_path_extension.dart';
import 'model/file_exception.dart';
import 'model/file_path_and_url.dart';
import 'model/file_task.dart';
import 'model/multi_download_file_task.dart';
import 'model/multi_upload_file_task.dart';
import 'repository/file_path_and_url_repository.dart';
import 'repository/firebase_file_repository.dart';
import 'service/task_management_service.dart';

extension CachedFileFromUrl on String {
  Future<File?> getCachedFile() => TransferKit()
      .downloadTask(
        filePathAndUrl: FilePathAndURL.url(url: this),
        taskId: 'cached_file_$this',
      )
      .then((task) => task.isComplete ? File(task.filePath) : null);
}

/// Controller for managing cached files using the repository pattern
class TransferKit {
  ///
  static final TransferKit instance = TransferKit._internal();

  /// Factory constructor to return the singleton instance
  factory TransferKit() => instance;

  /// Private constructor for singleton pattern
  TransferKit._internal();

  /// The repository instance used for file operations
  final FirebaseFileRepository repository = FirebaseFileRepository();

  /// Task management service instance
  final TaskManagementService taskService = TaskManagementService.instance;

  /// Stream of file tasks
  Stream<Set<FileTask>> get taskStream => taskService.stream;

  /// Get a task stream by ID
  Stream<FileTask?> getTaskStreamById(String taskId) =>
      taskService.getTaskStreamById(taskId);

  /// Get a task stream by file path
  Stream<FileTask?> getTaskStreamByFilePath(String filePath) =>
      taskService.getTaskStreamByFilePath(filePath);

  /// Get a task stream by destination path
  Stream<FileTask?> getTaskStreamByDestinationPath(String destinationPath) =>
      taskService.getTaskStreamByDestinationPath(destinationPath);

  /// Get a task stream by download url
  Stream<FileTask?> getDownloadTaskStreamByUrl(String downloadUrl) =>
      taskService.getDownloadTaskStreamByUrl(downloadUrl);

  /// Get a task stream by file path
  Stream<FileTask?> getUploadTaskStreamByFilePath(String filePath) =>
      taskService.getUploadTaskStreamByFilePath(filePath);

  /// Get all tasks
  Set<FileTask> getAllTasks() => taskService.getActiveTasks();

  /// Get upload tasks
  Set<FileTask> getUploadTasks() => taskService.getUploadTasks();

  /// Get download tasks
  Set<FileTask> getDownloadTasks() => taskService.getDownloadTasks();

  /// Get a task by ID
  FileTask? getTaskById(String taskId) => taskService.getTaskById(taskId);

  /// SIMPLIFIED API METHODS

  /// Start a task
  Future<bool> startTask(String taskId) => repository.startTask(taskId);

  /// Start all tasks in a group
  Future<void> startTasksByGroupId(String groupId) =>
      taskService.resumeTasksByGroupId(groupId);

  /// Pause a task
  Future<bool> pauseTask(String taskId) => repository.pauseTask(taskId);

  /// Pause all tasks in a group
  Future<void> pauseTasksByGroupId(String groupId) =>
      taskService.pauseTasksByGroupId(groupId);

  /// Resume a task
  Future<bool> resumeTask(String taskId) => repository.resumeTask(taskId);

  /// Resume all tasks in a group
  Future<void> resumeTasksByGroupId(String groupId) =>
      taskService.resumeTasksByGroupId(groupId);

  /// Cancel a task
  Future<bool> cancelTask(String taskId) => repository.cancelTask(taskId);

  /// Cancel all tasks in a group
  Future<void> cancelTasksByGroupId(String groupId) =>
      taskService.cancelTasksByGroupId(groupId);

  /// Retry a failed task
  Future<bool> retryTask(String taskId) => repository.startTask(taskId);

  /// Remove a task
  Future<void> removeTask(String taskId) => taskService.removeTask(taskId);

  /// Start all waiting tasks
  Future<void> startAllWaitingTasks() => taskService.startAllWaitingTasks();

  /// Pause all running tasks
  Future<void> pauseAllRunningTasks() => taskService.pauseAllRunningTasks();

  /// Cancel all active tasks
  Future<void> cancelAllActiveTasks() => taskService.cancelAllActiveTasks();

  /// Clear all completed tasks
  Future<void> clearCompletedTasks() async => taskService.clearCompletedTasks();

  /// Checks if a file has been cached for the given URL
  ///
  /// [url] The Firebase Storage URL of the file
  /// Returns a [Future<bool>] indicating whether the file is cached
  Future<bool> isFileCached(String url) async {
    final entry = FilePathAndURLRepository.instance.getByUrl(url);
    if (entry != null) return File(entry.path).exists();
    return File(url.toHashName().toCachedPath()).exists();
  }

  /// Gets the cached file path for the given URL
  ///
  /// [url] The Firebase Storage URL of the file
  /// Returns a [Future<String?>] containing the local file path if cached, null otherwise
  Future<String?> getCachedFilePath(String url) async {
    final entry = FilePathAndURLRepository.instance.getByUrl(url);
    final filePath = entry?.path ?? url.toHashName().toCachedPath();
    final file = File(filePath);
    if (await file.exists()) return filePath;
    return null;
  }

  /// Clears the cached file for the given URL and removes its index entry.
  ///
  /// - [url] The URL of the file to clear from cache
  Future<void> clearCache(String url) async {
    final entry = FilePathAndURLRepository.instance.getByUrl(url);
    if (entry != null) {
      final file = File(entry.path);
      if (await file.exists()) await file.delete();
      FilePathAndURLRepository.instance.remove(entry);
    } else {
      // Fallback: hash-based deletion for backward compatibility
      final file = File(url.toHashName().toCachedPath());
      if (await file.exists()) await file.delete();
    }
  }

  /// Clears cached files for the given URLs and removes their index entries.
  ///
  /// - [urls] The URLs of the files to clear from cache
  Future<void> clearCacheForUrls(Set<String> urls) async {
    for (final url in urls) {
      await clearCache(url);
    }
  }

  /// Deletes local files and removes index entries where [expiresAt] has passed.
  /// Returns the number of entries removed. No remote operations.
  Future<int> clearExpiredCacheEntries() =>
      FilePathAndURLRepository.instance.clearExpiredEntries();

  /// Removes index entries where the local file no longer exists on disk.
  /// Returns the count of stale entries repaired. No remote operations.
  Future<int> repairStaleCacheEntries() =>
      FilePathAndURLRepository.instance.repairStaleEntries();

  /// Get tasks by group ID
  Set<FileTask> getTasksByGroupId(String groupId) =>
      taskService.getTasksByGroupId(groupId);

  /// Get all unique group IDs
  Set<String> getAllGroupIds() => taskService.getAllGroupIds();

  /// Create a new upload task
  ///
  /// - [filePathAndUrl] The path to the file to upload
  /// - [autoStart] Whether to start the upload immediately
  /// - [taskId] Optional identifier for the task
  /// - [group] Optional group information for batch operations
  ///
  /// Returns a future [FileTask] containing the created upload task
  Future<FileTask> createUploadTask({
    required FilePathAndURL filePathAndUrl,
    required String taskId,
    required FileGroupInfo group,
    bool autoStart = true,
  }) =>
      repository.createUploadTask(
        filePathAndUrl: filePathAndUrl,
        autoStart: autoStart,
        taskId: taskId,
        group: group,
      );

  /// Streams a file upload to Firebase Storage with progress updates
  ///
  /// - [filePathAndUrl] The file path and destination path to upload
  /// - [autoStart] Whether to start the upload immediately
  /// - [taskId] Optional identifier for the task
  /// - [group] Optional group information for batch operations
  ///
  /// Returns a [Stream<FileTask>] that emits progress updates during upload
  Stream<FileTask> uploadTaskStream({
    required FilePathAndURL filePathAndUrl,
    bool autoStart = true,
    required String taskId,
    FileGroupInfo? group,
  }) {
    group ??= FileGroupInfo(id: const Uuid().v4());

    late final StreamController<FileTask> controller;
    controller = StreamController<FileTask>(
      onCancel: () {
        // Ensure controller is closed when stream is cancelled
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    _uploadTaskStream(
      filePathAndUrl: filePathAndUrl,
      controller: controller,
      taskId: taskId,
      group: group,
    ).catchError((error) {
      if (!controller.isClosed) {
        controller.addError(
          FileUploadException('Failed to stream upload: $error'),
        );
        controller.close();
      }
    });

    return controller.stream;
  }

  Future<void> _uploadTaskStream({
    required FilePathAndURL filePathAndUrl,
    required StreamController<FileTask> controller,
    required FileGroupInfo group,
    required String taskId,
    bool autoStart = true,
  }) async {
    try {
      final task = await repository.createUploadTask(
        filePathAndUrl: filePathAndUrl,
        taskId: taskId,
        group: group,
        autoStart: autoStart,
      );

      // Stream the upload with progress updates
      repository.uploadTaskStream(task: task, controller: controller);
    } catch (e) {
      throw FileUploadException('Failed to check and stream upload: $e');
    }
  }

  /// Uploads a single file with built-in deduplication (Future version)
  ///
  /// The method automatically checks for existing tasks with the same file to avoid duplicates.
  /// If a matching task is found, it will be returned instead of creating a new one.
  ///
  /// - [filePathAndUrl] FilePathAndURL object containing file path and optional destination path
  /// - [autoStart] Whether to start the upload immediately
  /// - [taskId] Optional identifier for the task
  /// - [group] Optional group information for batch operations
  ///
  /// Returns a future with the created or existing task
  Future<FileTask> uploadTask({
    required FilePathAndURL filePathAndUrl,
    required String taskId,
    bool autoStart = true,
    FileGroupInfo? group,
  }) async {
    group ??= FileGroupInfo(id: const Uuid().v4());

    return await uploadTaskStream(
      filePathAndUrl: filePathAndUrl,
      taskId: taskId,
      group: group,
      autoStart: autoStart,
    ).last;
  }

  /// Uploads multiple files in parallel to Firebase Storage with progress updates
  ///
  /// - [filePathsAndUrls] Set of file paths and URLs to upload
  /// - [autoStart] Whether to start the upload immediately
  /// - [group] Optional group information for batch operations
  ///
  /// Returns a stream of [MultiUploadFileTask] that emits progress updates during uploads
  Stream<MultiUploadFileTask> uploadTasksParallelStream({
    required Set<FilePathAndURL> filePathsAndUrls,
    FileGroupInfo? group,
    bool autoStart = true,
  }) {
    // Generate a group ID for this batch
    group ??= FileGroupInfo(id: const Uuid().v4());

    if (filePathsAndUrls.isEmpty) {
      return Stream.value(
        MultiUploadFileTask.fromTasks(tasks: [], taskId: group.id),
      );
    }

    // Return the progress stream
    return repository.uploadTasksParallelStream(
      filePathsAndUrls: filePathsAndUrls,
      autoStart: autoStart,
      group: group,
    );
  }

  /// Uploads multiple files in parallel to Firebase Storage with progress updates
  ///
  /// - [filePathsAndUrls] Set of file paths and URLs to upload
  /// - [autoStart] Whether to start the upload immediately
  /// - [group] Optional group information for batch operations
  ///
  /// Returns a [MultiUploadFileTask] that emits progress updates during uploads
  Future<MultiUploadFileTask> uploadTasksParallel({
    required Set<FilePathAndURL> filePathsAndUrls,
    FileGroupInfo? group,
    bool autoStart = true,
  }) async {
    // Generate a group for this batch
    group ??= FileGroupInfo(id: const Uuid().v4());

    return await uploadTasksParallelStream(
      filePathsAndUrls: filePathsAndUrls,
      group: group,
      autoStart: autoStart,
    ).last;
  }

  /// Create a new download task
  ///
  /// - [filePathAndUrl] The FilePathAndURL object containing the file to download
  /// - [autoStart] Whether to start the download immediately
  /// - [taskId] Optional identifier for the task
  /// - [group] Optional group information for batch operations
  ///
  /// Returns a future [FileTask] containing the created download task
  Future<FileTask> createDownloadTask({
    required FilePathAndURL filePathAndUrl,
    required String taskId,
    required FileGroupInfo group,
    bool autoStart = true,
  }) =>
      repository.createDownloadTask(
        filePathAndUrl: filePathAndUrl,
        autoStart: autoStart,
        taskId: taskId,
        group: group,
      );

  /// Streams a file from cache or downloads it if not cached, with progress updates
  ///
  /// - [filePathAndUrl] The FilePathAndURL object containing the file to download
  /// - [autoStart] Whether to start the download immediately
  /// - [taskId] Optional identifier for the task
  /// - [group] Optional group information for batch operations
  ///
  /// Returns a [Stream<FileTask>] that emits progress updates during download
  Stream<FileTask> downloadTaskStream({
    required FilePathAndURL filePathAndUrl,
    bool autoStart = true,
    required String taskId,
    FileGroupInfo? group,
    bool forceRefresh = false,
  }) {
    group ??= FileGroupInfo(id: const Uuid().v4());

    late final StreamController<FileTask> controller;
    controller = StreamController<FileTask>(
      onCancel: () {
        // Ensure controller is closed when stream is cancelled
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    _downloadTaskStream(
      filePathAndUrl: filePathAndUrl,
      controller: controller,
      taskId: taskId,
      group: group,
      forceRefresh: forceRefresh,
    ).catchError((error) {
      if (!controller.isClosed) {
        controller.addError(
          FileDownloadException('Failed to stream download: $error'),
        );
        controller.close();
      }
    });

    return controller.stream;
  }

  Future<void> _downloadTaskStream({
    required FilePathAndURL filePathAndUrl,
    required StreamController<FileTask> controller,
    required FileGroupInfo group,
    required String taskId,
    bool autoStart = true,
    bool forceRefresh = false,
  }) async {
    try {
      final task = await repository.createDownloadTask(
        filePathAndUrl: filePathAndUrl,
        taskId: taskId,
        group: group,
        autoStart: autoStart,
        forceRefresh: forceRefresh,
      );

      // Stream the download with progress updates
      repository.downloadTaskStream(task: task, controller: controller);
    } catch (e) {
      throw FileDownloadException('Failed to check and stream download: $e');
    }
  }

  /// Downloads a single file with built-in deduplication (Future version)
  ///
  /// The method automatically checks for existing tasks with the same file to avoid duplicates.
  /// If a matching task is found, it will be returned instead of creating a new one.
  ///
  /// - [filePathAndUrl] FilePathAndURL object containing file path and optional destination path
  /// - [autoStart] Whether to start the download immediately
  /// - [taskId] Optional identifier for the task
  /// - [group] Optional group information for batch operations
  ///
  /// Returns a future with the created or existing task
  Future<FileTask> downloadTask({
    required FilePathAndURL filePathAndUrl,
    required String taskId,
    bool autoStart = true,
    FileGroupInfo? group,
    bool forceRefresh = false,
  }) async {
    group ??= FileGroupInfo(id: const Uuid().v4());

    return await downloadTaskStream(
      filePathAndUrl: filePathAndUrl,
      taskId: taskId,
      group: group,
      autoStart: autoStart,
      forceRefresh: forceRefresh,
    ).last;
  }

  /// Downloads multiple files in parallel with progress updates
  ///
  /// - [filePathsAndUrls] Set of file paths and URLs to download
  /// - [autoStart] Whether to start the download immediately.
  /// - [group] Optional group for batch operations.
  ///
  /// Returns a [Stream<MultiDownloadTask>] that emits progress updates during downloads
  Stream<MultiDownloadFileTask> downloadTasksParallelStream({
    required Set<FilePathAndURL> filePathsAndUrls,
    FileGroupInfo? group,
    bool autoStart = true,
  }) {
    // Generate a group ID for this batch
    group ??= FileGroupInfo(id: const Uuid().v4());

    if (filePathsAndUrls.isEmpty) {
      return Stream.value(
        MultiDownloadFileTask.fromTasks(tasks: [], taskId: group.id),
      );
    }

    return repository.downloadTasksParallelStream(
      filePathsAndUrls: filePathsAndUrls,
      autoStart: autoStart,
      group: group,
    );
  }

  /// 6. Downloads multiple files in parallel with built-in deduplication (Future version)
  ///
  /// The order of tasks in the returned list is not guaranteed due to parallel processing.
  /// The method automatically checks for existing tasks with the same files to avoid duplicates.
  ///
  /// - [filePathsAndUrls] List of FilePathAndURL objects to download
  /// - [autoStart] Whether to start downloads immediately
  /// - [group] Optional group information for batch operations
  ///
  /// Returns a future with list of created or existing tasks
  Future<MultiDownloadFileTask> downloadTasksParallel({
    required Set<FilePathAndURL> filePathsAndUrls,
    FileGroupInfo? group,
    bool autoStart = true,
  }) async {
    // Generate a group for this batch
    group ??= FileGroupInfo(id: const Uuid().v4());

    return await downloadTasksParallelStream(
      filePathsAndUrls: filePathsAndUrls,
      group: group,
      autoStart: autoStart,
    ).last;
  }
}
