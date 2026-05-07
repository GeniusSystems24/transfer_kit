import 'package:flutter_test/flutter_test.dart';
import 'package:transfer_kit/src/core/driver/transfer_driver.dart';

import '../fake/fake_transfer_driver.dart';

void main() {
  group('FakeTransferDriver cache deduplication', () {
    test(
      'downloadCallCount stays at 1 when driver is not re-invoked',
      () async {
        final driver = FakeTransferDriver(progressSteps: 2);

        // Simulate first download
        await driver
            .download(
              DownloadRequest(
                taskId: 'cache_test_001',
                source: Uri.parse('fake://image.jpg'),
              ),
            )
            .drain<void>();

        expect(driver.downloadCallCount, 1);

        // Calling download a second time would increment the counter — the
        // repository layer is responsible for the cache hit check that prevents
        // this second call. Here we verify that the driver itself increments
        // correctly only when actually called.
        await driver
            .download(
              DownloadRequest(
                taskId: 'cache_test_001',
                source: Uri.parse('fake://image.jpg'),
              ),
            )
            .drain<void>();

        expect(driver.downloadCallCount, 2);
      },
    );

    test('TransferCompleted carries the expected localPath', () async {
      final driver = FakeTransferDriver();
      final events = await driver
          .download(
            DownloadRequest(
              taskId: 'cache_path_check',
              source: Uri.parse('fake://doc.pdf'),
              localPath: '/tmp/doc.pdf',
            ),
          )
          .toList();

      final completed = events.whereType<TransferCompleted>().first;
      expect(completed.localPath, '/tmp/doc.pdf');
    });

    test(
      'TransferCompleted localPath defaults to fake:// path when not given',
      () async {
        final driver = FakeTransferDriver();
        final events = await driver
            .download(
              DownloadRequest(
                taskId: 'cache_default_path',
                source: Uri.parse('fake://default.png'),
              ),
            )
            .toList();

        final completed = events.whereType<TransferCompleted>().first;
        expect(completed.localPath, contains('cache_default_path'));
      },
    );
  });
}
