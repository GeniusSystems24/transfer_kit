part of 'file_task_repository.dart';

/// Firebase Storage factory for managing upload and download tasks with stream sharing.
///
/// This factory implements a shared stream pattern to optimize resource usage when
/// multiple widgets request the same file transfer. Instead of creating duplicate
/// listeners for the same Firebase task, it shares a single broadcast stream
/// among all subscribers.
///
/// ## Key Features:
/// - **Stream Sharing**: Multiple subscribers share the same stream for identical transfers
/// - **Reference Counting**: Automatic cleanup when all subscribers disconnect
/// - **Memory Management**: Automatic cleanup of completed tasks and streams
/// - **Delayed Cleanup**: Prevents rapid re-creation of streams during widget rebuilds
///
/// ## Architecture:
/// ```
/// Request 1 ─┐
/// Request 2 ─┼──► Single Firebase Task ──► Shared Broadcast Stream
/// Request 3 ─┘         │                          │
///                      ▼                          ▼
///              One snapshotEvents          Multiple Subscribers
///                  listener                (no duplicate updates)
/// ```
///
/// ## Example:
/// ```dart
/// // Both calls return the same shared stream
/// final stream1 = FirebaseStorageFactory.getDownloadStream(url: url, task: task);
/// final stream2 = FirebaseStorageFactory.getDownloadStream(url: url, task: task);
/// // stream1 and stream2 point to the same broadcast stream
/// ```
abstract class FirebaseStorageFactory {
  // ═══════════════════════════════════════════════════════════════════════════
  // FIREBASE TASK CACHING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cache for download tasks - prevents creating duplicate Firebase download tasks
  static final Map<String, DownloadTask> _downloadTaskMap = {};

  /// Cache for upload tasks - prevents creating duplicate Firebase upload tasks
  static final Map<String, UploadTask> _uploadTaskMap = {};

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAM CACHING (NEW - Shared Stream Pattern)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cache for active download streams - enables stream sharing across subscribers
  static final Map<String, StreamController<FileTask>> _downloadStreamCache = {};

  /// Cache for active upload streams - enables stream sharing across subscribers
  static final Map<String, StreamController<FileTask>> _uploadStreamCache = {};

  /// Reference counter for download streams - tracks active subscribers
  static final Map<String, int> _downloadStreamRefCount = {};

  /// Reference counter for upload streams - tracks active subscribers
  static final Map<String, int> _uploadStreamRefCount = {};

  /// Subscriptions to Firebase snapshot events - one per unique transfer
  static final Map<String, StreamSubscription> _downloadSubscriptions = {};
  static final Map<String, StreamSubscription> _uploadSubscriptions = {};

  /// Gets the cleanup delay from configuration.
  ///
  /// This delay prevents rapid cleanup/recreation of streams during widget rebuilds.
  static Duration get _cleanupDelay =>
      FileManagementConfig.instance.streamCleanupDelay;

  // ═══════════════════════════════════════════════════════════════════════════
  // DOWNLOAD TASK CREATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates or retrieves a cached Firebase download task.
  ///
  /// If a download task for the given [url] already exists, returns the cached task.
  /// Otherwise, creates a new download task and caches it.
  ///
  /// ## Parameters:
  /// - [url]: The Firebase Storage URL to download from
  /// - [autoStart]: If false, pauses the task immediately after creation (default: false)
  ///
  /// ## Returns:
  /// The Firebase [DownloadTask] for the given URL
  static DownloadTask createDownload(String url, {bool autoStart = false}) {
    return _downloadTaskMap.putIfAbsent(url, () {
      final taskRef = FirebaseStorage.instance.refFromURL(url);
      final filePath = url.toHashName().toCachedPath();

      var task = taskRef.writeToFile(File(filePath));

      // Pause immediately if autoStart is false (allows manual start later)
      if (!autoStart) {
        Future.delayed(const Duration(milliseconds: 50), () => task.pause());
      }

      return task;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UPLOAD TASK CREATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates or retrieves a cached Firebase upload task.
  ///
  /// If an upload task for the given [filePath] already exists, returns the cached task.
  /// Otherwise, creates a new upload task and caches it.
  ///
  /// ## Parameters:
  /// - [filePath]: The local file path to upload
  /// - [destinationPath]: The destination path in Firebase Storage
  /// - [autoStart]: If false, pauses the task immediately after creation (default: false)
  ///
  /// ## Returns:
  /// The Firebase [UploadTask] for the given file
  static UploadTask createUpload(String filePath, String destinationPath,
      {bool autoStart = false}) {
    return _uploadTaskMap.putIfAbsent(filePath, () {
      final taskRef = FirebaseStorage.instance.ref(destinationPath);

      var task = taskRef.putFile(File(filePath));
      if (!autoStart) task.pause();
      return task;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED DOWNLOAD STREAM (NEW)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets or creates a shared download stream for the given URL.
  ///
  /// This method implements the shared stream pattern:
  /// 1. If a stream already exists for this URL, increments the reference count
  ///    and returns the existing stream
  /// 2. If no stream exists, creates a new broadcast stream, sets up the
  ///    Firebase snapshot listener, and returns the new stream
  ///
  /// ## Parameters:
  /// - [url]: The Firebase Storage URL (used as cache key)
  /// - [task]: The [FileTask] to update with progress
  /// - [onUpdate]: Callback invoked when task state changes (called once per event)
  /// - [onComplete]: Callback invoked when download completes successfully
  /// - [onError]: Callback invoked when an error occurs
  ///
  /// ## Returns:
  /// A broadcast [Stream<FileTask>] that can have multiple subscribers
  ///
  /// ## Example:
  /// ```dart
  /// final stream = FirebaseStorageFactory.getDownloadStream(
  ///   url: 'gs://bucket/path/file.jpg',
  ///   task: fileTask,
  ///   onUpdate: (task) => repository.addOrUpdate(task),
  ///   onComplete: (task) => handleComplete(task),
  ///   onError: (task, error) => handleError(error),
  /// );
  /// ```
  static Stream<FileTask> getDownloadStream({
    required String url,
    required FileTask task,
    required void Function(FileTask task) onUpdate,
    required void Function(FileTask task) onComplete,
    required void Function(FileTask task, Object error) onError,
  }) {
    // Check if a shared stream already exists for this URL
    if (_downloadStreamCache.containsKey(url) &&
        !_downloadStreamCache[url]!.isClosed) {
      // Increment reference count and return existing stream
      _downloadStreamRefCount[url] = (_downloadStreamRefCount[url] ?? 0) + 1;
      return _downloadStreamCache[url]!.stream;
    }

    // Create new broadcast stream controller
    final controller = StreamController<FileTask>.broadcast(
      onCancel: () => _handleDownloadStreamCancel(url),
    );

    // Cache the controller and initialize reference count
    _downloadStreamCache[url] = controller;
    _downloadStreamRefCount[url] = 1;

    // Get or create the Firebase download task
    final downloadTask = createDownload(url, autoStart: true);

    // Set up single listener on Firebase snapshot events
    _downloadSubscriptions[url] = downloadTask.snapshotEvents.listen(
      (TaskSnapshot snapshot) async {
        // Update task with new progress
        final updatedTask = task.copyWith(
          state: snapshot.state.fileTaskState,
          progress: FileProgress(
            bytesTransferred: snapshot.bytesTransferred,
            totalBytes: snapshot.totalBytes,
          ),
          lastUpdatedAt: DateTime.now(),
        );

        // Notify repository (once per event, regardless of subscriber count)
        onUpdate(updatedTask);

        if (snapshot.state == TaskState.success) {
          // Handle successful completion
          onComplete(updatedTask);
          if (!controller.isClosed) {
            controller.add(updatedTask);
            controller.close();
          }
          _cleanupDownloadStream(url);
        } else {
          // Emit progress update to all subscribers
          if (!controller.isClosed) {
            controller.add(updatedTask);
          }
        }
      },
      onError: (error) {
        // Handle error
        final errorTask = task.copyWith(
          state: FileTaskState.error,
          errorMessage: error.toString(),
        );
        onError(errorTask, error);
        if (!controller.isClosed) {
          controller.addError(FileDownloadException('Download failed: $error'));
          controller.close();
        }
        _cleanupDownloadStream(url);
      },
    );

    // Emit initial task state
    if (!controller.isClosed) {
      controller.add(task);
    }

    return controller.stream;
  }

  /// Handles download stream cancellation with delayed cleanup.
  ///
  /// When a subscriber cancels, decrements the reference count.
  /// If no subscribers remain, schedules cleanup after [_cleanupDelay].
  /// The delay prevents rapid cleanup/recreation during widget rebuilds.
  static void _handleDownloadStreamCancel(String url) {
    _downloadStreamRefCount[url] = (_downloadStreamRefCount[url] ?? 1) - 1;

    if (_downloadStreamRefCount[url]! <= 0) {
      // Schedule cleanup after delay
      Future.delayed(_cleanupDelay, () {
        // Only cleanup if still no subscribers
        if (_downloadStreamRefCount[url] == null ||
            _downloadStreamRefCount[url]! <= 0) {
          _cleanupDownloadStream(url);
        }
      });
    }
  }

  /// Cleans up download stream resources for the given URL.
  static void _cleanupDownloadStream(String url) {
    _downloadSubscriptions[url]?.cancel();
    _downloadSubscriptions.remove(url);

    if (_downloadStreamCache[url]?.isClosed == false) {
      _downloadStreamCache[url]?.close();
    }
    _downloadStreamCache.remove(url);
    _downloadStreamRefCount.remove(url);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED UPLOAD STREAM (NEW)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets or creates a shared upload stream for the given file path.
  ///
  /// This method implements the shared stream pattern for uploads:
  /// 1. If a stream already exists for this file, increments the reference count
  ///    and returns the existing stream
  /// 2. If no stream exists, creates a new broadcast stream, sets up the
  ///    Firebase snapshot listener, and returns the new stream
  ///
  /// ## Parameters:
  /// - [filePath]: The local file path (used as cache key)
  /// - [destinationPath]: The destination path in Firebase Storage
  /// - [task]: The [FileTask] to update with progress
  /// - [onUpdate]: Callback invoked when task state changes (called once per event)
  /// - [onComplete]: Callback invoked when upload completes successfully
  /// - [onError]: Callback invoked when an error occurs
  ///
  /// ## Returns:
  /// A broadcast [Stream<FileTask>] that can have multiple subscribers
  static Stream<FileTask> getUploadStream({
    required String filePath,
    required String destinationPath,
    required FileTask task,
    required void Function(FileTask task) onUpdate,
    required void Function(FileTask task, String downloadUrl) onComplete,
    required void Function(FileTask task, Object error) onError,
  }) {
    // Check if a shared stream already exists for this file
    if (_uploadStreamCache.containsKey(filePath) &&
        !_uploadStreamCache[filePath]!.isClosed) {
      // Increment reference count and return existing stream
      _uploadStreamRefCount[filePath] =
          (_uploadStreamRefCount[filePath] ?? 0) + 1;
      return _uploadStreamCache[filePath]!.stream;
    }

    // Create new broadcast stream controller
    final controller = StreamController<FileTask>.broadcast(
      onCancel: () => _handleUploadStreamCancel(filePath),
    );

    // Cache the controller and initialize reference count
    _uploadStreamCache[filePath] = controller;
    _uploadStreamRefCount[filePath] = 1;

    // Get or create the Firebase upload task
    final uploadTask =
        createUpload(filePath, destinationPath, autoStart: true);

    // Set up single listener on Firebase snapshot events
    _uploadSubscriptions[filePath] = uploadTask.snapshotEvents.listen(
      (TaskSnapshot snapshot) async {
        // Update task with new progress
        var updatedTask = task.copyWith(
          state: snapshot.state.fileTaskState,
          progress: FileProgress(
            bytesTransferred: snapshot.bytesTransferred,
            totalBytes: snapshot.totalBytes,
          ),
          lastUpdatedAt: DateTime.now(),
        );

        // Notify repository (once per event, regardless of subscriber count)
        onUpdate(updatedTask);

        if (snapshot.state == TaskState.success) {
          // Get download URL and handle completion
          final downloadUrl = await task.reference.getDownloadURL();
          updatedTask = updatedTask.copyWith(downloadUrl: downloadUrl);
          onComplete(updatedTask, downloadUrl);

          if (!controller.isClosed) {
            controller.add(updatedTask);
            controller.close();
          }
          _cleanupUploadStream(filePath);
        } else {
          // Emit progress update to all subscribers
          if (!controller.isClosed) {
            controller.add(updatedTask);
          }
        }
      },
      onError: (error) {
        // Handle error
        final errorTask = task.copyWith(
          state: FileTaskState.error,
          errorMessage: error.toString(),
        );
        onError(errorTask, error);
        if (!controller.isClosed) {
          controller.addError(FileUploadException('Upload failed: $error'));
          controller.close();
        }
        _cleanupUploadStream(filePath);
      },
    );

    // Emit initial task state
    if (!controller.isClosed) {
      controller.add(task);
    }

    return controller.stream;
  }

  /// Handles upload stream cancellation with delayed cleanup.
  static void _handleUploadStreamCancel(String filePath) {
    _uploadStreamRefCount[filePath] =
        (_uploadStreamRefCount[filePath] ?? 1) - 1;

    if (_uploadStreamRefCount[filePath]! <= 0) {
      // Schedule cleanup after delay
      Future.delayed(_cleanupDelay, () {
        // Only cleanup if still no subscribers
        if (_uploadStreamRefCount[filePath] == null ||
            _uploadStreamRefCount[filePath]! <= 0) {
          _cleanupUploadStream(filePath);
        }
      });
    }
  }

  /// Cleans up upload stream resources for the given file path.
  static void _cleanupUploadStream(String filePath) {
    _uploadSubscriptions[filePath]?.cancel();
    _uploadSubscriptions.remove(filePath);

    if (_uploadStreamCache[filePath]?.isClosed == false) {
      _uploadStreamCache[filePath]?.close();
    }
    _uploadStreamCache.remove(filePath);
    _uploadStreamRefCount.remove(filePath);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLEANUP METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cleans up completed tasks from memory to prevent memory leaks.
  ///
  /// Removes tasks that are in success, error, or canceled state from both
  /// download and upload task caches.
  static void clearCompletedTasks() {
    // Clean up completed download tasks
    _downloadTaskMap.removeWhere(
      (key, task) =>
          task.snapshot.state == TaskState.success ||
          task.snapshot.state == TaskState.error ||
          task.snapshot.state == TaskState.canceled,
    );

    // Clean up completed upload tasks
    _uploadTaskMap.removeWhere(
      (key, task) =>
          task.snapshot.state == TaskState.success ||
          task.snapshot.state == TaskState.error ||
          task.snapshot.state == TaskState.canceled,
    );

    // Clean up completed stream caches
    _cleanupCompletedStreams();
  }

  /// Cleans up stream caches for completed transfers.
  static void _cleanupCompletedStreams() {
    // Clean download streams for completed tasks
    final completedDownloads = _downloadTaskMap.entries
        .where((e) =>
            e.value.snapshot.state == TaskState.success ||
            e.value.snapshot.state == TaskState.error ||
            e.value.snapshot.state == TaskState.canceled)
        .map((e) => e.key)
        .toList();

    for (final url in completedDownloads) {
      _cleanupDownloadStream(url);
    }

    // Clean upload streams for completed tasks
    final completedUploads = _uploadTaskMap.entries
        .where((e) =>
            e.value.snapshot.state == TaskState.success ||
            e.value.snapshot.state == TaskState.error ||
            e.value.snapshot.state == TaskState.canceled)
        .map((e) => e.key)
        .toList();

    for (final path in completedUploads) {
      _cleanupUploadStream(path);
    }
  }

  /// Clears all tasks and streams from memory.
  ///
  /// Use this method to completely reset the factory state.
  /// Warning: This will cancel all active transfers.
  static void clearAllTasks() {
    // Cancel all subscriptions
    for (final sub in _downloadSubscriptions.values) {
      sub.cancel();
    }
    for (final sub in _uploadSubscriptions.values) {
      sub.cancel();
    }

    // Close all stream controllers
    for (final controller in _downloadStreamCache.values) {
      if (!controller.isClosed) controller.close();
    }
    for (final controller in _uploadStreamCache.values) {
      if (!controller.isClosed) controller.close();
    }

    // Clear all caches
    _downloadTaskMap.clear();
    _uploadTaskMap.clear();
    _downloadStreamCache.clear();
    _uploadStreamCache.clear();
    _downloadStreamRefCount.clear();
    _uploadStreamRefCount.clear();
    _downloadSubscriptions.clear();
    _uploadSubscriptions.clear();
  }

  /// Gets the count of active (running or paused) tasks.
  ///
  /// Returns the total number of active download and upload tasks.
  static int getActiveTasksCount() {
    final activeDownloads = _downloadTaskMap.values
        .where((task) =>
            task.snapshot.state == TaskState.running ||
            task.snapshot.state == TaskState.paused)
        .length;
    final activeUploads = _uploadTaskMap.values
        .where((task) =>
            task.snapshot.state == TaskState.running ||
            task.snapshot.state == TaskState.paused)
        .length;
    return activeDownloads + activeUploads;
  }

  /// Gets the count of active shared streams.
  ///
  /// Useful for debugging and monitoring stream sharing effectiveness.
  static Map<String, int> getActiveStreamStats() {
    return {
      'downloadStreams': _downloadStreamCache.length,
      'uploadStreams': _uploadStreamCache.length,
      'downloadSubscribers': _downloadStreamRefCount.values.fold(0, (a, b) => a + b),
      'uploadSubscribers': _uploadStreamRefCount.values.fold(0, (a, b) => a + b),
    };
  }
}
