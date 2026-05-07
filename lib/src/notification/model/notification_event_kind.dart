/// The kind of lifecycle event that produced a notification dispatch decision.
///
/// Used by [TransferNotificationPolicy] to pick the matching toggle in
/// [TransferNotificationConfig].
enum NotificationEventKind {
  /// Periodic progress update (subject to throttling).
  progress,

  /// Terminal event (`completed`, `error`, `cancelled`, `cached`).
  terminal,

  /// Side-channel retry signal emitted before a retried task transitions back
  /// to running.
  retry,
}
