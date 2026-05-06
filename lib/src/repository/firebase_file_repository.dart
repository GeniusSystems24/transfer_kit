import 'dart:async';
import 'dart:io';

import 'file_task_repository.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../model/file_exception.dart';
import '../model/file_path_and_url.dart';
import '../model/file_task.dart';
import '../model/multi_download_file_task.dart';
import '../model/multi_upload_file_task.dart';
import '../service/metadata_extraction_service.dart';
import '../service/task_management_service.dart';
import 'file_path_and_url_repository.dart';

/// Repository for managing Firebase Storage file operations.
///
/// This repository provides a high-level API for uploading and downloading files
/// to/from Firebase Storage with features like:
/// - Progress tracking via streams
/// - Task lifecycle management (start, pause, resume, cancel)
/// - Automatic caching and cache management
/// - Batch operations for multiple files
///
/// ## Stream Sharing
/// When multiple widgets request the same file transfer, this repository uses
/// [FirebaseStorageFactory]'s shared stream pattern to avoid duplicate listeners
/// and reduce resource usage.
///
/// ## Example:
/// ```dart
/// final repo = FirebaseFileRepository();
///
/// // Create and start a download task
/// final task = await repo.createDownloadTask(
///   filePathAndUrl: FilePathAndURL.url(url: 'https://...'),
///   taskId: 'download_001',
///   group: FileGroupInfo(id: 'downloads'),
/// );
///
/// // Listen to progress
/// repo.downloadTaskStream(task: task).listen((updatedTask) {
///   print('Progress: ${updatedTask.progressPercentage}%');
/// });
/// ```
class FirebaseFileRepository {
  // ═══════════════════════════════════════════════════════════════════════════
  // DEPENDENCIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Task management service for tracking all file tasks
  final TaskManagementService taskService = TaskManagementService.instance;

  /// Optional custom Firebase Storage instance
  FirebaseFileRepository({FirebaseStorage? storage});

  // ═══════════════════════════════════════════════════════════════════════════
  // TASK LIFECYCLE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Starts a file transfer task.
  ///
  /// If the task is already running or complete, returns false.
  /// Otherwise, starts the appropriate stream (upload or download) based on task type.
  ///
  /// ## Parameters:
  /// - [taskId]: The unique identifier of the task to start
  ///
  /// ## Returns:
  /// `true` if the task was started successfully, `false` otherwise
  Future<bool> startTask(String taskId) async {
    final task = taskService.getTaskById(taskId);
    if (task == null || task.isRunning || task.isComplete) return false;

    if (task.type == FileTaskType.upload) {
      task.state = FileTaskState.running;
      uploadTaskStream(task: task);
    } else {
      task.state = FileTaskState.running;
      downloadTaskStream(task: task);
    }

    return true;
  }

  /// Pauses a running file transfer task.
  ///
  /// ## Parameters:
  /// - [taskId]: The unique identifier of the task to pause
  ///
  /// ## Returns:
  /// `true` if the task was paused successfully, `false` otherwise
  Future<bool> pauseTask(String taskId) async {
    final task = taskService.getTaskById(taskId);
    if (task == null || !task.isRunning) return false;

    if ((await task.firebaseTask(justCheck: true)?.pause()) == true) {
      task.state = FileTaskState.paused;
      return true;
    }
    return false;
  }

  /// Resumes a paused file transfer task.
  ///
  /// ## Parameters:
  /// - [taskId]: The unique identifier of the task to resume
  ///
  /// ## Returns:
  /// `true` if the task was resumed successfully, `false` otherwise
  Future<bool> resumeTask(String taskId) async {
    final task = taskService.getTaskById(taskId);
    if (task == null || task.isRunning) {
      return false;
    }
    if (task.type == FileTaskType.upload) {
      uploadTaskStream(task: task);
    } else {
      downloadTaskStream(task: task);
    }
    return true;
  }

  /// Cancels a file transfer task.
  ///
  /// ## Parameters:
  /// - [taskId]: The unique identifier of the task to cancel
  ///
  /// ## Returns:
  /// `true` if the task was cancelled successfully, `false` otherwise
  Future<bool> cancelTask(String taskId) async {
    final task = taskService.getTaskById(taskId);
    if (task == null) return false;

    await task.firebaseTask(justCheck: true)?.cancel();
    task.state = FileTaskState.cancelled;

    return true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CACHE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Clears a cached file from local storage.
  ///
  /// ## Parameters:
  /// - [localPath]: The path to the cached file relative to the app's temp directory
  ///
  /// ## Throws:
  /// [FileDeleteException] if the file cannot be deleted
  Future<void> clearCache(String localPath) async {
    try {
      final appDir = await getTemporaryDirectory();
      final filePath = '${appDir.path}/$localPath';

      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw FileDeleteException(
        'Failed to delete cached file',
        cause: e,
      );
    }
  }

  /// Cleans up tasks and Firebase resources.
  ///
  /// ## Parameters:
  /// - [onlyCompleted]: If true, only cleans completed tasks. If false, cleans all tasks.
  ///
  /// ## Returns:
  /// The number of tasks that were cleaned up
  int cleanupTasks({bool onlyCompleted = true}) {
    if (onlyCompleted) {
      FirebaseStorageFactory.clearCompletedTasks();
      return taskService.clearCompletedTasks();
    } else {
      FirebaseStorageFactory.clearAllTasks();
      return taskService.clearAllTasks();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TASK QUERIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets all tasks currently managed by the service.
  Set<FileTask> getAllTasks() => taskService.tasks;

  /// Gets a specific task by its ID.
  FileTask? getTaskById(String taskId) => taskService.getTaskById(taskId);

  /// Stream of all tasks (emits whenever any task changes).
  Stream<Set<FileTask>> get taskStream => taskService.stream;

  // ═══════════════════════════════════════════════════════════════════════════
  // UPLOAD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates a new upload task.
  ///
  /// ## Parameters:
  /// - [filePathAndUrl]: Contains the local file path and destination path
  /// - [taskId]: Unique identifier for this task
  /// - [group]: Group information for batch operations
  /// - [autoStart]: Whether to start the upload immediately (default: true)
  ///
  /// ## Returns:
  /// A [FileTask] representing the upload operation
  Future<FileTask> createUploadTask({
    required FilePathAndURL filePathAndUrl,
    required String taskId,
    required FileGroupInfo group,
    bool autoStart = true,
  }) async =>
      await FileTaskRepository.instance.createUploadTask(
        filePath: filePathAndUrl.path,
        destinationPath: filePathAndUrl.destinationPath!,
        autoStart: autoStart,
        taskId: taskId,
        group: group,
      );

  /// Creates a stream that emits upload progress updates.
  ///
  /// This method uses the shared stream pattern - if multiple callers request
  /// a stream for the same upload, they all share the same underlying stream.
  ///
  /// ## Parameters:
  /// - [task]: The upload task to stream progress for
  /// - [controller]: Optional external stream controller (for internal use)
  ///
  /// ## Returns:
  /// A [Stream<FileTask>] that emits progress updates
  ///
  /// ## Example:
  /// ```dart
  /// final stream = repo.uploadTaskStream(task: uploadTask);
  /// stream.listen((task) {
  ///   print('Upload progress: ${task.progressPercentage}%');
  ///   if (task.isComplete) {
  ///     print('Download URL: ${task.downloadUrl}');
  ///   }
  /// });
  /// ```
  Stream<FileTask> uploadTaskStream({
    required FileTask task,
    StreamController<FileTask>? controller,
  }) {
    // If task is already complete, return immediately
    if (task.isComplete) {
      final streamController = controller ?? StreamController<FileTask>();
      streamController.add(task);
      streamController.close();
      return streamController.stream;
    }

    // Use shared stream from factory
    return FirebaseStorageFactory.getUploadStream(
      filePath: task.filePath,
      destinationPath: task.destinationPath!,
      task: task,
      onUpdate: (updatedTask) {
        // Update repository (called once per event, not per subscriber)
        FileTaskRepository.instance.addOrUpdate(updatedTask);
      },
      onComplete: (updatedTask, downloadUrl) async {
        // Extract metadata from uploaded file and merge with existing
        var filePathAndURL = updatedTask.filePathAndURL;
        final extractedMetadata = await MetadataExtractionService()
            .extractMetadata(
          File(updatedTask.filePath),
          existingMetadata: filePathAndURL.metadata,
        );
        filePathAndURL = filePathAndURL.copyWithMergedMetadata(extractedMetadata);
              // Save to file path repository for caching (includes metadata)
        FilePathAndURLRepository.instance.addOrUpdate(filePathAndURL);
        // Clean up completed tasks
        FirebaseStorageFactory.clearCompletedTasks();
      },
      onError: (errorTask, error) {
        // Update repository with error state
        FileTaskRepository.instance.addOrUpdate(errorTask);
        Logger().e('Upload failed: ${error.runtimeType}');
        // Clean up after failure
        FirebaseStorageFactory.clearCompletedTasks();
      },
    );
  }

  /// Uploads multiple files in parallel with progress tracking.
  ///
  /// ## Parameters:
  /// - [filePathsAndUrls]: Set of files to upload
  /// - [group]: Group information for the batch
  /// - [autoStart]: Whether to start uploads immediately (default: true)
  /// - [controller]: Optional external stream controller
  ///
  /// ## Returns:
  /// A [Stream<MultiUploadFileTask>] that emits combined progress for all files
  Stream<MultiUploadFileTask> uploadTasksParallelStream({
    required Set<FilePathAndURL> filePathsAndUrls,
    required FileGroupInfo group,
    bool autoStart = true,
    StreamController<MultiUploadFileTask>? controller,
  }) {
    assert(
        filePathsAndUrls.isNotEmpty, 'File paths and urls must not be empty');
    final newController =
        controller ?? StreamController<MultiUploadFileTask>();

    _uploadTasksParallelStream(
      filePathsAndUrls: filePathsAndUrls,
      controller: newController,
      autoStart: autoStart,
      group: group,
    ).catchError((error) {
      newController.addError(
          FileUploadException('Failed to upload files in parallel: $error'));
      newController.close();
    });

    return newController.stream;
  }

  /// Internal implementation for parallel uploads.
  Future<void> _uploadTasksParallelStream({
    required Set<FilePathAndURL> filePathsAndUrls,
    required StreamController<MultiUploadFileTask> controller,
    required FileGroupInfo group,
    bool autoStart = true,
  }) async {
    try {
      // Initialize tracking variables
      final List<FileTask> tasks = [];

      // Convert Set to List for O(1) access
      final filePathsAndUrlsList = filePathsAndUrls.toList();

      // Create all upload tasks
      for (int i = 0; i < filePathsAndUrlsList.length; i++) {
        final filePathAndUrl = filePathsAndUrlsList[i];

        tasks.add(
          await FileTaskRepository.instance.createUploadTask(
            taskId: '${group.id}_$i',
            filePath: filePathAndUrl.path,
            destinationPath: filePathAndUrl.destinationPath!,
            group: group,
            autoStart: autoStart,
          ),
        );
      }

      // Emit initial progress
      controller
          .add(MultiUploadFileTask.fromTasks(tasks: tasks, taskId: group.id));

      // Track completion count
      int completedCount = tasks.where((t) => t.isComplete).length;

      // Start uploads in parallel (uses shared streams internally)
      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];

        // Skip already completed tasks (cached)
        if (task.isComplete) continue;

        uploadTaskStream(task: task).listen((updatedTask) {
          // Update the task in our list
          tasks[i] = updatedTask;

          // Emit the progress update
          if (!controller.isClosed) {
            controller.add(
                MultiUploadFileTask.fromTasks(tasks: tasks, taskId: group.id));
          }

          // Check if all tasks are complete
          if (updatedTask.isComplete) {
            completedCount++;
            if (completedCount >= tasks.length && !controller.isClosed) {
              controller.close();
            }
          }
        });
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(
            FileUploadException('Failed to upload files in parallel: $e'));
        controller.close();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DOWNLOAD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates a new download task.
  ///
  /// ## Parameters:
  /// - [filePathAndUrl]: Contains the URL to download from and optional metadata
  /// - [taskId]: Unique identifier for this task
  /// - [group]: Group information for batch operations
  /// - [autoStart]: Whether to start the download immediately (default: true)
  ///
  /// ## Returns:
  /// A [FileTask] representing the download operation
  ///
  /// ## Metadata Handling:
  /// If [filePathAndUrl] contains metadata (e.g., from API response), it will be
  /// preserved and merged with locally extracted metadata after download completion.
  Future<FileTask> createDownloadTask({
    required FilePathAndURL filePathAndUrl,
    required String taskId,
    required FileGroupInfo group,
    bool autoStart = true,
    bool forceRefresh = false,
  }) async {
    // If filePathAndUrl has metadata, store it for later retrieval
    if (filePathAndUrl.metadata != null) {
      FilePathAndURLRepository.instance.addOrUpdate(filePathAndUrl);
    }

    return await FileTaskRepository.instance.createDownloadTask(
      url: filePathAndUrl.url!,
      taskId: taskId,
      group: group,
      autoStart: autoStart,
      cacheKey: filePathAndUrl.cacheKey,
      forceRefresh: forceRefresh,
    );
  }

  /// Creates a stream that emits download progress updates.
  ///
  /// This method uses the shared stream pattern - if multiple callers request
  /// a stream for the same download, they all share the same underlying stream.
  /// This prevents duplicate Firebase listeners and reduces resource usage.
  ///
  /// ## Parameters:
  /// - [task]: The download task to stream progress for
  /// - [controller]: Optional external stream controller (for internal use)
  ///
  /// ## Returns:
  /// A [Stream<FileTask>] that emits progress updates
  ///
  /// ## Example:
  /// ```dart
  /// final stream = repo.downloadTaskStream(task: downloadTask);
  /// stream.listen((task) {
  ///   print('Download progress: ${task.progressPercentage}%');
  ///   if (task.isComplete) {
  ///     print('File saved at: ${task.filePath}');
  ///   }
  /// });
  /// ```
  ///
  /// ## Stream Sharing:
  /// ```dart
  /// // Both listeners share the same underlying stream
  /// final stream1 = repo.downloadTaskStream(task: task);
  /// final stream2 = repo.downloadTaskStream(task: task);
  /// // Only ONE Firebase listener is created, both receive updates
  /// ```
  Stream<FileTask> downloadTaskStream({
    required FileTask task,
    StreamController<FileTask>? controller,
  }) {
    // If task is already complete, return immediately
    if (task.isComplete) {
      final streamController = controller ?? StreamController<FileTask>();
      streamController.add(task);
      streamController.close();
      return streamController.stream;
    }

    // Use shared stream from factory
    return FirebaseStorageFactory.getDownloadStream(
      url: task.url!,
      task: task,
      onUpdate: (updatedTask) {
        // Update repository (called once per event, not per subscriber)
        FileTaskRepository.instance.addOrUpdate(updatedTask);
      },
      onComplete: (updatedTask) async {
        // Get existing FilePathAndURL from repository (may contain API metadata)
        final existingFilePathAndUrl = FilePathAndURLRepository.instance
            .getByUrl(updatedTask.downloadUrl ?? '');
        var filePathAndURL = updatedTask.filePathAndURL;

        // Extract metadata from downloaded file and merge with existing
        final extractedMetadata = await MetadataExtractionService()
            .extractMetadata(
          File(updatedTask.filePath),
          existingMetadata: existingFilePathAndUrl?.metadata ?? filePathAndURL.metadata,
        );
        filePathAndURL = filePathAndURL.copyWithMergedMetadata(extractedMetadata);

        // Stamp timestamps: preserve createdAt on update, always set updatedAt
        final now = DateTime.now();
        final isNew = existingFilePathAndUrl == null;
        filePathAndURL = filePathAndURL.copyWith(
          createdAt: isNew ? now : existingFilePathAndUrl.createdAt,
          updatedAt: now,
        );

        // Save to file path repository for caching (includes metadata)
        FilePathAndURLRepository.instance.addOrUpdate(filePathAndURL);
        // Clean up completed tasks
        FirebaseStorageFactory.clearCompletedTasks();
      },
      onError: (errorTask, error) {
        // Update repository with error state
        FileTaskRepository.instance.addOrUpdate(errorTask);
        Logger().e('Download failed: ${error.runtimeType}');
        // Clean up after failure
        FirebaseStorageFactory.clearCompletedTasks();
      },
    );
  }

  /// Downloads multiple files in parallel with progress tracking.
  ///
  /// ## Parameters:
  /// - [filePathsAndUrls]: Set of files to download
  /// - [group]: Group information for the batch
  /// - [autoStart]: Whether to start downloads immediately (default: true)
  /// - [controller]: Optional external stream controller
  ///
  /// ## Returns:
  /// A [Stream<MultiDownloadFileTask>] that emits combined progress for all files
  Stream<MultiDownloadFileTask> downloadTasksParallelStream({
    required Set<FilePathAndURL> filePathsAndUrls,
    required FileGroupInfo group,
    bool autoStart = true,
    StreamController<MultiDownloadFileTask>? controller,
  }) {
    assert(
        filePathsAndUrls.isNotEmpty, 'File paths and urls must not be empty');
    final newController =
        controller ?? StreamController<MultiDownloadFileTask>();

    _downloadFilesParallelWithProgress(
      filePathsAndUrls: filePathsAndUrls,
      controller: newController,
      autoStart: autoStart,
      group: group,
    ).catchError((error) {
      newController.addError(FileDownloadException(
          'Failed to download files in parallel: $error'));
      newController.close();
    });

    return newController.stream;
  }

  /// Internal implementation for parallel downloads.
  Future<void> _downloadFilesParallelWithProgress({
    required Set<FilePathAndURL> filePathsAndUrls,
    required StreamController<MultiDownloadFileTask> controller,
    required FileGroupInfo group,
    bool autoStart = true,
  }) async {
    try {
      // Initialize tracking variables
      final List<FileTask> tasks = [];

      // Convert Set to List for O(1) access
      final filePathsAndUrlsList = filePathsAndUrls.toList();

      // Create all download tasks
      for (int i = 0; i < filePathsAndUrlsList.length; i++) {
        final filePathAndUrl = filePathsAndUrlsList[i];

        tasks.add(
          await FileTaskRepository.instance.createDownloadTask(
            taskId: '${group.id}_$i',
            url: filePathAndUrl.url!,
            group: group,
            autoStart: autoStart,
          ),
        );
      }

      // Emit initial progress
      controller
          .add(MultiDownloadFileTask.fromTasks(tasks: tasks, taskId: group.id));

      // Track completion count
      int completedCount = tasks.where((t) => t.isComplete).length;

      // Start downloads in parallel (uses shared streams internally)
      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];

        // Skip already completed tasks (cached)
        if (task.isComplete) continue;

        downloadTaskStream(task: task).listen((updatedTask) {
          // Update the task in our list
          tasks[i] = updatedTask;

          // Emit the progress update
          if (!controller.isClosed) {
            controller.add(
                MultiDownloadFileTask.fromTasks(tasks: tasks, taskId: group.id));
          }

          // Check if all tasks are complete
          if (updatedTask.isComplete) {
            completedCount++;
            if (completedCount >= tasks.length && !controller.isClosed) {
              controller.close();
            }
          }
        });
      }

      // Emit initial state
      if (!controller.isClosed) {
        controller
            .add(MultiDownloadFileTask.fromTasks(tasks: tasks, taskId: group.id));
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(
            FileDownloadException('Failed to download files in parallel: $e'));
        controller.close();
      }
    }
  }
}
