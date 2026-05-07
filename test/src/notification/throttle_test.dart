import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transfer_kit/src/model/file_task.dart';
import 'package:transfer_kit/src/notification/config/transfer_notification_config.dart';
import 'package:transfer_kit/src/notification/coordinator/transfer_notification_coordinator.dart';

import 'fake/fake_notification_adapter.dart';

FileTask _uploadAt(String id, int bytes, FileTaskState state) {
  return FileTask.upload(
    id: id,
    filePath: 'photo_$id.jpg',
    destinationPath: 'remote/$id.jpg',
    group: FileGroupInfo(id: 'g_$id'),
    state: state,
    progress: FileProgress(bytesTransferred: bytes, totalBytes: 100),
  );
}

void main() {
  group('Throttle (US4)', () {
    test('first event fires immediately and uses stable notificationId', () {
      fakeAsync((async) {
        final fake = FakeNotificationAdapter();
        final ctrl = StreamController<Set<FileTask>>.broadcast();
        final coord = TransferNotificationCoordinator(
          config: TransferNotificationConfig(
            enabled: true,
            throttleDuration: const Duration(seconds: 2),
          ),
          adapter: fake,
          taskStream: ctrl.stream,
        );
        coord.start();

        ctrl.add({_uploadAt('a', 10, FileTaskState.running)});
        async.flushMicrotasks();

        final calls = fake.callsTo('showOrUpdateProgress').toList();
        expect(calls.length, 1);
        final firstId = calls.first.payload!.notificationId;
        expect(firstId, equals(notificationIdFor('a')));

        // Second event within window — buffered, not fired immediately.
        ctrl.add({_uploadAt('a', 20, FileTaskState.running)});
        async.flushMicrotasks();
        expect(fake.callsTo('showOrUpdateProgress').length, 1);

        // Advance past throttle window — trailing fires.
        async.elapse(const Duration(seconds: 2));
        expect(fake.callsTo('showOrUpdateProgress').length, 2);
        // All calls share the same notification ID.
        for (final c in fake.callsTo('showOrUpdateProgress')) {
          expect(c.payload!.notificationId, equals(firstId));
        }
      });
    });

    test(
      'throttle window: 10 progress events in 10s with 2s window → ≤ 5 fires',
      () {
        fakeAsync((async) {
          final fake = FakeNotificationAdapter();
          final ctrl = StreamController<Set<FileTask>>.broadcast();
          final coord = TransferNotificationCoordinator(
            config: TransferNotificationConfig(
              enabled: true,
              throttleDuration: const Duration(seconds: 2),
            ),
            adapter: fake,
            taskStream: ctrl.stream,
          );
          coord.start();

          // 10 events at 1s spacing.
          for (int i = 0; i < 10; i++) {
            ctrl.add({_uploadAt('b', i * 10, FileTaskState.running)});
            async.elapse(const Duration(seconds: 1));
          }

          final fires = fake.callsTo('showOrUpdateProgress').length;
          expect(
            fires,
            lessThanOrEqualTo(6),
            reason: 'should have at most 5-6 fires across 10s with 2s window',
          );
        });
      },
    );

    test('trailing edge: last payload emitted at end of quiet window', () {
      fakeAsync((async) {
        final fake = FakeNotificationAdapter();
        final ctrl = StreamController<Set<FileTask>>.broadcast();
        final coord = TransferNotificationCoordinator(
          config: TransferNotificationConfig(
            enabled: true,
            throttleDuration: const Duration(seconds: 2),
          ),
          adapter: fake,
          taskStream: ctrl.stream,
        );
        coord.start();

        ctrl.add({_uploadAt('c', 10, FileTaskState.running)});
        async.flushMicrotasks();
        // Within window, push two updates with the latest being 90 bytes.
        async.elapse(const Duration(milliseconds: 200));
        ctrl.add({_uploadAt('c', 50, FileTaskState.running)});
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 100));
        ctrl.add({_uploadAt('c', 90, FileTaskState.running)});
        async.flushMicrotasks();

        // Wait out the trailing window.
        async.elapse(const Duration(seconds: 5));
        final calls = fake.callsTo('showOrUpdateProgress').toList();
        // Should have exactly two fires: the immediate first, then the
        // trailing for the last (90) payload.
        expect(calls.length, 2);
        expect(calls.last.payload!.bytesTransferred, equals(90));
      });
    });

    test('terminal bypass: completion fires immediately, cancels trailing', () {
      fakeAsync((async) {
        final fake = FakeNotificationAdapter();
        final ctrl = StreamController<Set<FileTask>>.broadcast();
        final coord = TransferNotificationCoordinator(
          config: TransferNotificationConfig(
            enabled: true,
            throttleDuration: const Duration(seconds: 5),
          ),
          adapter: fake,
          taskStream: ctrl.stream,
        );
        coord.start();

        ctrl.add({_uploadAt('d', 10, FileTaskState.running)});
        async.flushMicrotasks();
        // Within window, queue a trailing.
        ctrl.add({_uploadAt('d', 50, FileTaskState.running)});
        async.flushMicrotasks();
        // Completion fires immediately and must cancel the pending trailing.
        ctrl.add({_uploadAt('d', 100, FileTaskState.completed)});
        async.flushMicrotasks();

        expect(fake.callsTo('showCompletion').length, 1);
        // Wait beyond throttle window — the trailing must NOT fire because
        // the subscription was retired on completion.
        async.elapse(const Duration(seconds: 10));
        expect(fake.callsTo('showOrUpdateProgress').length, 1);
      });
    });

    test('dedup: same task ID always uses the same notification id', () {
      fakeAsync((async) {
        final fake = FakeNotificationAdapter();
        final ctrl = StreamController<Set<FileTask>>.broadcast();
        final coord = TransferNotificationCoordinator(
          config: TransferNotificationConfig(
            enabled: true,
            throttleDuration: const Duration(milliseconds: 100),
          ),
          adapter: fake,
          taskStream: ctrl.stream,
        );
        coord.start();

        for (int i = 0; i < 10; i++) {
          ctrl.add({_uploadAt('z', i * 10, FileTaskState.running)});
          async.elapse(const Duration(milliseconds: 200));
        }

        final ids = fake
            .callsTo('showOrUpdateProgress')
            .map((c) => c.payload!.notificationId)
            .toSet();
        expect(ids.length, 1);
      });
    });
  });
}
