import 'package:flutter_test/flutter_test.dart';
import 'package:transfer_kit/src/core/driver/transfer_driver.dart';

import '../fake/fake_transfer_driver.dart';

void main() {
  group('FakeTransferDriver lifecycle', () {
    test('download emits running progress then completed', () async {
      final driver = FakeTransferDriver(progressSteps: 3);

      final events = await driver
          .download(
            DownloadRequest(
              taskId: 'test_lifecycle_01',
              source: Uri.parse('fake://file.txt'),
            ),
          )
          .toList();

      expect(events.whereType<TransferProgressUpdate>().length, 3);
      expect(events.last, isA<TransferCompleted>());
      final completed = events.last as TransferCompleted;
      expect(completed.localPath, isNotNull);
    });

    test('download emits TransferFailed when shouldFail is true', () async {
      final driver = FakeTransferDriver(shouldFail: true, progressSteps: 2);

      final events = await driver
          .download(
            DownloadRequest(
              taskId: 'test_lifecycle_02',
              source: Uri.parse('fake://file.txt'),
            ),
          )
          .toList();

      expect(events.whereType<TransferProgressUpdate>().length, 2);
      expect(events.last, isA<TransferFailed>());
    });

    test('upload emits running progress then completed', () async {
      final driver = FakeTransferDriver(progressSteps: 2);

      final events = await driver
          .upload(
            const UploadRequest(
              taskId: 'test_lifecycle_03',
              localPath: '/tmp/file.txt',
              destinationPath: 'remote/file.txt',
            ),
          )
          .toList();

      expect(events.whereType<TransferProgressUpdate>().length, 2);
      expect(events.last, isA<TransferCompleted>());
      final completed = events.last as TransferCompleted;
      expect(completed.remoteIdentifier, contains('test_lifecycle_03'));
    });

    test('upload emits TransferFailed when shouldFail is true', () async {
      final driver = FakeTransferDriver(shouldFail: true);

      final events = await driver
          .upload(
            const UploadRequest(
              taskId: 'test_lifecycle_04',
              localPath: '/tmp/file.txt',
              destinationPath: 'remote/file.txt',
            ),
          )
          .toList();

      expect(events.last, isA<TransferFailed>());
    });

    test('driver tracks download and upload call counts', () async {
      final driver = FakeTransferDriver();

      await driver
          .download(
            DownloadRequest(
              taskId: 'count_dl',
              source: Uri.parse('fake://a.txt'),
            ),
          )
          .drain<void>();

      await driver
          .upload(
            const UploadRequest(taskId: 'count_ul', localPath: '/tmp/a.txt'),
          )
          .drain<void>();

      expect(driver.downloadCallCount, 1);
      expect(driver.uploadCallCount, 1);
    });

    test('cancel increments cancelCallCount', () async {
      final driver = FakeTransferDriver();
      await driver.cancel('any_task');
      expect(driver.cancelCallCount, 1);
    });

    test('pause succeeds when supportsPause is true', () async {
      final driver = FakeTransferDriver(supportsPause: true);
      await expectLater(driver.pause('t1'), completes);
    });

    test('TransferProgressUpdate percentage computes correctly', () {
      const update = TransferProgressUpdate(
        taskId: 'pct',
        bytesTransferred: 50,
        totalBytes: 100,
      );
      expect(update.percentage, 0.5);
    });

    test('TransferProgressUpdate percentage is 0.0 when totalBytes is 0', () {
      const update = TransferProgressUpdate(
        taskId: 'pct_zero',
        bytesTransferred: 0,
        totalBytes: 0,
      );
      expect(update.percentage, 0.0);
    });
  });
}
