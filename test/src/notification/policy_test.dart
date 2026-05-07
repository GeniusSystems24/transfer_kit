import 'package:flutter_test/flutter_test.dart';
import 'package:transfer_kit/src/model/file_task.dart';
import 'package:transfer_kit/src/notification/config/transfer_notification_config.dart';
import 'package:transfer_kit/src/notification/model/notification_event_kind.dart';
import 'package:transfer_kit/src/notification/model/transfer_type.dart';
import 'package:transfer_kit/src/notification/policy/transfer_notification_policy.dart';

void main() {
  group('TransferNotificationPolicy — global enabled gate (US1)', () {
    test('enabled=false returns false unconditionally (FR-015)', () {
      final policy = TransferNotificationPolicy(
        TransferNotificationConfig(
          enabled: false,
          uploadEnabled: true,
          downloadEnabled: true,
          showProgress: true,
          showCompletion: true,
          showErrors: true,
          showCancelled: true,
          showPaused: true,
          showRetry: true,
        ),
      );

      for (final type in TransferType.values) {
        for (final state in FileTaskState.values) {
          for (final kind in NotificationEventKind.values) {
            expect(
              policy.shouldNotify(transferType: type, state: state, kind: kind),
              isFalse,
              reason:
                  '$type/$state/$kind should be silenced when enabled=false',
            );
          }
        }
      }
    });
  });

  group('TransferNotificationPolicy — per-type gate (US2)', () {
    test('uploadEnabled=false suppresses upload completion', () {
      final policy = TransferNotificationPolicy(
        TransferNotificationConfig(
          enabled: true,
          uploadEnabled: false,
          downloadEnabled: true,
        ),
      );
      expect(
        policy.shouldNotify(
          transferType: TransferType.upload,
          state: FileTaskState.completed,
          kind: NotificationEventKind.terminal,
        ),
        isFalse,
      );
      expect(
        policy.shouldNotify(
          transferType: TransferType.download,
          state: FileTaskState.completed,
          kind: NotificationEventKind.terminal,
        ),
        isTrue,
      );
    });

    test('downloadEnabled=false suppresses download error', () {
      final policy = TransferNotificationPolicy(
        TransferNotificationConfig(
          enabled: true,
          uploadEnabled: true,
          downloadEnabled: false,
        ),
      );
      expect(
        policy.shouldNotify(
          transferType: TransferType.download,
          state: FileTaskState.error,
          kind: NotificationEventKind.terminal,
        ),
        isFalse,
      );
      expect(
        policy.shouldNotify(
          transferType: TransferType.upload,
          state: FileTaskState.error,
          kind: NotificationEventKind.terminal,
        ),
        isTrue,
      );
    });

    test('both per-type disabled with enabled=true → all false', () {
      final policy = TransferNotificationPolicy(
        TransferNotificationConfig(
          enabled: true,
          uploadEnabled: false,
          downloadEnabled: false,
        ),
      );
      for (final type in TransferType.values) {
        expect(
          policy.shouldNotify(
            transferType: type,
            state: FileTaskState.running,
            kind: NotificationEventKind.progress,
          ),
          isFalse,
        );
      }
    });
  });

  group('TransferNotificationPolicy — per-state gate (US3)', () {
    test('progress suppressed but completion shown', () {
      final policy = TransferNotificationPolicy(
        TransferNotificationConfig(
          enabled: true,
          showProgress: false,
          showCompletion: true,
        ),
      );
      expect(
        policy.shouldNotify(
          transferType: TransferType.upload,
          state: FileTaskState.running,
          kind: NotificationEventKind.progress,
        ),
        isFalse,
      );
      expect(
        policy.shouldNotify(
          transferType: TransferType.upload,
          state: FileTaskState.completed,
          kind: NotificationEventKind.terminal,
        ),
        isTrue,
      );
    });

    test('showCancelled false (default) hides cancellation', () {
      final defaultPolicy = TransferNotificationPolicy(
        TransferNotificationConfig(enabled: true),
      );
      expect(
        defaultPolicy.shouldNotify(
          transferType: TransferType.download,
          state: FileTaskState.cancelled,
          kind: NotificationEventKind.terminal,
        ),
        isFalse,
      );

      final loudPolicy = TransferNotificationPolicy(
        TransferNotificationConfig(enabled: true, showCancelled: true),
      );
      expect(
        loudPolicy.shouldNotify(
          transferType: TransferType.download,
          state: FileTaskState.cancelled,
          kind: NotificationEventKind.terminal,
        ),
        isTrue,
      );
    });

    test('waiting never notifies regardless of flags', () {
      final policy = TransferNotificationPolicy(
        TransferNotificationConfig(
          enabled: true,
          showProgress: true,
          showCompletion: true,
          showErrors: true,
          showPaused: true,
          showRetry: true,
        ),
      );
      for (final kind in NotificationEventKind.values) {
        expect(
          policy.shouldNotify(
            transferType: TransferType.upload,
            state: FileTaskState.waiting,
            kind: kind,
          ),
          isFalse,
        );
      }
    });

    test('cached never notifies in v1 regardless of flags', () {
      final policy = TransferNotificationPolicy(
        TransferNotificationConfig(enabled: true, showCompletion: true),
      );
      expect(
        policy.shouldNotify(
          transferType: TransferType.download,
          state: FileTaskState.cached,
          kind: NotificationEventKind.terminal,
        ),
        isFalse,
      );
    });

    test('paused state honors showPaused flag', () {
      final off = TransferNotificationPolicy(
        TransferNotificationConfig(enabled: true, showPaused: false),
      );
      expect(
        off.shouldNotify(
          transferType: TransferType.upload,
          state: FileTaskState.paused,
          kind: NotificationEventKind.progress,
        ),
        isFalse,
      );

      final on = TransferNotificationPolicy(
        TransferNotificationConfig(enabled: true, showPaused: true),
      );
      expect(
        on.shouldNotify(
          transferType: TransferType.upload,
          state: FileTaskState.paused,
          kind: NotificationEventKind.progress,
        ),
        isTrue,
      );
    });
  });
}
