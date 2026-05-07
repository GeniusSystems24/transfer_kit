/// Determines how TransferKit groups notifications across multiple tasks.
///
/// See `specs/003-notification-control-ui/data-model.md` §5 (FR-006).
enum NotificationGroupingMode {
  /// One notification per task. Default.
  perFile,

  /// One grouped summary notification per `groupId`; individual task
  /// notifications are suppressed.
  batch,

  /// No notifications shown at all.
  none,
}
