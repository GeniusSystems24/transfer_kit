import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:transfer_kit/src/core/driver/transfer_driver.dart';
import 'package:transfer_kit/src/drivers/http_download_driver.dart';

void main() {
  group('HttpDownloadDriver capabilities', () {
    test(
      'declares download, cancel, and progress; not upload/pause/resume',
      () {
        final driver = HttpDownloadDriver();
        expect(driver.capabilities.supportsDownload, isTrue);
        expect(driver.capabilities.supportsCancel, isTrue);
        expect(driver.capabilities.supportsProgress, isTrue);
        expect(driver.capabilities.supportsUpload, isFalse);
        expect(driver.capabilities.supportsPause, isFalse);
        expect(driver.capabilities.supportsResume, isFalse);
      },
    );
  });

  group('HttpDownloadDriver.download', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('http_driver_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('emits progress updates then TransferCompleted on 200', () async {
      final body = List.generate(512, (i) => i % 256);
      final mockClient = MockClient(
        (_) async => http.Response.bytes(
          body,
          200,
          headers: {'content-length': '${body.length}'},
        ),
      );

      final driver = HttpDownloadDriver(clientFactory: () => mockClient);
      final destPath = '${tempDir.path}/output.bin';

      final events = await driver
          .download(
            DownloadRequest(
              taskId: 'http_200',
              source: Uri.parse('https://example.com/file.bin'),
              localPath: destPath,
            ),
          )
          .toList();

      expect(events.whereType<TransferProgressUpdate>(), isNotEmpty);
      expect(events.last, isA<TransferCompleted>());
      final completed = events.last as TransferCompleted;
      expect(completed.localPath, destPath);
      expect(File(destPath).existsSync(), isTrue);
    });

    test('emits TransferFailed on non-2xx response', () async {
      final mockClient = MockClient(
        (_) async => http.Response('Not Found', 404),
      );
      final driver = HttpDownloadDriver(clientFactory: () => mockClient);

      final events = await driver
          .download(
            DownloadRequest(
              taskId: 'http_404',
              source: Uri.parse('https://example.com/missing.bin'),
              localPath: '${tempDir.path}/missing.bin',
            ),
          )
          .toList();

      expect(events.last, isA<TransferFailed>());
    });

    test(
      'cancel on active task terminates stream with TransferFailed',
      () async {
        final completer = Completer<void>();
        final mockClient = MockClient((_) async {
          await completer.future; // block until cancelled
          return http.Response('', 200);
        });

        final driver = HttpDownloadDriver(clientFactory: () => mockClient);

        final streamFuture = driver
            .download(
              DownloadRequest(
                taskId: 'http_cancel',
                source: Uri.parse('https://example.com/large.bin'),
                localPath: '${tempDir.path}/large.bin',
              ),
            )
            .toList();

        // Cancel shortly after starting
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await driver.cancel('http_cancel');
        completer.complete();

        final events = await streamFuture;
        expect(events.last, isA<TransferFailed>());
      },
    );
  });

  group('HttpDownloadDriver unsupported operations', () {
    test('upload throws UnsupportedCapabilityException', () {
      final driver = HttpDownloadDriver();
      expect(
        () => driver.upload(
          const UploadRequest(taskId: 'ul', localPath: '/tmp/file'),
        ),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
    });

    test('pause throws UnsupportedCapabilityException', () {
      final driver = HttpDownloadDriver();
      expect(
        () => driver.pause('t1'),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
    });

    test('resume throws UnsupportedCapabilityException', () {
      final driver = HttpDownloadDriver();
      expect(
        () => driver.resume('t1'),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
    });

    test('cancel on non-active task is a no-op', () async {
      final driver = HttpDownloadDriver();
      await expectLater(driver.cancel('not_active'), completes);
    });
  });
}
