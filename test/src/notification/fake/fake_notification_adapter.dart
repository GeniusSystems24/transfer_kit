import 'package:transfer_kit/src/notification/adapter/transfer_notification_adapter.dart';
import 'package:transfer_kit/src/notification/model/notification_permission_status.dart';
import 'package:transfer_kit/src/notification/model/transfer_notification_payload.dart';

/// One recorded interaction with a [FakeNotificationAdapter].
class RecordedCall {
  /// Adapter method name (`showOrUpdateProgress`, `showCompletion`,
  /// `showError`, `cancel`, `cancelGroup`, `checkPermission`,
  /// `requestPermission`, `dispose`).
  final String method;

  /// Payload passed (null for `cancel*` and permission queries).
  final TransferNotificationPayload? payload;

  /// Task or group identifier (null for `show*` and permission queries — the
  /// id is on the payload in those cases).
  final String? taskOrGroupId;

  /// Wall-clock time the call was recorded.
  final DateTime at;

  RecordedCall({
    required this.method,
    required this.at,
    this.payload,
    this.taskOrGroupId,
  });

  @override
  String toString() =>
      'RecordedCall($method, payload: $payload, id: $taskOrGroupId, at: $at)';
}

/// In-memory test double for [TransferNotificationAdapter] that records every
/// invocation so tests can assert on dispatch decisions, payload contents,
/// and ordering.
///
/// Analogous to `FakeTransferDriver` (Principle VI). Always safe on every
/// platform — it never touches the OS.
class FakeNotificationAdapter implements TransferNotificationAdapter {
  /// Every call to this adapter, in order.
  final List<RecordedCall> recordedCalls = [];

  /// What [checkPermission] / [requestPermission] return. Default `granted`.
  NotificationPermissionStatus permissionStatus =
      NotificationPermissionStatus.granted;

  /// When non-null, every method throws this exception. Used by resilience
  /// tests to verify the coordinator survives adapter failures (FR-014).
  Object? throwOnEveryCall;

  void clear() {
    recordedCalls.clear();
  }

  /// Convenience: filter to calls matching [method].
  Iterable<RecordedCall> callsTo(String method) =>
      recordedCalls.where((c) => c.method == method);

  void _maybeThrow() {
    final err = throwOnEveryCall;
    if (err != null) throw err;
  }

  @override
  Future<NotificationPermissionStatus> checkPermission() async {
    recordedCalls.add(
      RecordedCall(method: 'checkPermission', at: DateTime.now()),
    );
    _maybeThrow();
    return permissionStatus;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    recordedCalls.add(
      RecordedCall(method: 'requestPermission', at: DateTime.now()),
    );
    _maybeThrow();
    return permissionStatus;
  }

  @override
  Future<void> showOrUpdateProgress(TransferNotificationPayload payload) async {
    recordedCalls.add(
      RecordedCall(
        method: 'showOrUpdateProgress',
        payload: payload,
        at: DateTime.now(),
      ),
    );
    _maybeThrow();
  }

  @override
  Future<void> showCompletion(TransferNotificationPayload payload) async {
    recordedCalls.add(
      RecordedCall(
        method: 'showCompletion',
        payload: payload,
        at: DateTime.now(),
      ),
    );
    _maybeThrow();
  }

  @override
  Future<void> showError(TransferNotificationPayload payload) async {
    recordedCalls.add(
      RecordedCall(method: 'showError', payload: payload, at: DateTime.now()),
    );
    _maybeThrow();
  }

  @override
  Future<void> cancel(String taskId) async {
    recordedCalls.add(
      RecordedCall(method: 'cancel', taskOrGroupId: taskId, at: DateTime.now()),
    );
    _maybeThrow();
  }

  @override
  Future<void> cancelGroup(String groupId) async {
    recordedCalls.add(
      RecordedCall(
        method: 'cancelGroup',
        taskOrGroupId: groupId,
        at: DateTime.now(),
      ),
    );
    _maybeThrow();
  }

  @override
  Future<void> dispose() async {
    recordedCalls.add(RecordedCall(method: 'dispose', at: DateTime.now()));
  }
}
