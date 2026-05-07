/// Notification permission state reported by a [TransferNotificationAdapter].
///
/// See FR-011 / FR-012.
enum NotificationPermissionStatus {
  /// User has granted notification permission.
  granted,

  /// User has explicitly denied notification permission.
  denied,

  /// Platform-level restriction prevents granting (iOS-specific). On Android
  /// this collapses into [denied] at runtime.
  restricted,

  /// Initial state, or returned by adapters on platforms that do not support
  /// notifications.
  notDetermined,
}
