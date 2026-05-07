import 'dart:io';

import '../core/driver/transfer_driver.dart';

/// A [TransferDriver] that copies files between local paths.
///
/// Useful for testing and for scenarios where a file needs to be moved
/// within the device's storage. This driver serves as the canonical
/// reference implementation for custom driver authors.
///
/// ```dart
/// TransferKitConfig.init(driver: LocalFileCopyDriver());
/// ```
///
/// **Supported capabilities**: upload, download, cancel, progress.
/// Pause and resume are not supported.
class LocalFileCopyDriver implements TransferDriver {
  LocalFileCopyDriver();

  final Map<String, bool> _cancelFlags = {};

  static const TransferCapabilities _capabilities = TransferCapabilities(
    supportsUpload: true,
    supportsDownload: true,
    supportsCancel: true,
    supportsProgress: true,
  );

  @override
  TransferCapabilities get capabilities => _capabilities;

  @override
  Stream<TransferProgressEvent> download(DownloadRequest request) async* {
    final sourcePath = request.source.toFilePath();
    final destPath = request.localPath ?? _tempPathFor(request.taskId);

    _cancelFlags.remove(request.taskId);

    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        yield TransferFailed(
          taskId: request.taskId,
          error: FileSystemException('Source file not found', sourcePath),
        );
        return;
      }

      final totalBytes = await sourceFile.length();
      int bytesTransferred = 0;

      await File(destPath).parent.create(recursive: true);
      final sink = File(destPath).openWrite();
      try {
        final source = sourceFile.openRead();
        await for (final chunk in source) {
          if (_cancelFlags[request.taskId] == true) {
            yield TransferFailed(
              taskId: request.taskId,
              error: const FileSystemException('Download cancelled'),
            );
            return;
          }

          sink.add(chunk);
          bytesTransferred += chunk.length;
          yield TransferProgressUpdate(
            taskId: request.taskId,
            bytesTransferred: bytesTransferred,
            totalBytes: totalBytes,
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (_cancelFlags[request.taskId] == true) {
        final dest = File(destPath);
        if (await dest.exists()) await dest.delete();
        yield TransferFailed(
          taskId: request.taskId,
          error: const FileSystemException('Download cancelled'),
        );
        return;
      }

      yield TransferCompleted(taskId: request.taskId, localPath: destPath);
    } catch (e, st) {
      final dest = File(destPath);
      if (await dest.exists()) await dest.delete();
      yield TransferFailed(taskId: request.taskId, error: e, stackTrace: st);
    } finally {
      _cancelFlags.remove(request.taskId);
    }
  }

  @override
  Stream<TransferProgressEvent> upload(UploadRequest request) async* {
    final destPath = request.destinationPath;
    if (destPath == null) {
      yield TransferFailed(
        taskId: request.taskId,
        error: ArgumentError('destinationPath is required for upload'),
      );
      return;
    }

    _cancelFlags.remove(request.taskId);

    try {
      final sourceFile = File(request.localPath);
      if (!await sourceFile.exists()) {
        yield TransferFailed(
          taskId: request.taskId,
          error: FileSystemException(
            'Source file not found',
            request.localPath,
          ),
        );
        return;
      }

      final totalBytes = await sourceFile.length();
      int bytesTransferred = 0;

      await File(destPath).parent.create(recursive: true);
      final sink = File(destPath).openWrite();
      try {
        final source = sourceFile.openRead();
        await for (final chunk in source) {
          if (_cancelFlags[request.taskId] == true) {
            yield TransferFailed(
              taskId: request.taskId,
              error: const FileSystemException('Upload cancelled'),
            );
            return;
          }

          sink.add(chunk);
          bytesTransferred += chunk.length;
          yield TransferProgressUpdate(
            taskId: request.taskId,
            bytesTransferred: bytesTransferred,
            totalBytes: totalBytes,
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (_cancelFlags[request.taskId] == true) {
        final dest = File(destPath);
        if (await dest.exists()) await dest.delete();
        yield TransferFailed(
          taskId: request.taskId,
          error: const FileSystemException('Upload cancelled'),
        );
        return;
      }

      yield TransferCompleted(
        taskId: request.taskId,
        remoteIdentifier: destPath,
      );
    } catch (e, st) {
      yield TransferFailed(taskId: request.taskId, error: e, stackTrace: st);
    } finally {
      _cancelFlags.remove(request.taskId);
    }
  }

  /// Sets the cancel flag for [taskId].
  ///
  /// The active download/upload loop detects this flag between chunks
  /// and terminates the stream with [TransferFailed].
  /// No-op if [taskId] is not active.
  @override
  Future<void> cancel(String taskId) async {
    _cancelFlags[taskId] = true;
  }

  @override
  Future<void> pause(String taskId) async {
    throw const UnsupportedCapabilityException(
      'LocalFileCopyDriver does not support pause.',
      capability: 'supportsPause',
    );
  }

  @override
  Future<void> resume(String taskId) async {
    throw const UnsupportedCapabilityException(
      'LocalFileCopyDriver does not support resume.',
      capability: 'supportsResume',
    );
  }

  String _tempPathFor(String taskId) =>
      '${Directory.systemTemp.path}/${taskId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.download';
}
