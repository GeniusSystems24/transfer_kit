import '../../model/file_task.dart';
import '../config/transfer_notification_config.dart';
import '../model/notification_event_kind.dart';
import '../model/transfer_type.dart';

/// Pure-function decision engine deciding whether a given notification event
/// should be dispatched to the adapter.
///
/// Decision matrix (when `config.enabled == true`):
///
/// | transferType | state     | kind     | shouldNotify                |
/// |--------------|-----------|----------|-----------------------------|
/// | upload       | *         | *        | false if !uploadEnabled     |
/// | download     | *         | *        | false if !downloadEnabled   |
/// | *            | running   | progress | config.showProgress         |
/// | *            | completed | terminal | config.showCompletion       |
/// | *            | error     | terminal | config.showErrors           |
/// | *            | cancelled | terminal | config.showCancelled        |
/// | *            | paused    | progress | config.showPaused           |
/// | *            | running   | retry    | config.showRetry            |
/// | *            | cached    | terminal | false (silent in v1)        |
/// | *            | waiting   | progress | false (queued never fires)  |
///
/// When `config.enabled == false`, returns `false` unconditionally (FR-015).
class TransferNotificationPolicy {
  final TransferNotificationConfig config;

  const TransferNotificationPolicy(this.config);

  /// Returns `true` when the event should result in an adapter dispatch.
  bool shouldNotify({
    required TransferType transferType,
    required FileTaskState state,
    required NotificationEventKind kind,
  }) {
    // FR-015: master switch wins over everything else.
    if (!config.enabled) return false;

    // FR-002: per-direction toggles.
    if (transferType == TransferType.upload && !config.uploadEnabled) {
      return false;
    }
    if (transferType == TransferType.download && !config.downloadEnabled) {
      return false;
    }

    // R-009: cached state and waiting state never fire in v1.
    if (state == FileTaskState.cached) return false;
    if (state == FileTaskState.waiting) return false;

    // FR-003: per-state toggles, dispatched by event kind.
    switch (kind) {
      case NotificationEventKind.retry:
        return config.showRetry;
      case NotificationEventKind.terminal:
        switch (state) {
          case FileTaskState.completed:
            return config.showCompletion;
          case FileTaskState.error:
            return config.showErrors;
          case FileTaskState.cancelled:
            return config.showCancelled;
          // ignore: no_default_cases
          default:
            return false;
        }
      case NotificationEventKind.progress:
        switch (state) {
          case FileTaskState.running:
            return config.showProgress;
          case FileTaskState.paused:
            return config.showPaused;
          // ignore: no_default_cases
          default:
            return false;
        }
    }
  }
}
