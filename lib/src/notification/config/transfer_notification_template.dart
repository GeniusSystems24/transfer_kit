import '../model/transfer_notification_action.dart';
import '../model/transfer_notification_payload.dart';

/// Reserved keys understood by [TransferNotificationTemplate.resolve].
class TransferNotificationTemplateKeys {
  static const String title = 'title';
  static const String body = 'body';
  static const String progress = 'progress';
  static const String success = 'success';
  static const String failure = 'failure';
  static const String cancelled = 'cancelled';
  static const String paused = 'paused';
  static const String retry = 'retry';
  static const String groupedTitle = 'groupedTitle';

  const TransferNotificationTemplateKeys._();
}

/// Customizable text and presentation for notifications.
///
/// One template per direction (upload / download) is held by
/// [TransferNotificationConfig]. The coordinator resolves text via
/// [resolve] which honors the precedence order:
///   1. `resolveText` callback if provided.
///   2. `localization[key]` if provided.
///   3. Per-key string field on this template.
///   4. Default factory string.
class TransferNotificationTemplate {
  /// Display title (e.g. "Uploading file").
  final String title;

  /// Optional explicit body. When null, the coordinator falls back to the
  /// runtime [TransferNotificationPayload.fileName] (or empty).
  final String? body;

  /// Renders the body text for a progress event. Receives `[0.0, 1.0]`.
  final String Function(double progress)? progressText;

  final String successText;
  final String failureText;
  final String cancelledText;
  final String pausedText;
  final String retryText;

  /// Renders the title for a grouped batch notification.
  final String Function(int total, int completed)? groupedTitle;

  /// Adapter-specific icon resource (e.g. an Android drawable name).
  final String? iconKey;

  /// Adapter-specific channel key. Falls back to the adapter default.
  final String? channelKey;

  /// Optional key → translation map. Consumed by the default [resolve] chain.
  final Map<String, String>? localization;

  /// Optional override that supersedes every plain string field.
  final String Function(String key, TransferNotificationPayload payload)?
  resolveText;

  /// Buttons to render (built-in adapter ignores per R-010).
  final List<TransferNotificationAction>? actions;

  const TransferNotificationTemplate({
    this.title = 'File transfer',
    this.body,
    this.progressText,
    this.successText = 'Transfer complete',
    this.failureText = 'Transfer failed',
    this.cancelledText = 'Transfer cancelled',
    this.pausedText = 'Transfer paused',
    this.retryText = 'Retrying transfer',
    this.groupedTitle,
    this.iconKey,
    this.channelKey,
    this.localization,
    this.resolveText,
    this.actions,
  });

  /// Default template for upload notifications.
  factory TransferNotificationTemplate.defaultUpload() =>
      const TransferNotificationTemplate(
        title: 'Uploading file',
        successText: 'Upload complete',
        failureText: 'Upload failed',
      );

  /// Default template for download notifications.
  factory TransferNotificationTemplate.defaultDownload() =>
      const TransferNotificationTemplate(
        title: 'Downloading file',
        successText: 'Download complete',
        failureText: 'Download failed',
      );

  /// Resolves a string for [key] using the precedence chain documented on the
  /// class. Returns the empty string when no override and no default exists.
  String resolve(String key, TransferNotificationPayload payload) {
    final cb = resolveText;
    if (cb != null) {
      return cb(key, payload);
    }
    final loc = localization;
    if (loc != null && loc.containsKey(key)) {
      return loc[key]!;
    }
    return _defaultFor(key, payload);
  }

  String _defaultFor(String key, TransferNotificationPayload payload) {
    switch (key) {
      case TransferNotificationTemplateKeys.title:
        return title;
      case TransferNotificationTemplateKeys.body:
        return body ?? payload.fileName ?? '';
      case TransferNotificationTemplateKeys.progress:
        final cb = progressText;
        if (cb != null) return cb(payload.progress);
        return '${(payload.progress * 100).toStringAsFixed(0)}%';
      case TransferNotificationTemplateKeys.success:
        return successText;
      case TransferNotificationTemplateKeys.failure:
        return failureText;
      case TransferNotificationTemplateKeys.cancelled:
        return cancelledText;
      case TransferNotificationTemplateKeys.paused:
        return pausedText;
      case TransferNotificationTemplateKeys.retry:
        return retryText;
      default:
        return '';
    }
  }
}
