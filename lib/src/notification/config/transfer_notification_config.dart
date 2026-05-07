import '../adapter/transfer_notification_adapter.dart';
import '../model/notification_grouping_mode.dart';
import 'transfer_notification_template.dart';

/// Default throttle window for progress notifications (FR-004).
const Duration kDefaultNotificationThrottle = Duration(milliseconds: 1000);

/// Configuration for TransferKit notifications.
///
/// Held inside `TransferKitConfig` and read by
/// `TransferNotificationCoordinator`. See `data-model.md` §1 for the field
/// catalogue.
class TransferNotificationConfig {
  /// Master switch. When false, no notifications fire — every other flag is
  /// ignored at runtime (FR-001 / FR-015). Defaults to false (opt-in).
  final bool enabled;

  /// When false, all upload notifications are suppressed (FR-002).
  final bool uploadEnabled;

  /// When false, all download notifications are suppressed (FR-002).
  final bool downloadEnabled;

  // Per-state toggles (FR-003). Defaults match the values declared in
  // data-model.md §1: progress / completion / errors on by default;
  // cancelled / paused / retry off by default.
  final bool showProgress;
  final bool showCompletion;
  final bool showErrors;
  final bool showCancelled;
  final bool showPaused;
  final bool showRetry;

  /// Minimum spacing between two progress updates for the same task (FR-004).
  /// Defaults to 1 second (per spec clarification Q4).
  final Duration throttleDuration;

  /// How notifications are grouped when multiple tasks share a `groupId`
  /// (FR-006).
  final NotificationGroupingMode grouping;

  /// Template for upload notifications.
  final TransferNotificationTemplate uploadTemplate;

  /// Template for download notifications.
  final TransferNotificationTemplate downloadTemplate;

  /// Optional adapter override. Null falls back to the built-in
  /// `AwesomeNotificationAdapter` when notifications are enabled (FR-010).
  final TransferNotificationAdapter? adapter;

  /// Whether `TransferKitConfig.init()` should automatically request
  /// notification permission (FR-013). Defaults to false.
  final bool requestPermissionOnInit;

  TransferNotificationConfig({
    this.enabled = false,
    this.uploadEnabled = true,
    this.downloadEnabled = true,
    this.showProgress = true,
    this.showCompletion = true,
    this.showErrors = true,
    this.showCancelled = false,
    this.showPaused = false,
    this.showRetry = false,
    this.throttleDuration = kDefaultNotificationThrottle,
    this.grouping = NotificationGroupingMode.perFile,
    TransferNotificationTemplate? uploadTemplate,
    TransferNotificationTemplate? downloadTemplate,
    this.adapter,
    this.requestPermissionOnInit = false,
  }) : assert(
         throttleDuration > Duration.zero,
         'throttleDuration must be greater than zero',
       ),
       uploadTemplate =
           uploadTemplate ?? TransferNotificationTemplate.defaultUpload(),
       downloadTemplate =
           downloadTemplate ?? TransferNotificationTemplate.defaultDownload();

  /// Convenience: every flag false — the post-upgrade default state. Used by
  /// `TransferKitConfig.init()` when `notificationConfig` is omitted.
  factory TransferNotificationConfig.disabled() =>
      TransferNotificationConfig(enabled: false);

  /// Convenience preset: only upload notifications enabled.
  factory TransferNotificationConfig.uploadsOnly() =>
      TransferNotificationConfig(
        enabled: true,
        uploadEnabled: true,
        downloadEnabled: false,
      );

  /// Convenience preset: only download notifications enabled.
  factory TransferNotificationConfig.downloadsOnly() =>
      TransferNotificationConfig(
        enabled: true,
        uploadEnabled: false,
        downloadEnabled: true,
      );

  TransferNotificationConfig copyWith({
    bool? enabled,
    bool? uploadEnabled,
    bool? downloadEnabled,
    bool? showProgress,
    bool? showCompletion,
    bool? showErrors,
    bool? showCancelled,
    bool? showPaused,
    bool? showRetry,
    Duration? throttleDuration,
    NotificationGroupingMode? grouping,
    TransferNotificationTemplate? uploadTemplate,
    TransferNotificationTemplate? downloadTemplate,
    TransferNotificationAdapter? adapter,
    bool? requestPermissionOnInit,
  }) {
    return TransferNotificationConfig(
      enabled: enabled ?? this.enabled,
      uploadEnabled: uploadEnabled ?? this.uploadEnabled,
      downloadEnabled: downloadEnabled ?? this.downloadEnabled,
      showProgress: showProgress ?? this.showProgress,
      showCompletion: showCompletion ?? this.showCompletion,
      showErrors: showErrors ?? this.showErrors,
      showCancelled: showCancelled ?? this.showCancelled,
      showPaused: showPaused ?? this.showPaused,
      showRetry: showRetry ?? this.showRetry,
      throttleDuration: throttleDuration ?? this.throttleDuration,
      grouping: grouping ?? this.grouping,
      uploadTemplate: uploadTemplate ?? this.uploadTemplate,
      downloadTemplate: downloadTemplate ?? this.downloadTemplate,
      adapter: adapter ?? this.adapter,
      requestPermissionOnInit:
          requestPermissionOnInit ?? this.requestPermissionOnInit,
    );
  }

  /// Returns a debug-friendly map representation. Excludes the adapter
  /// reference and the template callbacks.
  Map<String, dynamic> toDebugMap() => {
    'enabled': enabled,
    'uploadEnabled': uploadEnabled,
    'downloadEnabled': downloadEnabled,
    'showProgress': showProgress,
    'showCompletion': showCompletion,
    'showErrors': showErrors,
    'showCancelled': showCancelled,
    'showPaused': showPaused,
    'showRetry': showRetry,
    'throttleDurationMs': throttleDuration.inMilliseconds,
    'grouping': grouping.name,
    'requestPermissionOnInit': requestPermissionOnInit,
    'hasCustomAdapter': adapter != null,
  };
}
