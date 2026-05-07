/// Thrown when an operation is attempted on a [TransferDriver] that does not
/// declare support for it via [TransferCapabilities].
///
/// Always thrown synchronously — never async.
class UnsupportedCapabilityException implements Exception {
  const UnsupportedCapabilityException(this.message, {this.capability});

  /// Human-readable description of the unsupported operation.
  final String message;

  /// The capability flag name that was `false`, e.g. `'supportsPause'`.
  final String? capability;

  @override
  String toString() {
    final cap = capability != null ? ' [$capability]' : '';
    return 'UnsupportedCapabilityException$cap: $message';
  }
}
