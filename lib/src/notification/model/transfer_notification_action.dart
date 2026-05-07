/// A button that can be attached to a notification.
///
/// v1: declared but ignored by the built-in `AwesomeNotificationAdapter` per
/// research decision R-010. Custom adapters MAY render the buttons and route
/// taps through `TransferKit.instance.handleNotificationAction(key, taskId)`.
class TransferNotificationAction {
  /// Identifier for the action. Reserved keys: `pause`, `resume`, `cancel`,
  /// `retry`. Unknown keys are forwarded to a developer-supplied callback.
  final String key;

  /// Localized button label.
  final String label;

  /// Adapter-specific icon reference (drawable name on Android, asset on iOS,
  /// etc.). Null defers to the adapter default.
  final String? iconKey;

  const TransferNotificationAction({
    required this.key,
    required this.label,
    this.iconKey,
  });
}
