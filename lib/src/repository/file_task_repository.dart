import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../core/driver/transfer_driver.dart';
import '../core/extension/string_extension.dart';
import '../core/file_management_config.dart';
import '../core/get_storage_repository.dart';
import '../model/file_exception.dart';
import '../model/file_path_and_url.dart';
import '../model/file_task.dart';
import '../model/multi_download_file_task.dart';
import '../model/multi_upload_file_task.dart';
import '../service/metadata_extraction_service.dart';
import 'file_path_and_url_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stream-sharing state (replaces FirebaseStorageFactory)
// ─────────────────────────────────────────────────────────────────────────────

final Map<String, StreamController<FileTask>> _downloadStreamCache = {};
final Map<String, StreamController<FileTask>> _uploadStreamCache = {};
final Map<String, int> _downloadStreamRefCount = {};
final Map<String, int> _uploadStreamRefCount = {};
final Map<String, StreamSubscription<TransferProgressEvent>>
_downloadSubscriptions = {};
final Map<String, StreamSubscription<TransferProgressEvent>>
_uploadSubscriptions = {};

Duration get _cleanupDelay => TransferKitConfig.instance.streamCleanupDelay;

void _cleanupDownloadStream(String key) {
  _downloadSubscriptions[key]?.cancel();
  _downloadSubscriptions.remove(key);
  if (_downloadStreamCache[key]?.isClosed == false) {
    _downloadStreamCache[key]?.close();
  }
  _downloadStreamCache.remove(key);
  _downloadStreamRefCount.remove(key);
}

void _cleanupUploadStream(String key) {
  _uploadSubscriptions[key]?.cancel();
  _uploadSubscriptions.remove(key);
  if (_uploadStreamCache[key]?.isClosed == false) {
    _uploadStreamCache[key]?.close();
  }
  _uploadStreamCache.remove(key);
  _uploadStreamRefCount.remove(key);
}

void _handleDownloadStreamCancel(String key) {
  _downloadStreamRefCount[key] = (_downloadStreamRefCount[key] ?? 1) - 1;
  if (_downloadStreamRefCount[key]! <= 0) {
    Future.delayed(_cleanupDelay, () {
      if ((_downloadStreamRefCount[key] ?? 0) <= 0) {
        _cleanupDownloadStream(key);
      }
    });
  }
}

void _handleUploadStreamCancel(String key) {
  _uploadStreamRefCount[key] = (_uploadStreamRefCount[key] ?? 1) - 1;
  if (_uploadStreamRefCount[key]! <= 0) {
    Future.delayed(_cleanupDelay, () {
      if ((_uploadStreamRefCount[key] ?? 0) <= 0) {
        _cleanupUploadStream(key);
      }
    });
  }
}

Stream<FileTask> _getSharedDownloadStream({
  required String key,
  required FileTask task,
  required TransferDriver driver,
  required void Function(FileTask) onUpdate,
  required Future<void> Function(FileTask) onComplete,
  required void Function(FileTask, Object) onError,
}) {
  if (_downloadStreamCache.containsKey(key) &&
      !_downloadStreamCache[key]!.isClosed) {
    _downloadStreamRefCount[key] = (_downloadStreamRefCount[key] ?? 0) + 1;
    return _downloadStreamCache[key]!.stream;
  }

  final controller = StreamController<FileTask>.broadcast(
    onCancel: () => _handleDownloadStreamCancel(key),
  );
  _downloadStreamCache[key] = controller;
  _downloadStreamRefCount[key] = 1;

  final request = DownloadRequest(
    taskId: task.id,
    source: Uri.parse(task.downloadUrl!),
    localPath: task.filePath,
    cacheKey: task.id,
  );

  _downloadSubscriptions[key] = driver
      .download(request)
      .listen(
        (event) async {
          if (event is TransferProgressUpdate) {
            final updated = task.copyWith(
              state: FileTaskState.running,
              progress: FileProgress(
                bytesTransferred: event.bytesTransferred,
                totalBytes: event.totalBytes,
              ),
              lastUpdatedAt: DateTime.now(),
            );
            onUpdate(updated);
            if (!controller.isClosed) controller.add(updated);
          } else if (event is TransferCompleted) {
            final updated = task.copyWith(
              state: FileTaskState.completed,
              filePath: event.localPath ?? task.filePath,
              progress: FileProgress(bytesTransferred: 1, totalBytes: 1),
              lastUpdatedAt: DateTime.now(),
            );
            await onComplete(updated);
            if (!controller.isClosed) {
              controller.add(updated);
              controller.close();
            }
            _cleanupDownloadStream(key);
          } else if (event is TransferFailed) {
            final errorTask = task.copyWith(
              state: FileTaskState.error,
              errorMessage: event.error.toString(),
            );
            onError(errorTask, event.error);
            if (!controller.isClosed) {
              controller.addError(
                FileDownloadException('Download failed: ${event.error}'),
              );
              controller.close();
            }
            _cleanupDownloadStream(key);
          }
        },
        onError: (error) {
          final errorTask = task.copyWith(
            state: FileTaskState.error,
            errorMessage: error.toString(),
          );
          onError(errorTask, error);
          if (!controller.isClosed) {
            controller.addError(
              FileDownloadException('Download failed: $error'),
            );
            controller.close();
          }
          _cleanupDownloadStream(key);
        },
      );

  // Emit running state immediately
  final runningTask = task.copyWith(state: FileTaskState.running);
  if (!controller.isClosed) controller.add(runningTask);
  return controller.stream;
}

Stream<FileTask> _getSharedUploadStream({
  required String key,
  required FileTask task,
  required TransferDriver driver,
  required void Function(FileTask) onUpdate,
  required Future<void> Function(FileTask, String?) onComplete,
  required void Function(FileTask, Object) onError,
}) {
  if (_uploadStreamCache.containsKey(key) &&
      !_uploadStreamCache[key]!.isClosed) {
    _uploadStreamRefCount[key] = (_uploadStreamRefCount[key] ?? 0) + 1;
    return _uploadStreamCache[key]!.stream;
  }

  final controller = StreamController<FileTask>.broadcast(
    onCancel: () => _handleUploadStreamCancel(key),
  );
  _uploadStreamCache[key] = controller;
  _uploadStreamRefCount[key] = 1;

  final request = UploadRequest(
    taskId: task.id,
    localPath: task.filePath,
    destinationPath: task.destinationPath,
  );

  _uploadSubscriptions[key] = driver
      .upload(request)
      .listen(
        (event) async {
          if (event is TransferProgressUpdate) {
            final updated = task.copyWith(
              state: FileTaskState.running,
              progress: FileProgress(
                bytesTransferred: event.bytesTransferred,
                totalBytes: event.totalBytes,
              ),
              lastUpdatedAt: DateTime.now(),
            );
            onUpdate(updated);
            if (!controller.isClosed) controller.add(updated);
          } else if (event is TransferCompleted) {
            final updated = task.copyWith(
              state: FileTaskState.completed,
              downloadUrl: event.remoteIdentifier ?? task.downloadUrl,
              progress: FileProgress(bytesTransferred: 1, totalBytes: 1),
              lastUpdatedAt: DateTime.now(),
            );
            await onComplete(updated, event.remoteIdentifier);
            if (!controller.isClosed) {
              controller.add(updated);
              controller.close();
            }
            _cleanupUploadStream(key);
          } else if (event is TransferFailed) {
            final errorTask = task.copyWith(
              state: FileTaskState.error,
              errorMessage: event.error.toString(),
            );
            onError(errorTask, event.error);
            if (!controller.isClosed) {
              controller.addError(
                FileUploadException('Upload failed: ${event.error}'),
              );
              controller.close();
            }
            _cleanupUploadStream(key);
          }
        },
        onError: (error) {
          final errorTask = task.copyWith(
            state: FileTaskState.error,
            errorMessage: error.toString(),
          );
          onError(errorTask, error);
          if (!controller.isClosed) {
            controller.addError(FileUploadException('Upload failed: $error'));
            controller.close();
          }
          _cleanupUploadStream(key);
        },
      );

  final runningTask = task.copyWith(state: FileTaskState.running);
  if (!controller.isClosed) controller.add(runningTask);
  return controller.stream;
}

/// A singleton repository for managing file upload and download tasks.
class FileTaskRepository extends GetStorageRepository<FileTask> {
  static final FileTaskRepository instance = FileTaskRepository._internal();

  FileTaskRepository._internal() : super('file_task_storage2', {});

  factory FileTaskRepository() => instance;

  @override
  @protected
  String inputConverter(Set<FileTask> val) =>
      json.encode(val.map((value) => value.toMap()).toList());

  @override
  @protected
  Set<FileTask> outputConverter(String? value) =>
      value?.toListMap().map((value) => FileTask.fromMap(value)).toSet() ??
      <FileTask>{};

  // MARK: - Remove Operations

  int removeById(String id, {bool notify = true}) {
    final item = firstWhereOrNull((task) => task.id == id);
    if (item != null) return remove(item, notify: notify);
    return 0;
  }

  int removeByGroupId(String groupId, {bool notify = true}) {
    final items = value.where((task) => task.groupId == groupId).toSet();
    if (items.isNotEmpty) return removeAll(items, notify: notify);
    return 0;
  }

  int removeAllByIds(Iterable<String> ids, {bool notify = true}) {
    final items = value.where((task) => ids.contains(task.id)).toSet();
    if (items.isNotEmpty) return removeAll(items, notify: notify);
    return 0;
  }

  int removeAllByGroupIds(Iterable<String> groupIds, {bool notify = true}) {
    final items = value
        .where((task) => groupIds.contains(task.groupId))
        .toSet();
    if (items.isNotEmpty) return removeAll(items, notify: notify);
    return 0;
  }

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
      final items = value.where((task) {
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

  Stream<Set<FileTask>> streamTasksBy({
    String? groupId,
    FileTaskType? type,
    Set<FileTaskState>? states,
  }) {
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

  Stream<FileTask?> getTaskStreamById(String taskId) =>
      streamFirstWhereOrNull((task) => task.id == taskId);

  Stream<FileTask?> getTaskStreamByFilePath(String filePath) =>
      streamFirstWhereOrNull((task) => task.filePath == filePath);

  Stream<FileTask?> getTaskStreamByDestinationPath(String destinationPath) =>
      streamFirstWhereOrNull((task) => task.destinationPath == destinationPath);

  Stream<FileTask?> getDownloadTaskStreamByUrl(String downloadUrl) =>
      streamFirstWhereOrNull(
        (task) =>
            task.type == FileTaskType.download &&
            task.downloadUrl == downloadUrl,
      );

  Stream<FileTask?> getUploadTaskStreamByFilePath(String filePath) =>
      streamFirstWhereOrNull(
        (task) => task.type == FileTaskType.upload && task.filePath == filePath,
      );

  // MARK: - Query Operations

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

  FileTask? getTaskById(String id) => getTaskBy(id: id);

  FileTask? getTaskByUrl(String url, {FileTaskType? type, String? groupId}) =>
      getTaskBy(url: url, type: type, groupId: groupId);

  FileTask? getTaskByFilePath(
    String filePath, {
    FileTaskType? type,
    String? groupId,
  }) => getTaskBy(filePath: filePath, type: type, groupId: groupId);

  FileTask? getTaskByDestinationPath(
    String destinationPath, {
    FileTaskType? type,
    String? groupId,
  }) =>
      getTaskBy(destinationPath: destinationPath, type: type, groupId: groupId);

  Set<FileTask> getTasksBy({
    String? groupId,
    FileTaskType? type,
    Set<FileTaskState>? states,
  }) {
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

  Set<FileTask> getUploadTasks() => getTasksBy(type: FileTaskType.upload);

  Set<FileTask> getDownloadTasks() => getTasksBy(type: FileTaskType.download);

  Set<FileTask> getActiveTasks() =>
      getTasksBy(states: {FileTaskState.running, FileTaskState.waiting});

  Set<FileTask> getCompletedTasks() =>
      getTasksBy(states: {FileTaskState.completed});

  Set<FileTask> getWaitingTasks() =>
      getTasksBy(states: {FileTaskState.waiting});

  Set<FileTask> getTasksByGroupId(String groupId) =>
      getTasksBy(groupId: groupId);

  Set<FileTask> getUploadTasksByGroupId(String groupId) =>
      getTasksBy(groupId: groupId, type: FileTaskType.upload);

  Set<FileTask> getDownloadTasksByGroupId(String groupId) =>
      getTasksBy(groupId: groupId, type: FileTaskType.download);

  FileTask? getTaskByPath(String path) => getTaskBy(filePath: path);

  FileTask? getTaskByDownloadUrl(String downloadUrl) =>
      getTaskBy(url: downloadUrl);

  FileTask? getUploadTaskByFilePath(String filePath) =>
      getTaskBy(filePath: filePath, type: FileTaskType.upload);

  FileTask? getDownloadTaskByUrl(String url) =>
      getTaskBy(url: url, type: FileTaskType.download);

  FileTask? getTaskByUploadedUrl(String url) => getTaskBy(url: url);

  Map<String, Set<FileTask>> getAllGroups() =>
      value.groupSetsBy((task) => task.groupId ?? '');

  // MARK: - Task Control Operations

  Future<bool> startTask(String taskId) async {
    final task = getTaskById(taskId);
    if (task != null && (task.isWaiting || task.isPaused)) {
      addOrUpdate(task.copyWith(state: FileTaskState.running));
      return true;
    }
    return false;
  }

  /// Pauses a running task.
  ///
  /// Throws [UnsupportedCapabilityException] synchronously if the driver does
  /// not support pause.
  Future<bool> pauseTask(String taskId) async {
    final driver = TransferKitConfig.instance.driver;
    if (!driver.capabilities.supportsPause) {
      throw const UnsupportedCapabilityException(
        'The active driver does not support pause.',
        capability: 'supportsPause',
      );
    }
    final task = getTaskById(taskId);
    if (task != null && task.isRunning) {
      await driver.pause(taskId);
      addOrUpdate(task.copyWith(state: FileTaskState.paused));
      return true;
    }
    return false;
  }

  /// Resumes a paused task.
  ///
  /// Throws [UnsupportedCapabilityException] synchronously if the driver does
  /// not support resume.
  Future<bool> resumeTask(String taskId) async {
    final driver = TransferKitConfig.instance.driver;
    if (!driver.capabilities.supportsResume) {
      throw const UnsupportedCapabilityException(
        'The active driver does not support resume.',
        capability: 'supportsResume',
      );
    }
    final task = getTaskById(taskId);
    if (task != null && task.isPaused) {
      await driver.resume(taskId);
      addOrUpdate(task.copyWith(state: FileTaskState.running));
      return true;
    }
    return false;
  }

  /// Cancels an active task.
  ///
  /// Throws [UnsupportedCapabilityException] synchronously if the driver does
  /// not support cancel.
  Future<bool> cancelTask(String taskId) async {
    final driver = TransferKitConfig.instance.driver;
    if (!driver.capabilities.supportsCancel) {
      throw const UnsupportedCapabilityException(
        'The active driver does not support cancel.',
        capability: 'supportsCancel',
      );
    }
    final task = getTaskById(taskId);
    if (task != null && !task.isComplete && !task.isCancelled) {
      await driver.cancel(taskId);
      addOrUpdate(task.copyWith(state: FileTaskState.cancelled));
      return true;
    }
    return false;
  }

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

  Future<void> startAllWaitingTasks() async {
    for (var task in getWaitingTasks()) {
      await startTask(task.id);
    }
  }

  Future<void> pauseAllRunningTasks() async {
    for (var task in getTasksBy(states: {FileTaskState.running})) {
      await pauseTask(task.id);
    }
  }

  Future<void> cancelAllActiveTasks() async {
    for (var task in getActiveTasks()) {
      await cancelTask(task.id);
    }
  }

  Future<void> removeTask(String taskId) async => removeById(taskId);

  int clearCompletedTasks() => removeBy(states: {FileTaskState.completed});

  Future<void> pauseTasksByGroupId(String groupId) async {
    for (var task
        in value.where((t) => t.groupId == groupId && t.isRunning).toList()) {
      await pauseTask(task.id);
    }
  }

  Future<void> resumeTasksByGroupId(String groupId) async {
    for (var task
        in value
            .where((t) => t.groupId == groupId && (t.isPaused || t.isWaiting))
            .toList()) {
      await startTask(task.id);
    }
  }

  Future<void> cancelTasksByGroupId(String groupId) async {
    for (var task
        in value
            .where(
              (t) => t.groupId == groupId && !t.isComplete && !t.isCancelled,
            )
            .toList()) {
      await cancelTask(task.id);
    }
  }

  // MARK: - Task Creation

  /// Creates a new upload task.
  ///
  /// Throws [UnsupportedCapabilityException] synchronously if the driver does
  /// not support upload.
  Future<FileTask> createUploadTask({
    required String taskId,
    required String filePath,
    required String destinationPath,
    required FileGroupInfo group,
    bool autoStart = true,
  }) async {
    final driver = TransferKitConfig.instance.driver;
    if (!driver.capabilities.supportsUpload) {
      throw const UnsupportedCapabilityException(
        'The active driver does not support upload.',
        capability: 'supportsUpload',
      );
    }

    final existingTask = getUploadTaskByFilePath(filePath);
    if (existingTask != null) return existingTask;

    final filePathAndUrl = await FilePathAndURLRepository.instance
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
      final newTask = FileTask.upload(
        id: taskId,
        filePath: filePathAndUrl.path,
        destinationPath: filePathAndUrl.destinationPath!,
        downloadUrl: filePathAndUrl.url,
        state: filePathAndUrl.url != null
            ? FileTaskState.cached
            : (autoStart ? FileTaskState.running : FileTaskState.waiting),
        group: group,
        progress: FileProgress(
          bytesTransferred: filePathAndUrl.url != null ? fileSize : 0,
          totalBytes: fileSize,
        ),
      );
      addOrUpdate(newTask);
      return newTask;
    }
  }

  /// Creates a new download task.
  ///
  /// Throws [UnsupportedCapabilityException] synchronously if the driver does
  /// not support download.
  Future<FileTask> createDownloadTask({
    required String taskId,
    required String url,
    required FileGroupInfo group,
    bool autoStart = true,
    String? cacheKey,
    bool forceRefresh = false,
  }) async {
    final driver = TransferKitConfig.instance.driver;
    if (!driver.capabilities.supportsDownload) {
      throw const UnsupportedCapabilityException(
        'The active driver does not support download.',
        capability: 'supportsDownload',
      );
    }

    if (forceRefresh) {
      final existing =
          (cacheKey != null
              ? FilePathAndURLRepository.instance.getByKey(cacheKey)
              : null) ??
          FilePathAndURLRepository.instance.getByUrl(url);
      if (existing != null) {
        final file = File(existing.path);
        if (await file.exists()) await file.delete();
        FilePathAndURLRepository.instance.remove(existing);
      }
    } else {
      final existingTask = getDownloadTaskByUrl(url);
      if (existingTask != null) return existingTask;

      final filePathAndUrl = await FilePathAndURLRepository.instance
          .getCachedDownloadFilePathAndURL(url: url, cacheKey: cacheKey);

      if (filePathAndUrl != null) {
        final file = File(filePathAndUrl.path);
        final fileSize = file.lengthSync();
        final newTask = FileTask.download(
          id: taskId,
          downloadUrl: filePathAndUrl.url!,
          group: group,
          state: FileTaskState.cached,
          cachedMetadata: filePathAndUrl.metadata,
          progress: FileProgress(
            bytesTransferred: fileSize,
            totalBytes: fileSize,
          ),
        );
        addOrUpdate(newTask);
        return newTask;
      }

      final existingByUrl = getTaskByUrl(url);
      if (existingByUrl != null) return existingByUrl;
    }

    final newTask = FileTask.download(
      id: taskId,
      downloadUrl: url,
      state: autoStart ? FileTaskState.running : FileTaskState.waiting,
      group: group,
      progress: FileProgress(bytesTransferred: 0, totalBytes: 0),
    );
    addOrUpdate(newTask);
    return newTask;
  }

  // MARK: - Streaming

  /// Creates a stream emitting download progress for [task].
  ///
  /// Uses the shared stream pattern — multiple callers for the same URL share
  /// one underlying driver subscription.
  Stream<FileTask> downloadTaskStream({
    required FileTask task,
    StreamController<FileTask>? controller,
  }) {
    if (task.isComplete) {
      final sc = controller ?? StreamController<FileTask>();
      sc.add(task);
      sc.close();
      return sc.stream;
    }

    final driver = TransferKitConfig.instance.driver;
    final key = task.downloadUrl!;

    return _getSharedDownloadStream(
      key: key,
      task: task,
      driver: driver,
      onUpdate: addOrUpdate,
      onComplete: (updatedTask) async {
        final existingEntry = FilePathAndURLRepository.instance.getByUrl(
          updatedTask.downloadUrl ?? '',
        );
        var fpau = updatedTask.filePathAndURL;
        final extracted = await MetadataExtractionService().extractMetadata(
          File(updatedTask.filePath),
          existingMetadata: existingEntry?.metadata ?? fpau.metadata,
        );
        fpau = fpau.copyWithMergedMetadata(extracted);
        final now = DateTime.now();
        fpau = fpau.copyWith(
          createdAt: existingEntry == null ? now : existingEntry.createdAt,
          updatedAt: now,
        );
        FilePathAndURLRepository.instance.addOrUpdate(fpau);
        addOrUpdate(updatedTask);
      },
      onError: (errorTask, error) {
        addOrUpdate(errorTask);
        Logger().e('Download failed: ${error.runtimeType}');
      },
    );
  }

  /// Creates a stream emitting upload progress for [task].
  Stream<FileTask> uploadTaskStream({
    required FileTask task,
    StreamController<FileTask>? controller,
  }) {
    if (task.isComplete) {
      final sc = controller ?? StreamController<FileTask>();
      sc.add(task);
      sc.close();
      return sc.stream;
    }

    final driver = TransferKitConfig.instance.driver;
    final key = task.filePath;

    return _getSharedUploadStream(
      key: key,
      task: task,
      driver: driver,
      onUpdate: addOrUpdate,
      onComplete: (updatedTask, remoteIdentifier) async {
        var fpau = updatedTask.filePathAndURL;
        final extracted = await MetadataExtractionService().extractMetadata(
          File(updatedTask.filePath),
          existingMetadata: fpau.metadata,
        );
        fpau = fpau.copyWithMergedMetadata(extracted);
        FilePathAndURLRepository.instance.addOrUpdate(fpau);
        addOrUpdate(updatedTask);
      },
      onError: (errorTask, error) {
        addOrUpdate(errorTask);
        Logger().e('Upload failed: ${error.runtimeType}');
      },
    );
  }

  /// Downloads multiple files in parallel with combined progress.
  Stream<MultiDownloadFileTask> downloadTasksParallelStream({
    required Set<FilePathAndURL> filePathsAndUrls,
    required FileGroupInfo group,
    bool autoStart = true,
    StreamController<MultiDownloadFileTask>? controller,
  }) {
    assert(
      filePathsAndUrls.isNotEmpty,
      'File paths and urls must not be empty',
    );
    final newController =
        controller ?? StreamController<MultiDownloadFileTask>();

    _downloadFilesParallelWithProgress(
      filePathsAndUrls: filePathsAndUrls,
      controller: newController,
      autoStart: autoStart,
      group: group,
    ).catchError((error) {
      newController.addError(
        FileDownloadException('Failed to download files in parallel: $error'),
      );
      newController.close();
    });

    return newController.stream;
  }

  Future<void> _downloadFilesParallelWithProgress({
    required Set<FilePathAndURL> filePathsAndUrls,
    required StreamController<MultiDownloadFileTask> controller,
    required FileGroupInfo group,
    bool autoStart = true,
  }) async {
    try {
      final List<FileTask> tasks = [];
      final fileList = filePathsAndUrls.toList();

      for (int i = 0; i < fileList.length; i++) {
        tasks.add(
          await createDownloadTask(
            taskId: '${group.id}_$i',
            url: fileList[i].url!,
            group: group,
            autoStart: autoStart,
          ),
        );
      }

      controller.add(
        MultiDownloadFileTask.fromTasks(tasks: tasks, taskId: group.id),
      );

      int completedCount = tasks.where((t) => t.isComplete).length;

      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];
        if (task.isComplete) continue;

        downloadTaskStream(task: task).listen((updatedTask) {
          tasks[i] = updatedTask;
          if (!controller.isClosed) {
            controller.add(
              MultiDownloadFileTask.fromTasks(tasks: tasks, taskId: group.id),
            );
          }
          if (updatedTask.isComplete) {
            completedCount++;
            if (completedCount >= tasks.length && !controller.isClosed) {
              controller.close();
            }
          }
        });
      }

      if (!controller.isClosed) {
        controller.add(
          MultiDownloadFileTask.fromTasks(tasks: tasks, taskId: group.id),
        );
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(
          FileDownloadException('Failed to download files in parallel: $e'),
        );
        controller.close();
      }
    }
  }

  /// Uploads multiple files in parallel with combined progress.
  Stream<MultiUploadFileTask> uploadTasksParallelStream({
    required Set<FilePathAndURL> filePathsAndUrls,
    required FileGroupInfo group,
    bool autoStart = true,
    StreamController<MultiUploadFileTask>? controller,
  }) {
    assert(
      filePathsAndUrls.isNotEmpty,
      'File paths and urls must not be empty',
    );
    final newController = controller ?? StreamController<MultiUploadFileTask>();

    _uploadTasksParallelStream(
      filePathsAndUrls: filePathsAndUrls,
      controller: newController,
      autoStart: autoStart,
      group: group,
    ).catchError((error) {
      newController.addError(
        FileUploadException('Failed to upload files in parallel: $error'),
      );
      newController.close();
    });

    return newController.stream;
  }

  Future<void> _uploadTasksParallelStream({
    required Set<FilePathAndURL> filePathsAndUrls,
    required StreamController<MultiUploadFileTask> controller,
    required FileGroupInfo group,
    bool autoStart = true,
  }) async {
    try {
      final List<FileTask> tasks = [];
      final fileList = filePathsAndUrls.toList();

      for (int i = 0; i < fileList.length; i++) {
        tasks.add(
          await createUploadTask(
            taskId: '${group.id}_$i',
            filePath: fileList[i].path,
            destinationPath: fileList[i].destinationPath!,
            group: group,
            autoStart: autoStart,
          ),
        );
      }

      controller.add(
        MultiUploadFileTask.fromTasks(tasks: tasks, taskId: group.id),
      );

      int completedCount = tasks.where((t) => t.isComplete).length;

      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];
        if (task.isComplete) continue;

        uploadTaskStream(task: task).listen((updatedTask) {
          tasks[i] = updatedTask;
          if (!controller.isClosed) {
            controller.add(
              MultiUploadFileTask.fromTasks(tasks: tasks, taskId: group.id),
            );
          }
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
          FileUploadException('Failed to upload files in parallel: $e'),
        );
        controller.close();
      }
    }
  }
}
