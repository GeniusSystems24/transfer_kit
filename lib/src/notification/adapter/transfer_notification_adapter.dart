import '../model/notification_permission_status.dart';
import '../model/transfer_notification_payload.dart';

/// Renders, updates, and dismisses notifications for transfer task events.
///
/// Implementations MUST satisfy the contract documented in
/// `specs/003-notification-control-ui/contracts/notification-adapter.md`.
/// In particular:
///
/// - Use `payload.notificationId` as the stable identity (G-1).
/// - Never throw — failures must be silent (G-2).
/// - Never include signed URLs, tokens, or full paths in title/body (G-3).
/// - `checkPermission()` MUST NOT trigger any system dialog (G-4).
/// - On unsupported platforms all `show*`/`cancel*` calls are no-ops and
///   `checkPermission()` / `requestPermission()` return [
///   NotificationPermissionStatus.notDetermined] (G-5).
abstract interface class TransferNotificationAdapter {
  /// Returns the current notification permission status WITHOUT showing any
  /// system dialog. Must complete in under 100 ms (SC-007).
  Future<NotificationPermissionStatus> checkPermission();

  /// Requests notification permission from the user (may show a system
  /// dialog). MUST NOT be called automatically by TransferKit unless
  /// `TransferNotificationConfig.requestPermissionOnInit` is true (FR-013).
  Future<NotificationPermissionStatus> requestPermission();

  /// Shows or updates the progress notification for `payload.taskId`.
  /// Implementations MUST use `payload.notificationId` as the stable identity
  /// so the same tray entry is reused (FR-005).
  ///
  /// Called for: `state == running` (progress ticks, throttled by the
  /// coordinator), `state == paused`, and retry events.
  Future<void> showOrUpdateProgress(TransferNotificationPayload payload);

  /// Shows a terminal completion notification.
  ///
  /// SHOULD reuse the same notification id as the progress notification so
  /// the tray entry transitions in place (FR-005).
  ///
  /// Called for: `state == completed`, and `state == cancelled` when
  /// `showCancelled` is true.
  Future<void> showCompletion(TransferNotificationPayload payload);

  /// Shows a terminal error notification (`state == error`).
  Future<void> showError(TransferNotificationPayload payload);

  /// Cancels (dismisses from the tray) the notification associated with
  /// [taskId]. No-op if no notification exists.
  Future<void> cancel(String taskId);

  /// Cancels all notifications associated with [groupId]. No-op if no
  /// grouped notification exists.
  Future<void> cancelGroup(String groupId);

  /// Releases any platform resources owned by this adapter.
  Future<void> dispose();
}
