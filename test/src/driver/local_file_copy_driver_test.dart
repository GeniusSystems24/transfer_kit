import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transfer_kit/src/core/driver/transfer_driver.dart';
import 'package:transfer_kit/src/drivers/local_file_copy_driver.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('local_copy_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('LocalFileCopyDriver capabilities', () {
    test('declares upload, download, cancel, progress; not pause/resume', () {
      final driver = LocalFileCopyDriver();
      expect(driver.capabilities.supportsUpload, isTrue);
      expect(driver.capabilities.supportsDownload, isTrue);
      expect(driver.capabilities.supportsCancel, isTrue);
      expect(driver.capabilities.supportsProgress, isTrue);
      expect(driver.capabilities.supportsPause, isFalse);
      expect(driver.capabilities.supportsResume, isFalse);
    });
  });

  group('LocalFileCopyDriver.download', () {
    test(
      'emits progress updates and TransferCompleted; dest file matches source',
      () async {
        final source = File('${tempDir.path}/source.bin');
        final content = List.generate(300, (i) => i % 256);
        await source.writeAsBytes(content);

        final destPath = '${tempDir.path}/dest.bin';
        final driver = LocalFileCopyDriver();

        final events = await driver
            .download(
              DownloadRequest(
                taskId: 'local_dl_01',
                source: source.uri,
                localPath: destPath,
              ),
            )
            .toList();

        expect(events.whereType<TransferProgressUpdate>(), isNotEmpty);
        expect(events.last, isA<TransferCompleted>());

        final completed = events.last as TransferCompleted;
        expect(completed.localPath, destPath);

        final destBytes = await File(destPath).readAsBytes();
        expect(destBytes, content);
      },
    );

    test('emits TransferFailed when source does not exist', () async {
      final driver = LocalFileCopyDriver();

      final events = await driver
          .download(
            DownloadRequest(
              taskId: 'local_dl_missing',
              source: Uri.file('${tempDir.path}/no_such_file.bin'),
              localPath: '${tempDir.path}/out.bin',
            ),
          )
          .toList();

      expect(events.last, isA<TransferFailed>());
    });

    test('cancel mid-copy terminates stream with TransferFailed', () async {
      // Create a large-enough file so cancel can fire mid-stream
      final source = File('${tempDir.path}/large.bin');
      await source.writeAsBytes(List.generate(1024 * 1024, (i) => i % 256));

      final destPath = '${tempDir.path}/large_dest.bin';
      final driver = LocalFileCopyDriver();

      final events = <TransferProgressEvent>[];
      final stream = driver.download(
        DownloadRequest(
          taskId: 'local_dl_cancel',
          source: source.uri,
          localPath: destPath,
        ),
      );

      await for (final event in stream) {
        events.add(event);
        // Cancel after first progress event
        if (event is TransferProgressUpdate) {
          await driver.cancel('local_dl_cancel');
        }
        if (event is TransferCompleted || event is TransferFailed) break;
      }

      expect(events.last, isA<TransferFailed>());
    });
  });

  group('LocalFileCopyDriver.upload', () {
    test(
      'emits progress updates and TransferCompleted; dest matches source',
      () async {
        final source = File('${tempDir.path}/upload_src.bin');
        final content = List.generate(256, (i) => i % 256);
        await source.writeAsBytes(content);

        final destPath = '${tempDir.path}/upload_dest.bin';
        final driver = LocalFileCopyDriver();

        final events = await driver
            .upload(
              UploadRequest(
                taskId: 'local_ul_01',
                localPath: source.path,
                destinationPath: destPath,
              ),
            )
            .toList();

        expect(events.whereType<TransferProgressUpdate>(), isNotEmpty);
        expect(events.last, isA<TransferCompleted>());

        final destBytes = await File(destPath).readAsBytes();
        expect(destBytes, content);
      },
    );

    test('emits TransferFailed when destinationPath is null', () async {
      final driver = LocalFileCopyDriver();

      final events = await driver
          .upload(
            const UploadRequest(
              taskId: 'local_ul_no_dest',
              localPath: '/tmp/file.bin',
            ),
          )
          .toList();

      expect(events.last, isA<TransferFailed>());
    });
  });

  group('LocalFileCopyDriver unsupported operations', () {
    test('pause throws UnsupportedCapabilityException', () {
      final driver = LocalFileCopyDriver();
      expect(
        () => driver.pause('t1'),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
    });

    test('resume throws UnsupportedCapabilityException', () {
      final driver = LocalFileCopyDriver();
      expect(
        () => driver.resume('t1'),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
    });
  });
}
