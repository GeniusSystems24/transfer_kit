import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/extension/file_path_extension.dart';
import '../core/extension/map_extension.dart';
import '../core/get_storage_repository.dart';
import '../repository/file_task_repository.dart';
import 'file_path_and_url.dart';
import 'media_metadata.dart';

class FileGroupInfo {
  final Map<String, dynamic> data;

  FileGroupInfo({
    required String id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalFiles,
    Map<String, dynamic>? extraData,
  }) : data = {
         idTag: id,
         nameTag: name,
         descriptionTag: description,
         createdAtTag: (createdAt ?? DateTime.now()).toIso8601String(),
         updatedAtTag: updatedAt?.toIso8601String(),
         if (extraData != null) ...extraData,
       };

  FileGroupInfo.fromMap(this.data);

  String get id => data.getString(idTag)!;
  static const String idTag = 'id';

  String? get name => data.getString(nameTag);
  static const String nameTag = 'name';

  String? get description => data.getString(descriptionTag);
  static const String descriptionTag = 'description';

  DateTime get createdAt => data.getDateTime(createdAtTag)!;
  static const String createdAtTag = 'createdAt';

  DateTime? get updatedAt => data.getDateTime(updatedAtTag);
  set updatedAt(DateTime? value) =>
      data[updatedAtTag] = value?.toIso8601String();
  static const String updatedAtTag = 'updatedAt';

  int get totalFiles => data.getInt(totalFilesTag) ?? 0;
  set totalFiles(int value) => data[totalFilesTag] = value;
  static const String totalFilesTag = 'totalFiles';

  Map<String, dynamic> toMap() => data;

  FileGroupInfo copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalFiles,
  }) => FileGroupInfo(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    totalFiles: totalFiles ?? this.totalFiles,
  );

  @override
  String toString() =>
      'FileGroupInfo(id: $id, name: $name, description: $description, createdAt: $createdAt, updatedAt: $updatedAt, totalFiles: $totalFiles)';

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) =>
      other is FileGroupInfo && hashCode == other.hashCode;
}

enum FileTaskState {
  waiting(Icons.hourglass_empty, Colors.grey),
  running(Icons.play_arrow, Colors.blue),
  paused(Icons.pause, Colors.amber),
  completed(Icons.check_circle, Colors.green),
  cached(Icons.cached, Colors.teal),
  cancelled(Icons.cancel, Colors.grey),
  error(Icons.error_outline, Colors.red);

  final IconData icon;
  final Color color;

  const FileTaskState(this.icon, this.color);

  FileProgress get defaultProgress => switch (this) {
    waiting => FileProgress(bytesTransferred: 0, totalBytes: 1),
    running => FileProgress(bytesTransferred: 0, totalBytes: 1),
    paused => FileProgress(bytesTransferred: 0, totalBytes: 1),
    completed => FileProgress(bytesTransferred: 1, totalBytes: 1),
    cached => FileProgress(bytesTransferred: 1, totalBytes: 1),
    cancelled => FileProgress(bytesTransferred: 0, totalBytes: 1),
    error => FileProgress(bytesTransferred: 0, totalBytes: 1),
  };
}

enum FileTaskType { upload, download }

class FileProgress {
  final Map<String, dynamic> data;

  int get bytesTransferred => data.getInt(bytesTransferredTag) ?? 0;
  set bytesTransferred(int value) => data[bytesTransferredTag] = value;
  static const String bytesTransferredTag = 'bytesTransferred';

  int get totalBytes => data.getInt(totalBytesTag) ?? 1;
  set totalBytes(int value) => data[totalBytesTag] = value;
  static const String totalBytesTag = 'totalBytes';

  FileProgress({int bytesTransferred = 0, int totalBytes = 0})
    : data = {bytesTransferredTag: bytesTransferred, totalBytesTag: totalBytes};
  FileProgress.fromMap(this.data);

  double get progressPercentage =>
      totalBytes > 0 ? (bytesTransferred / totalBytes) * 100 : 0;

  Map<String, dynamic> toMap() => data;

  FileProgress copyWith({int? bytesTransferred, int? totalBytes}) =>
      FileProgress(
        bytesTransferred: bytesTransferred ?? this.bytesTransferred,
        totalBytes: totalBytes ?? this.totalBytes,
      );

  @override
  String toString() =>
      'FileProgress(bytesTransferred: $bytesTransferred, totalBytes: $totalBytes, progressPercentage: $progressPercentage)';
}

class FileTask extends GetStorageMethods {
  final Map<String, dynamic> data;

  String get id => data.getString(idTag)!;
  static const String idTag = 'id';

  /// Get the file path of the task (for uploads this is the local file path)
  String get filePath => data.getString(filePathTag)!;
  set filePath(String value) {
    data[filePathTag] = value;
    _invalidateFilePathAndURLCache();
  }

  static const String filePathTag = 'filePath';

  String get tempFilePath => '$filePath.tmp';

  /// Get the download URL of the task
  String? get downloadUrl => data.getString(downloadUrlTag);
  set downloadUrl(String? value) {
    data[downloadUrlTag] = value;
    _invalidateFilePathAndURLCache();
  }

  static const String downloadUrlTag = 'downloadUrl';

  /// Get the destination path of firebase storage
  String? get destinationPath => data.getString(destinationPathTag);
  set destinationPath(String? value) {
    data[destinationPathTag] = value;
    _invalidateFilePathAndURLCache();
  }

  static const String destinationPathTag = 'destinationPath';

  FilePathAndURL? _filePathAndURL;

  /// Invalidates the cached FilePathAndURL when any related property changes
  void _invalidateFilePathAndURLCache() {
    _filePathAndURL = null;
  }

  FilePathAndURL get filePathAndURL {
    if (_filePathAndURL != null) return _filePathAndURL!;

    if (type == FileTaskType.upload) {
      return _filePathAndURL = FilePathAndURL.local(
        path: filePath,
        destinationPath: destinationPath!,
      ).copyWith(url: downloadUrl);
    } else {
      return _filePathAndURL = FilePathAndURL.url(
        url: downloadUrl!,
      ).copyWith(destinationPath: destinationPath);
    }
  }

  /// Get the file name of the task
  String get fileName => filePath.fileName;

  /// Get if the task is an upload or download
  FileTaskType get type => FileTaskType.values.byName(
    data.getString(typeTag) ?? FileTaskType.download.name,
  );
  set type(FileTaskType value) => data[typeTag] = value.name;
  static const String typeTag = 'type';

  /// Get if the task is running, paused, completed, cached, cancelled or in error
  FileTaskState get state => FileTaskState.values.byName(
    data.getString(stateTag) ?? FileTaskState.waiting.name,
  );
  set state(FileTaskState value) => data[stateTag] = value.name;
  static const String stateTag = 'state';

  /// Get the date and time when the task was created
  DateTime get createdAt => data.getDateTime(createdAtTag) ?? DateTime.now();
  set createdAt(DateTime value) => data[createdAtTag] = value.toIso8601String();
  static const String createdAtTag = 'createdAt';

  /// Get the date and time when the task was last updated
  DateTime? get lastUpdatedAt => data.getDateTime(lastUpdatedAtTag);
  set lastUpdatedAt(DateTime? value) =>
      data[lastUpdatedAtTag] = value?.toIso8601String();
  static const String lastUpdatedAtTag = 'lastUpdatedAt';

  /// Get the number of bytes transferred
  FileProgress get progress =>
      data[progressTag] != null
          ? FileProgress.fromMap(data.getMap(progressTag)!)
          : state.defaultProgress;
  set progress(FileProgress value) => data[progressTag] = value.toMap();
  static const String progressTag = 'progress';

  /// Get the number of bytes transferred
  int get bytesTransferred => progress.bytesTransferred;
  set bytesTransferred(int value) => progress.bytesTransferred = value;

  /// Get the total number of bytes to be transferred
  int get totalBytes => progress.totalBytes;
  set totalBytes(int value) => progress.totalBytes = value;

  /// Get the error message of the task
  String? get errorMessage => data.getString(errorMessageTag);
  set errorMessage(String? value) => data[errorMessageTag] = value;
  static const String errorMessageTag = 'errorMessage';

  /// Metadata extracted from the cached file at the time of cache hit.
  /// Non-null only when [state] == [FileTaskState.cached].
  MediaMetadata? get cachedMetadata {
    final map = data[cachedMetadataTag] as Map<String, dynamic>?;
    return map != null ? MediaMetadata.fromMap(map) : null;
  }

  set cachedMetadata(MediaMetadata? value) {
    if (value != null) {
      data[cachedMetadataTag] = value.toMap();
    } else {
      data.remove(cachedMetadataTag);
    }
  }

  static const String cachedMetadataTag = 'cachedMetadata';

  /// Get the group information of the task
  FileGroupInfo get group => FileGroupInfo.fromMap(data.getMap(groupTag)!);
  set group(FileGroupInfo value) => data[groupTag] = value.toMap();
  static const String groupTag = 'group';

  /// Get the group ID of the task
  String? get groupId => group.id;
  set groupId(String? value) => group = group.copyWith(id: value);
  static const String groupIdTag = 'groupId';

  /// Get the reference of the task
  Reference get reference {
    if (type == FileTaskType.upload) {
      return FirebaseStorage.instance.ref().child(destinationPath!);
    } else {
      return FirebaseStorage.instance.refFromURL(downloadUrl!);
    }
  }

  Task? task;

  /// Get the firebase task of the task
  Task? firebaseTask({bool justCheck = false}) {
    if (justCheck) return task;

    if (!{
      FileTaskState.waiting,
      FileTaskState.running,
      FileTaskState.paused,
    }.contains(state)) {
      return null;
    }

    if (task != null) return task;

    if (type == FileTaskType.upload) {
      return task = FirebaseStorageFactory.createUpload(
        filePath,
        destinationPath!,
        autoStart: state == FileTaskState.running,
      );
    } else {
      return task = FirebaseStorageFactory.createDownload(
        downloadUrl!,
        autoStart: state == FileTaskState.running,
      );
    }
  }

  FileTask({
    required String id,
    required String filePath,
    String? downloadUrl,
    String? destinationPath,
    required FileGroupInfo group,
    FileTaskType type = FileTaskType.download,
    FileTaskState state = FileTaskState.waiting,
    FileProgress? progress,
    String? errorMessage,
    Task? firebaseTask,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
  }) : task = firebaseTask,
       data = {
         idTag: id,
         filePathTag: filePath,
         downloadUrlTag: downloadUrl,
         destinationPathTag: destinationPath,
         typeTag: type.name,
         stateTag: state.name,
         createdAtTag: (createdAt ?? DateTime.now()).toIso8601String(),
         lastUpdatedAtTag: lastUpdatedAt?.toIso8601String(),
         progressTag: progress?.toMap(),
         errorMessageTag: errorMessage,
         groupTag: group.toMap(),
       };

  /// Create a new download task
  FileTask.download({
    required String id,
    required String downloadUrl,
    required FileGroupInfo group,
    FileTaskState state = FileTaskState.waiting,
    FileProgress? progress,
    String? errorMessage,
    Task? firebaseTask,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    MediaMetadata? cachedMetadata,
  }) : task = firebaseTask,
       data = {
         idTag: id,
         filePathTag: downloadUrl.toHashName().toCachedPath(),
         downloadUrlTag: downloadUrl,
         destinationPathTag:
             FirebaseStorage.instance.refFromURL(downloadUrl).fullPath,
         typeTag: FileTaskType.download.name,
         stateTag: state.name,
         createdAtTag: (createdAt ?? DateTime.now()).toIso8601String(),
         lastUpdatedAtTag: lastUpdatedAt?.toIso8601String(),
         progressTag: progress?.toMap(),
         errorMessageTag: errorMessage,
         groupTag: group.toMap(),
         if (cachedMetadata != null) cachedMetadataTag: cachedMetadata.toMap(),
       };

  /// Create a new upload task
  FileTask.upload({
    required String id,
    required String filePath,
    required FileGroupInfo group,
    required String destinationPath,
    String? downloadUrl,
    FileTaskState state = FileTaskState.waiting,
    FileProgress? progress,
    String? errorMessage,
    UploadTask? firebaseTask,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
  }) : task = firebaseTask,
       data = {
         idTag: id,
         filePathTag: filePath,
         downloadUrlTag: downloadUrl,
         destinationPathTag: destinationPath,
         typeTag: FileTaskType.upload.name,
         stateTag: state.name,
         createdAtTag: (createdAt ?? DateTime.now()).toIso8601String(),
         lastUpdatedAtTag: lastUpdatedAt?.toIso8601String(),
         progressTag: progress?.toMap(),
         errorMessageTag: errorMessage,
         groupTag: group.toMap(),
       };

  /// Create a new task from another task
  FileTask.fromTask({required FileTask task})
    : this(
        id: task.id,
        filePath: task.filePath,
        downloadUrl: task.downloadUrl,
        createdAt: task.createdAt,
        group: task.group,
        destinationPath: task.destinationPath,
        type: task.type,
        state: task.state,
        lastUpdatedAt: task.lastUpdatedAt,
        progress: task.progress,
        errorMessage: task.errorMessage,
        firebaseTask: task.firebaseTask(justCheck: true),
      );

  /// Create from JSON for persistence
  FileTask.fromMap(this.data);

  /// Get if the file task is ready to be uploaded or downloaded
  bool get isReady =>
      type == FileTaskType.upload ||
      progress.totalBytes == progress.bytesTransferred;

  /// Get the local path for the file
  /// For upload tasks, this is filePath
  /// For download tasks, this is filePath if available
  String get localPath => filePath;

  /// Get the remote URL for the file
  /// For upload tasks, this is downloadUrl if available
  /// For download tasks, this is downloadUrl
  String? get url => downloadUrl;

  /// Get the progress percentage of the task
  double get progressPercentage =>
      totalBytes > 0 ? (bytesTransferred / totalBytes) * 100 : 0;

  /// Get the completion status of the task
  bool get isComplete =>
      {FileTaskState.completed, FileTaskState.cached}.contains(state);

  /// Get the running status of the task
  bool get isRunning => state == FileTaskState.running;

  Stream<FileTask> get run async* {
    state = FileTaskState.running;
    if (this.task == null) bytesTransferred = 0;

    final task = this.task!;
    await for (var snapshot in task.snapshotEvents) {
      if (snapshot.state != TaskState.running) {
        state = switch (snapshot.state) {
          TaskState.paused => FileTaskState.paused,
          TaskState.canceled => FileTaskState.cancelled,
          TaskState.error => FileTaskState.error,
          TaskState.success => FileTaskState.completed,
          _ => state,
        };
      }

      bytesTransferred = snapshot.bytesTransferred;
      totalBytes = snapshot.totalBytes;
      yield this;
      if (state != FileTaskState.completed) break;
    }
  }

  /// Get the paused status of the task
  bool get isPaused => state == FileTaskState.paused;

  /// Get the waiting status of the task
  bool get isWaiting => state == FileTaskState.waiting;

  /// Get the cancelled status of the task
  bool get isCancelled => state == FileTaskState.cancelled;

  /// Get the error status of the task
  bool get isError => state == FileTaskState.error;

  /// Get the cached status of the task
  bool get isCached => state == FileTaskState.cached;

  // Convert to JSON for persistence
  Map<String, dynamic> toMap() => data;

  // Create a copy with updated properties
  FileTask copyWith({
    String? id,
    String? filePath,
    String? destinationPath,
    FileTaskType? type,
    FileTaskState? state,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    FileProgress? progress,
    String? errorMessage,
    String? downloadUrl,
    FileGroupInfo? group,
    Task? firebaseTask,
    MediaMetadata? cachedMetadata,
  }) {
    final copy = FileTask(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      destinationPath: destinationPath ?? this.destinationPath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      type: type ?? this.type,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      firebaseTask: firebaseTask ?? this.firebaseTask(justCheck: true),
      group: group ?? this.group,
    );
    copy.cachedMetadata = cachedMetadata ?? this.cachedMetadata;
    return copy;
  }

  FileTask copy() {
    final newTask = FileTask.fromMap(data);
    newTask.task = task;
    newTask._filePathAndURL = _filePathAndURL;
    return newTask;
  }

  @override
  String toString() =>
      'FileTask(id: $id, filePath: $filePath, downloadUrl: $downloadUrl, type: $type, state: $state, progress: $progress, errorMessage: $errorMessage, group: $group)';

  @override
  int get hashCode => type.name.hashCode ^ filePath.hashCode;

  @override
  bool operator ==(Object other) =>
      other is FileTask && hashCode == other.hashCode;

  /// if there are changes in the data.
  ///
  /// Returns true if path is the same and data is different, otherwise false.
  /// that is means that data has been changed.
  @override
  bool operator ^(covariant FileTask other) {
    if (other.hashCode != hashCode) return false;

    if (identical(this, other)) return false;

    final thisData = Map<String, dynamic>.from(data);
    final otherData = Map<String, dynamic>.from(other.data);

    /// compare the data
    return !mapEquals(thisData, otherData);
  }

  @override
  void update(Object item) {
    if (item is! FileTask) return;
    data.updateAll((key, value) => item.data[key]);
  }
}
