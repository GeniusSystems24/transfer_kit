import 'package:flutter_test/flutter_test.dart';
import 'package:transfer_kit/src/model/file_task.dart';
import 'package:transfer_kit/src/notification/model/notification_event_kind.dart';
import 'package:transfer_kit/src/notification/model/notification_permission_status.dart';
import 'package:transfer_kit/src/notification/model/transfer_notification_payload.dart';
import 'package:transfer_kit/src/notification/model/transfer_type.dart';

import 'fake_notification_adapter.dart';

TransferNotificationPayload _payload(String taskId) =>
    TransferNotificationPayload(
      taskId: taskId,
      transferType: TransferType.upload,
      state: FileTaskState.running,
      eventKind: NotificationEventKind.progress,
      progress: 0.5,
      title: 'T',
      body: 'B',
      notificationId: 12345,
      timestamp: DateTime.now(),
    );

void main() {
  test('recordedCalls starts empty', () {
    final fake = FakeNotificationAdapter();
    expect(fake.recordedCalls, isEmpty);
  });

  test('clear() resets recorded calls', () async {
    final fake = FakeNotificationAdapter();
    await fake.showOrUpdateProgress(_payload('a'));
    expect(fake.recordedCalls.length, 1);
    fake.clear();
    expect(fake.recordedCalls, isEmpty);
  });

  test(
    'every method records a call with correct method name and payload',
    () async {
      final fake = FakeNotificationAdapter();
      final p = _payload('x');

      await fake.showOrUpdateProgress(p);
      await fake.showCompletion(p);
      await fake.showError(p);
      await fake.cancel('x');
      await fake.cancelGroup('g1');
      await fake.checkPermission();
      await fake.requestPermission();
      await fake.dispose();

      final names = fake.recordedCalls.map((c) => c.method).toList();
      expect(
        names,
        containsAllInOrder([
          'showOrUpdateProgress',
          'showCompletion',
          'showError',
          'cancel',
          'cancelGroup',
          'checkPermission',
          'requestPermission',
          'dispose',
        ]),
      );

      expect(fake.callsTo('showOrUpdateProgress').single.payload!.taskId, 'x');
      expect(fake.callsTo('cancel').single.taskOrGroupId, 'x');
      expect(fake.callsTo('cancelGroup').single.taskOrGroupId, 'g1');
    },
  );

  test(
    'permissionStatus default is granted; setting denies returns denied',
    () async {
      final fake = FakeNotificationAdapter();
      expect(
        await fake.checkPermission(),
        NotificationPermissionStatus.granted,
      );
      fake.permissionStatus = NotificationPermissionStatus.denied;
      expect(await fake.checkPermission(), NotificationPermissionStatus.denied);
    },
  );

  test('throwOnEveryCall propagates the supplied error from non-recording '
      'methods', () async {
    final fake = FakeNotificationAdapter()
      ..throwOnEveryCall = StateError('boom');
    expect(
      () => fake.showOrUpdateProgress(_payload('a')),
      throwsA(isA<StateError>()),
    );
  });
}
