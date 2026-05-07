import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';

import '../model/notification_permission_status.dart';
import '../model/transfer_notification_payload.dart';
import 'transfer_notification_adapter.dart';

/// Built-in [TransferNotificationAdapter] backed by `awesome_notifications`.
///
/// This is the only file in TransferKit that imports `awesome_notifications`
/// (Principle VI — provider abstraction boundary). The channel is registered
/// lazily on the first `show*` call so consumers that never enable
/// notifications never pay the registration cost.
///
/// Platform support matrix (G-5):
///
/// | Platform | show*  | cancel* | checkPermission | requestPermission |
/// |----------|--------|---------|-----------------|-------------------|
/// | Android  | yes    | yes     | yes             | yes               |
/// | iOS      | yes    | yes     | yes             | yes               |
/// | other    | no-op  | no-op   | notDetermined   | notDetermined     |
class AwesomeNotificationAdapter implements TransferNotificationAdapter {
  /// Default notification channel key used when a template does not override.
  static const String defaultChannelKey = 'transfer_kit_default';

  /// Default channel name shown to the user in OS settings.
  static const String defaultChannelName = 'File Transfers';

  /// Default channel description shown in OS settings.
  static const String defaultChannelDescription =
      'Notifications for file uploads and downloads';

  bool _initialized = false;

  /// Optional override of the platform check, used by tests to simulate
  /// unsupported platforms without monkey-patching `defaultTargetPlatform`.
  final bool Function()? _isSupportedOverride;

  AwesomeNotificationAdapter({bool Function()? isSupportedOverride})
    : _isSupportedOverride = isSupportedOverride;

  bool get _isSupported {
    if (_isSupportedOverride != null) return _isSupportedOverride();
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _ensureInitialized(String channelKey) async {
    if (_initialized) return;
    _initialized = true;
    try {
      await AwesomeNotifications().initialize(null, [
        NotificationChannel(
          channelKey: channelKey,
          channelName: defaultChannelName,
          channelDescription: defaultChannelDescription,
          importance: NotificationImportance.High,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          locked: true,
        ),
      ]);
    } catch (_) {
      // G-2: failures are silent. We will retry initialization on the next
      // call by leaving _initialized true so we do not loop on a permanently
      // broken platform; subsequent show* calls will simply no-op.
    }
  }

  @override
  Future<NotificationPermissionStatus> checkPermission() async {
    if (!_isSupported) return NotificationPermissionStatus.notDetermined;
    try {
      final allowed = await AwesomeNotifications().isNotificationAllowed();
      return allowed
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    } catch (_) {
      return NotificationPermissionStatus.notDetermined;
    }
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    if (!_isSupported) return NotificationPermissionStatus.notDetermined;
    try {
      final granted = await AwesomeNotifications()
          .requestPermissionToSendNotifications();
      return granted
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    } catch (_) {
      return NotificationPermissionStatus.notDetermined;
    }
  }

  @override
  Future<void> showOrUpdateProgress(TransferNotificationPayload payload) async {
    if (!_isSupported) return;
    const channelKey = defaultChannelKey;
    await _ensureInitialized(channelKey);
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: payload.notificationId,
          channelKey: channelKey,
          title: payload.title,
          body: payload.body,
          notificationLayout: NotificationLayout.ProgressBar,
          progress: (payload.progress * 100).clamp(0, 100).toDouble(),
          locked: true,
          category: NotificationCategory.Progress,
        ),
      );
    } catch (_) {
      // Silent per G-2.
    }
  }

  @override
  Future<void> showCompletion(TransferNotificationPayload payload) async {
    if (!_isSupported) return;
    const channelKey = defaultChannelKey;
    await _ensureInitialized(channelKey);
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: payload.notificationId,
          channelKey: channelKey,
          title: payload.title,
          body: payload.body,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Transport,
        ),
      );
    } catch (_) {
      // Silent per G-2.
    }
  }

  @override
  Future<void> showError(TransferNotificationPayload payload) async {
    if (!_isSupported) return;
    const channelKey = defaultChannelKey;
    await _ensureInitialized(channelKey);
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: payload.notificationId,
          channelKey: channelKey,
          title: payload.title,
          body: payload.body,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Error,
        ),
      );
    } catch (_) {
      // Silent per G-2.
    }
  }

  @override
  Future<void> cancel(String taskId) async {
    if (!_isSupported) return;
    try {
      final id = _notificationIdFor(taskId);
      await AwesomeNotifications().cancel(id);
    } catch (_) {
      // Silent per G-2.
    }
  }

  @override
  Future<void> cancelGroup(String groupId) async {
    if (!_isSupported) return;
    try {
      final id = _notificationIdFor(groupId);
      await AwesomeNotifications().cancel(id);
    } catch (_) {
      // Silent per G-2.
    }
  }

  @override
  Future<void> dispose() async {
    // No persistent listener owned here; nothing to release in v1.
  }

  static int _notificationIdFor(String key) =>
      10000 + (key.hashCode.abs() % 29999);
}
