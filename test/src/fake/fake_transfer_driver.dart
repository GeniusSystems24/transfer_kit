import 'dart:async';

import 'package:transfer_kit/src/core/driver/transfer_driver.dart';

/// A configurable fake [TransferDriver] for offline tests.
///
/// Emits [progressSteps] progress events then [TransferCompleted] (or
/// [TransferFailed] when [shouldFail] is `true`). Tracks call counts for
/// test assertions.
class FakeTransferDriver implements TransferDriver {
  FakeTransferDriver({
    this.shouldFail = false,
    bool supportsPause = true,
    this.progressSteps = 3,
    this.delay = Duration.zero,
  }) : _capabilities = TransferCapabilities(
          supportsDownload: true,
          supportsUpload: true,
          supportsPause: supportsPause,
          supportsResume: supportsPause,
          supportsCancel: true,
          supportsProgress: true,
        );

  final bool shouldFail;
  final int progressSteps;
  final Duration delay;
  final TransferCapabilities _capabilities;

  int downloadCallCount = 0;
  int uploadCallCount = 0;
  int cancelCallCount = 0;

  @override
  TransferCapabilities get capabilities => _capabilities;

  @override
  Stream<TransferProgressEvent> download(DownloadRequest request) async* {
    downloadCallCount++;
    yield* _runTransfer(request.taskId, isUpload: false, localPath: request.localPath ?? '/fake/${request.taskId}');
  }

  @override
  Stream<TransferProgressEvent> upload(UploadRequest request) async* {
    uploadCallCount++;
    yield* _runTransfer(request.taskId, isUpload: true);
  }

  Stream<TransferProgressEvent> _runTransfer(
    String taskId, {
    required bool isUpload,
    String? localPath,
  }) async* {
    if (delay != Duration.zero) await Future<void>.delayed(delay);

    final total = progressSteps * 100;
    for (var i = 1; i <= progressSteps; i++) {
      if (delay != Duration.zero) await Future<void>.delayed(delay);
      yield TransferProgressUpdate(
        taskId: taskId,
        bytesTransferred: i * 100,
        totalBytes: total,
      );
    }

    if (shouldFail) {
      yield TransferFailed(
        taskId: taskId,
        error: Exception('FakeTransferDriver: simulated failure'),
      );
    } else {
      yield TransferCompleted(
        taskId: taskId,
        localPath: isUpload ? null : localPath,
        remoteIdentifier: isUpload ? 'fake://remote/$taskId' : null,
      );
    }
  }

  @override
  Future<void> pause(String taskId) async {
    if (!capabilities.supportsPause) {
      throw UnsupportedCapabilityException(
        'This driver does not support pause.',
        capability: 'supportsPause',
      );
    }
  }

  @override
  Future<void> resume(String taskId) async {
    if (!capabilities.supportsResume) {
      throw UnsupportedCapabilityException(
        'This driver does not support resume.',
        capability: 'supportsResume',
      );
    }
  }

  @override
  Future<void> cancel(String taskId) async {
    cancelCallCount++;
  }
}
