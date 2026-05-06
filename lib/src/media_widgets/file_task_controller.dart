import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';

import '../core/extension/file_path_extension.dart';
import 'utils/map_notifier.dart';

export 'package:background_downloader/background_downloader.dart';

/// Controller for managing file download tasks.
///
/// This singleton class provides a centralized way to manage file downloads
/// using the background_downloader package.
class FileTaskController {
  bool isInitialized = false;
  final FileDownloader _fileDownloader = FileDownloader();
  FileDownloader get fileDownloader => _fileDownloader;
  final Map<String, String> _filePaths = {};
  final Map<String, TaskItem> fileUpdates = {};
  final Set<String> _taskUrlsInQueue = {};
  final MapNotifier<String, StreamController<TaskItem>> _fileControllers =
      MapNotifier<String, StreamController<TaskItem>>({});

  // Singleton pattern
  static final FileTaskController instance = FileTaskController._internal();
  factory FileTaskController() => instance;
  FileTaskController._internal();

  /// file stream controller get
  StreamController<TaskItem>? getFileController(String url) =>
      _fileControllers.value[url];

  /// file stream controller create
  StreamController<TaskItem> createFileController(String url) {
    var controller = getFileController(url);
    controller ??= _fileControllers.add(
      url,
      StreamController<TaskItem>.broadcast(),
    );

    return controller;
  }

  // Initialize the controller and setup listeners
  Future<void> initialize() async {
    if (isInitialized) return;
    isInitialized = true;

    // Registering a callback and configure notifications
    FileDownloader()
        .registerCallbacks(
          taskNotificationTapCallback: myNotificationTapCallback,
        )
        .configureNotificationForGroup(
          FileDownloader.defaultGroup,
          running: const TaskNotification(
            'Download {filename}',
            'File: {filename} - {progress} - speed {networkSpeed} and {timeRemaining} remaining',
          ),
          complete: const TaskNotification(
            '{displayName} download {filename}',
            'Download complete',
          ),
          error: const TaskNotification(
            'Download {filename}',
            'Download failed',
          ),
          paused: const TaskNotification(
            'Download {filename}',
            'Paused with metadata {metadata}',
          ),
          canceled: const TaskNotification('Download {filename}', 'Canceled'),
          progressBar: false,
        )
        .configureNotificationForGroup(
          'bunch',
          running: const TaskNotification(
            '{numFinished} out of {numTotal}',
            'Progress = {progress}',
          ),
          complete: const TaskNotification('Done!', 'Loaded {numTotal} files'),
          error: const TaskNotification(
            'Error',
            '{numFailed}/{numTotal} failed',
          ),
          progressBar: false,
          groupNotificationId: 'notGroup',
        )
        .configureNotification(
          complete: const TaskNotification(
            'Download {filename}',
            'Download complete',
          ),
          tapOpensFile: false,
        );

    fileDownloader.database.allRecords().then((records) {
      for (final record in records) {
        _addTaskItem(TaskItem.fromRecord(record));
      }
    });

    fileDownloader.updates.listen((update) {
      _addTaskItem(update);
    });

    await fileDownloader.trackTasks();
    fileDownloader.start();
  }

  void _addTaskItem(TaskUpdate taskUpdate) {
    var taskItem = fileUpdates[taskUpdate.task.url];
    if (taskItem != null) taskItem = taskItem.copyWithUpdate(taskUpdate);

    taskItem ??= TaskItem.fromUpdate(taskUpdate);

    if (taskItem.progress == 1.0) {
      _filePaths[taskItem.url] = taskItem.filePath;
    }

    fileUpdates[taskItem.url] = taskItem;
    createFileController(taskItem.url).add(taskItem);
  }

  Future<(String? filePath, StreamController<TaskItem>? streamController)>
      enqueueOrResume(Task task, bool autoStart) async {
    final filePath = _filePaths[task.url];

    if (filePath != null) return (filePath, null);

    final taskItem = fileUpdates[task.url];
    var streamController = createFileController(task.url);
    if (taskItem != null) return (null, streamController);

    if (autoStart && !_taskUrlsInQueue.contains(task.url)) {
      _taskUrlsInQueue.add(task.url);
      await fileDownloader.enqueue(task);
    }

    return (null, streamController);
  }

  Future<bool> pause(TaskItem taskItem) async {
    final task = taskItem.task;
    if (task is! DownloadTask) return false;

    return await fileDownloader.pause(task);
  }

  Future<bool> resume(TaskItem taskItem) async {
    final task = taskItem.task;
    if (task is! DownloadTask) return false;

    return await fileDownloader.resume(task);
  }

  Future<bool> cancel(TaskItem taskItem) async {
    final task = taskItem.task;
    if (task is! DownloadTask) return false;

    return await fileDownloader.cancel(task);
  }

  /// Retry a failed download task
  Future<bool> retry(TaskItem taskItem) async {
    final task = taskItem.task;
    if (task is! DownloadTask) return false;

    // Remove the task from queue tracking to allow re-enqueue
    _taskUrlsInQueue.remove(task.url);

    // Re-enqueue the task
    return await fileDownloader.enqueue(task);
  }

  Future<bool> openFile(TaskItem taskItem) async {
    final task = taskItem.task;
    if (task is! DownloadTask) return false;

    return await fileDownloader.openFile(task: task);
  }

  Future<void> deleteFile(TaskItem taskItem) async {
    final task = taskItem.task;

    await fileDownloader.database.deleteRecordWithId(task.taskId);
    _filePaths.remove(task.url);
    fileUpdates.remove(task.url);
    _fileControllers.value.remove(task.url);
  }

  // Settings operations
  Future<bool> requireWiFi(
    RequireWiFi requireWiFi, {
    bool rescheduleRunningTasks = false,
  }) async {
    return fileDownloader.requireWiFi(
      requireWiFi,
      rescheduleRunningTasks: rescheduleRunningTasks,
    );
  }

  Future<void> configure({
    List<(Config, Object)>? globalConfig,
    List<(Config, Object)>? androidConfig,
    List<(Config, Object)>? iOSConfig,
    List<(Config, Object)>? desktopConfig,
  }) async {
    await fileDownloader.configure(
      globalConfig: globalConfig,
      androidConfig: androidConfig,
      iOSConfig: iOSConfig,
      desktopConfig: desktopConfig,
    );
  }

  // Notification configuration
  void configureNotificationForGroup(
    String group, {
    TaskNotification? running,
    TaskNotification? complete,
    TaskNotification? error,
    TaskNotification? paused,
    bool progressBar = false,
  }) {
    fileDownloader.configureNotificationForGroup(
      group,
      running: running,
      complete: complete,
      error: error,
      paused: paused,
      progressBar: progressBar,
    );
  }

  // File picker operations
  Future<Uri?> pickFile() async {
    return await fileDownloader.uri.pickFile();
  }

  // Batch operations
  Future<List<bool>> pauseAllTasks(List<TaskItem> tasks) async {
    final results = <bool>[];
    for (final task in tasks) {
      try {
        final success = await pause(task);
        results.add(success);
      } catch (e) {
        results.add(false);
      }
    }
    return results;
  }

  Future<List<bool>> resumeAllTasks(List<TaskItem> tasks) async {
    final results = <bool>[];
    for (final task in tasks) {
      try {
        final success = await resume(task);
        results.add(success);
      } catch (e) {
        results.add(false);
      }
    }
    return results;
  }

  Future<bool> cancelAllTasks(List<TaskItem> tasks) async {
    final taskIds = tasks.map((task) => task.taskId).toList();
    return await fileDownloader.cancelTasksWithIds(taskIds);
  }

  // Utility methods
  String get defaultGroup => FileDownloader.defaultGroup;

  // Dispose method
  void dispose() {
    _fileControllers.value.forEach((url, controller) => controller.close());
    _fileControllers.value.clear();
    fileUpdates.clear();
    _filePaths.clear();
    _fileControllers.dispose();
  }

  void myNotificationTapCallback(Task task, NotificationType notificationType) {
    debugPrint(
      'Tapped notification $notificationType for taskId ${task.taskId}',
    );
  }
}

/// Represents a download task item with status and progress information.
class TaskItem implements TaskProgressUpdate, TaskStatusUpdate {
  @override
  final Task task;
  String get taskId => task.taskId;
  String get filename => task.filename;
  String get url => task.url;
  String get displayName => task.displayName;
  String get directory => task.directory;
  BaseDirectory get baseDirectory => task.baseDirectory;
  DateTime get createdAt => task.creationTime;
  String get metaData => task.metaData;
  String get group => task.group;
  bool get requiresWiFi => task.requiresWiFi;
  int get retries => task.retries;
  bool get allowPause => task.allowPause;
  Updates get updates => task.updates;

  @override
  int expectedFileSize;
  @override
  TaskStatus status;
  @override
  double progress;
  @override
  double networkSpeed;
  @override
  Duration timeRemaining;
  @override
  TaskException? exception;

  @override
  String? get charSet => null;

  @override
  bool get hasExpectedFileSize => expectedFileSize > 0;

  @override
  bool get hasNetworkSpeed => networkSpeed > 0;

  @override
  bool get hasTimeRemaining => timeRemaining.inSeconds > 0;

  @override
  String? get mimeType => filename.split('.').last.split('?').first;

  @override
  String get networkSpeedAsString => networkSpeedText;

  @override
  String? get responseBody => null;

  @override
  Map<String, String>? get responseHeaders => null;

  @override
  int? get responseStatusCode => null;

  @override
  String get timeRemainingAsString => timeRemainingText;

  String get filePath {
    String path = baseDirectory.path;

    var directoryPath = directory.trim().isNotEmpty ? directory.trim() : null;
    if (directoryPath != null) path += '/$directoryPath';
    return '$path/${filename.trim()}';
  }

  TaskItem({
    required this.task,
    required this.expectedFileSize,
    this.status = TaskStatus.enqueued,
    this.progress = 0.0,
    this.networkSpeed = 0.0,
    this.timeRemaining = Duration.zero,
    this.exception,
  });

  TaskItem.from(this.task)
      : expectedFileSize = 0,
        status = TaskStatus.enqueued,
        progress = 0.0,
        networkSpeed = 0.0,
        timeRemaining = Duration.zero,
        exception = null;

  TaskItem.fromJson(Map<String, dynamic> json)
      : task = Task.createFromJson(json['task'] ?? json),
        expectedFileSize = json['expectedFileSize'] ?? 0,
        status = json['status'] ?? TaskStatus.enqueued,
        progress = json['progress'] ?? 0.0,
        networkSpeed = json['networkSpeed'] ?? 0.0,
        timeRemaining = json['timeRemaining'] ?? Duration.zero,
        exception = json['exception'];

  TaskItem.fromUpdate(TaskUpdate update)
      : task = update.task,
        expectedFileSize = 0,
        status =
            update is TaskStatusUpdate ? update.status : TaskStatus.enqueued,
        progress = update is TaskProgressUpdate ? update.progress : 0.0,
        networkSpeed = update is TaskProgressUpdate ? update.networkSpeed : 0.0,
        timeRemaining =
            update is TaskProgressUpdate ? update.timeRemaining : Duration.zero,
        exception = update is TaskStatusUpdate ? update.exception : null;

  TaskItem.fromRecord(TaskRecord record)
      : task = record.task,
        expectedFileSize = record.expectedFileSize,
        status = record.status,
        progress = record.progress,
        networkSpeed = 0,
        timeRemaining = Duration.zero,
        exception = record.exception;

  @override
  TaskItem copyWith({
    Task? task,
    TaskStatus? status,
    TaskException? exception,
    String? responseBody,
    Map<String, String>? responseHeaders,
    int? responseStatusCode,
    String? mimeType,
    String? charSet,
    int? expectedFileSize,
    double? progress,
    double? networkSpeed,
    Duration? timeRemaining,
  }) {
    return TaskItem(
      task: task ?? this.task,
      expectedFileSize: expectedFileSize ?? this.expectedFileSize,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      networkSpeed: networkSpeed ?? this.networkSpeed,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      exception: exception ?? this.exception,
    );
  }

  TaskItem copyWithUpdate(TaskUpdate update) {
    var newProgress = update is TaskProgressUpdate ? update.progress : progress;
    return copyWith(
      status: update is TaskStatusUpdate ? update.status : status,
      progress: newProgress > 0 ? newProgress : progress,
      networkSpeed:
          update is TaskProgressUpdate ? update.networkSpeed : networkSpeed,
      timeRemaining:
          update is TaskProgressUpdate ? update.timeRemaining : timeRemaining,
      exception: update is TaskStatusUpdate ? update.exception : exception,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'task': task.toJson(),
      'expectedFileSize': expectedFileSize,
      'status': status.name,
      'progress': progress,
      'networkSpeed': networkSpeed,
      'timeRemaining': timeRemaining.inSeconds,
      'exception': exception?.toJson(),
    };
  }

  String get statusText {
    switch (status) {
      case TaskStatus.enqueued:
        return 'Waiting';
      case TaskStatus.running:
        return 'Downloading';
      case TaskStatus.complete:
        return 'Complete';
      case TaskStatus.failed:
        return 'Failed';
      case TaskStatus.canceled:
        return 'Canceled';
      case TaskStatus.paused:
        return 'Paused';
      case TaskStatus.notFound:
        return 'Not Found';
      case TaskStatus.waitingToRetry:
        return 'Waiting to Retry';
    }
  }

  String get networkSpeedText {
    if (networkSpeed <= 0) return '--';

    if (networkSpeed < 1024) {
      return '${networkSpeed.toStringAsFixed(1)} B/s';
    } else if (networkSpeed < 1024 * 1024) {
      return '${(networkSpeed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(networkSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  String get timeRemainingText {
    if (timeRemaining.inSeconds <= 0) return '--';

    final hours = timeRemaining.inHours;
    final minutes = timeRemaining.inMinutes.remainder(60);
    final seconds = timeRemaining.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get fileSizeText {
    if (expectedFileSize <= 0) return '--';

    final size = expectedFileSize;
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String get progressText {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  int get downloadedBytes {
    if (expectedFileSize <= 0) return 0;
    return (expectedFileSize * progress).round();
  }

  String get downloadedSizeText {
    final downloaded = downloadedBytes;
    if (downloaded <= 0) return '0 B';

    if (downloaded < 1024) {
      return '$downloaded B';
    } else if (downloaded < 1024 * 1024) {
      return '${(downloaded / 1024).toStringAsFixed(1)} KB';
    } else if (downloaded < 1024 * 1024 * 1024) {
      return '${(downloaded / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(downloaded / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String get pausedProgressText {
    if (expectedFileSize <= 0) {
      return '$progressText complete';
    }
    return '$downloadedSizeText of $fileSizeText ($progressText)';
  }

  @override
  String toString() {
    return 'TaskItem(task: $task, expectedFileSize: $expectedFileSize, status: $status, progress: $progress, networkSpeed: $networkSpeed, timeRemaining: $timeRemaining, exception: $exception)';
  }
}

/// Extension to get the path for BaseDirectory
extension BaseDirectoryExtension on BaseDirectory {
  String get path {
    return switch (this) {
      BaseDirectory.applicationDocuments =>
        AppDirectory.instance.applicationDocumentsDirectory!.path,
      BaseDirectory.temporary => AppDirectory.instance.temporaryDirectory!.path,
      BaseDirectory.applicationSupport =>
        AppDirectory.instance.applicationSupportDirectory!.path,
      BaseDirectory.applicationLibrary =>
        AppDirectory.instance.applicationSupportDirectory!.path,
      BaseDirectory.root => AppDirectory.instance.rootDirectory!.path,
    };
  }
}

/// Extension to get color for TaskStatus
extension TaskStatusExtension on TaskStatus {
  Color get color {
    return switch (this) {
      TaskStatus.enqueued => Colors.blue,
      TaskStatus.running => Colors.purple,
      TaskStatus.complete => Colors.green,
      TaskStatus.failed => Colors.red,
      TaskStatus.paused => Colors.orange,
      TaskStatus.canceled => Colors.grey,
      TaskStatus.waitingToRetry => Colors.grey,
      TaskStatus.notFound => Colors.grey,
    };
  }
}
