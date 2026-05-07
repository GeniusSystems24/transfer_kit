import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/driver/transfer_driver.dart';

/// A [TransferDriver] that downloads files over HTTP/HTTPS.
///
/// Authentication headers and other static headers can be supplied at
/// construction time:
///
/// ```dart
/// TransferKitConfig.init(
///   driver: HttpDownloadDriver(
///     headers: {'Authorization': 'Bearer $token'},
///   ),
/// );
/// ```
///
/// **Supported capabilities**: download, cancel, progress.
/// Upload, pause, and resume are not supported.
class HttpDownloadDriver implements TransferDriver {
  HttpDownloadDriver({Map<String, String> headers = const {}})
      : _headers = Map.unmodifiable(headers);

  final Map<String, String> _headers;
  final Map<String, http.Client> _activeClients = {};

  static const TransferCapabilities _capabilities = TransferCapabilities(
    supportsDownload: true,
    supportsCancel: true,
    supportsProgress: true,
  );

  @override
  TransferCapabilities get capabilities => _capabilities;

  @override
  Stream<TransferProgressEvent> download(DownloadRequest request) async* {
    if (!capabilities.supportsDownload) {
      throw UnsupportedCapabilityException(
        'HttpDownloadDriver does not support download.',
        capability: 'supportsDownload',
      );
    }

    final client = http.Client();
    _activeClients[request.taskId] = client;

    final localPath =
        request.localPath ?? _tempPathFor(request.taskId);
    final tempPath = '$localPath.tmp';

    try {
      final httpRequest = http.Request('GET', request.source);
      httpRequest.headers.addAll(_headers);
      final response = await client.send(httpRequest);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        yield TransferFailed(
          taskId: request.taskId,
          error: HttpException(
            'HTTP ${response.statusCode}',
            uri: request.source,
          ),
        );
        return;
      }

      final totalBytes = response.contentLength ?? 0;
      int bytesTransferred = 0;

      final sink = File(tempPath).openWrite();
      try {
        await for (final chunk in response.stream) {
          if (!_activeClients.containsKey(request.taskId)) {
            // Task was cancelled — _activeClients entry removed by cancel()
            yield TransferFailed(
              taskId: request.taskId,
              error: const HttpException('Download cancelled'),
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

      // Rename temp file to final path
      await File(tempPath).rename(localPath);

      yield TransferCompleted(
        taskId: request.taskId,
        localPath: localPath,
      );
    } catch (e, st) {
      // Clean up temp file on error
      final tmp = File(tempPath);
      if (await tmp.exists()) await tmp.delete();

      yield TransferFailed(
        taskId: request.taskId,
        error: e,
        stackTrace: st,
      );
    } finally {
      _activeClients.remove(request.taskId);
    }
  }

  @override
  Stream<TransferProgressEvent> upload(UploadRequest request) {
    throw UnsupportedCapabilityException(
      'HttpDownloadDriver does not support upload.',
      capability: 'supportsUpload',
    );
  }

  @override
  Future<void> pause(String taskId) async {
    throw UnsupportedCapabilityException(
      'HttpDownloadDriver does not support pause.',
      capability: 'supportsPause',
    );
  }

  @override
  Future<void> resume(String taskId) async {
    throw UnsupportedCapabilityException(
      'HttpDownloadDriver does not support resume.',
      capability: 'supportsResume',
    );
  }

  /// Cancels the active download for [taskId].
  ///
  /// Closes the HTTP client, which causes the stream to terminate.
  /// No-op if [taskId] is not currently active.
  @override
  Future<void> cancel(String taskId) async {
    final client = _activeClients.remove(taskId);
    client?.close();
  }

  String _tempPathFor(String taskId) =>
      '${Directory.systemTemp.path}/${taskId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.download';
}
