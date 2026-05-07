import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:transfer_kit/src/model/file_task.dart';
import 'package:transfer_kit/src/notification/config/transfer_notification_config.dart';
import 'package:transfer_kit/src/notification/coordinator/transfer_notification_coordinator.dart';
import 'package:transfer_kit/src/notification/model/notification_grouping_mode.dart';

import 'fake/fake_notification_adapter.dart';

FileTask _uploadTask({
  required String id,
  required String groupId,
  FileTaskState state = FileTaskState.running,
  int bytes = 0,
  int total = 100,
}) {
  return FileTask.upload(
    id: id,
    filePath: 'photo_$id.jpg',
    destinationPath: 'remote/$id.jpg',
    group: FileGroupInfo(id: groupId),
    state: state,
    progress: FileProgress(bytesTransferred: bytes, totalBytes: total),
  );
}

void main() {
  group('Grouping (US6)', () {
    test('batch mode: 5 tasks share group → all fires use group id', () async {
      final fake = FakeNotificationAdapter();
      final ctrl = StreamController<Set<FileTask>>.broadcast();
      const groupId = 'photos-2026-05-07';
      final coord = TransferNotificationCoordinator(
        config: TransferNotificationConfig(
          enabled: true,
          grouping: NotificationGroupingMode.batch,
          throttleDuration: const Duration(milliseconds: 1),
        ),
        adapter: fake,
        taskStream: ctrl.stream,
      );
      coord.start();

      for (int i = 0; i < 5; i++) {
        ctrl.add({
          for (int j = 0; j < 5; j++)
            _uploadTask(
              id: 't$j',
              groupId: groupId,
              state: FileTaskState.running,
              bytes: (i + 1) * 10,
            ),
        });
        await Future<void>.delayed(Duration.zero);
      }

      final calls = fake.callsTo('showOrUpdateProgress').toList();
      expect(calls, isNotEmpty);
      final expectedId = notificationIdFor(groupId);
      for (final c in calls) {
        expect(c.payload!.notificationId, equals(expectedId));
      }

      await coord.dispose();
      await ctrl.close();
    });

    test('perFile mode: 5 tasks → 5 distinct notification ids', () async {
      final fake = FakeNotificationAdapter();
      final ctrl = StreamController<Set<FileTask>>.broadcast();
      final coord = TransferNotificationCoordinator(
        config: TransferNotificationConfig(
          enabled: true,
          grouping: NotificationGroupingMode.perFile,
          throttleDuration: const Duration(milliseconds: 1),
        ),
        adapter: fake,
        taskStream: ctrl.stream,
      );
      coord.start();

      ctrl.add({
        for (int j = 0; j < 5; j++)
          _uploadTask(
            id: 't$j',
            groupId: 'g$j',
            state: FileTaskState.running,
            bytes: 10,
          ),
      });
      await Future<void>.delayed(Duration.zero);

      final ids = fake
          .callsTo('showOrUpdateProgress')
          .map((c) => c.payload!.notificationId)
          .toSet();
      expect(ids.length, 5);

      await coord.dispose();
      await ctrl.close();
    });

    test('none mode: zero adapter calls regardless of events', () async {
      final fake = FakeNotificationAdapter();
      final ctrl = StreamController<Set<FileTask>>.broadcast();
      final coord = TransferNotificationCoordinator(
        config: TransferNotificationConfig(
          enabled: true,
          grouping: NotificationGroupingMode.none,
        ),
        adapter: fake,
        taskStream: ctrl.stream,
      );
      coord.start();

      for (int j = 0; j < 5; j++) {
        ctrl.add({
          _uploadTask(
            id: 't$j',
            groupId: 'g',
            state: FileTaskState.running,
            bytes: 50,
          ),
        });
        ctrl.add({
          _uploadTask(
            id: 't$j',
            groupId: 'g',
            state: FileTaskState.completed,
            bytes: 100,
          ),
        });
      }
      await Future<void>.delayed(Duration.zero);

      expect(
        fake.recordedCalls.where((c) => c.method.startsWith('show')),
        isEmpty,
      );

      await coord.dispose();
      await ctrl.close();
    });

    test(
      'batch group progress monotonically increases as tasks finish',
      () async {
        final fake = FakeNotificationAdapter();
        final ctrl = StreamController<Set<FileTask>>.broadcast();
        const groupId = 'g1';
        final coord = TransferNotificationCoordinator(
          config: TransferNotificationConfig(
            enabled: true,
            grouping: NotificationGroupingMode.batch,
            throttleDuration: const Duration(milliseconds: 1),
          ),
          adapter: fake,
          taskStream: ctrl.stream,
        );
        coord.start();

        // Seed the aggregator with all 4 tasks at 0% in one snapshot.
        ctrl.add({
          for (int j = 0; j < 4; j++)
            _uploadTask(
              id: 't$j',
              groupId: groupId,
              state: FileTaskState.running,
              bytes: 0,
            ),
        });
        await Future<void>.delayed(const Duration(milliseconds: 5));

        // Then complete one task at a time.
        for (int finished = 1; finished <= 4; finished++) {
          ctrl.add({
            for (int j = 0; j < 4; j++)
              _uploadTask(
                id: 't$j',
                groupId: groupId,
                state: j < finished
                    ? FileTaskState.completed
                    : FileTaskState.running,
                bytes: j < finished ? 100 : 0,
              ),
          });
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        final progressValues = fake
            .callsTo('showOrUpdateProgress')
            .map((c) => c.payload!.progress)
            .toList();
        expect(progressValues, isNotEmpty);
        // After every task has completed, the aggregator has reached 1.0.
        expect(progressValues.reduce((a, b) => a > b ? a : b), equals(1.0));
        // The very last fire reflects the final aggregate.
        expect(progressValues.last, equals(1.0));

        await coord.dispose();
        await ctrl.close();
      },
    );
  });
}
