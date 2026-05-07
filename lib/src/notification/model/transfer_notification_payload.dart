import '../../model/file_task.dart';
import 'notification_event_kind.dart';
import 'transfer_notification_action.dart';
import 'transfer_type.dart';

/// Immutable snapshot describing one notification event delivered to a
/// [TransferNotificationAdapter].
///
/// Constructed only by `TransferNotificationCoordinator`; consumers receive
/// it inside their adapter implementation.
class TransferNotificationPayload {
  /// Stable per-task identifier (also serves as the dedup key).
  final String taskId;

  /// Non-null when grouping mode is `batch`.
  final String? groupId;

  /// Direction of the transfer.
  final TransferType transferType;

  /// Underlying task lifecycle state at the time of dispatch.
  final FileTaskState state;

  /// The kind of event that triggered this dispatch.
  final NotificationEventKind eventKind;

  /// Progress in `[0.0, 1.0]`. For terminal states: `1.0` on success and the
  /// last-known value on failure.
  final double progress;

  /// Optional byte counters for adapters that show byte amounts.
  final int? bytesTransferred;
  final int? totalBytes;

  /// Best-effort file name resolved from the task. Null if unavailable.
  final String? fileName;

  /// Pre-resolved title string (template + localization applied).
  final String title;

  /// Pre-resolved body string (template + localization applied).
  final String body;

  /// Buttons to render. Empty if the template provided none. Built-in adapter
  /// ignores in v1 per R-010.
  final List<TransferNotificationAction> actions;

  /// Stable platform-level notification ID for this task or group.
  ///
  /// Computed as `kNotificationIdRangeStart + (taskId.hashCode.abs() %
  /// kNotificationIdRangeSize)` (R-004) so progress and terminal events
  /// update the same tray entry.
  final int notificationId;

  /// Time the event was emitted.
  final DateTime timestamp;

  const TransferNotificationPayload({
    required this.taskId,
    required this.transferType,
    required this.state,
    required this.eventKind,
    required this.progress,
    required this.title,
    required this.body,
    required this.notificationId,
    required this.timestamp,
    this.groupId,
    this.bytesTransferred,
    this.totalBytes,
    this.fileName,
    this.actions = const [],
  });

  TransferNotificationPayload copyWith({
    String? taskId,
    String? groupId,
    TransferType? transferType,
    FileTaskState? state,
    NotificationEventKind? eventKind,
    double? progress,
    int? bytesTransferred,
    int? totalBytes,
    String? fileName,
    String? title,
    String? body,
    List<TransferNotificationAction>? actions,
    int? notificationId,
    DateTime? timestamp,
  }) {
    return TransferNotificationPayload(
      taskId: taskId ?? this.taskId,
      groupId: groupId ?? this.groupId,
      transferType: transferType ?? this.transferType,
      state: state ?? this.state,
      eventKind: eventKind ?? this.eventKind,
      progress: progress ?? this.progress,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      fileName: fileName ?? this.fileName,
      title: title ?? this.title,
      body: body ?? this.body,
      actions: actions ?? this.actions,
      notificationId: notificationId ?? this.notificationId,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() =>
      'TransferNotificationPayload(taskId: $taskId, state: $state, '
      'kind: $eventKind, progress: ${(progress * 100).toStringAsFixed(0)}%, '
      'notificationId: $notificationId)';
}
