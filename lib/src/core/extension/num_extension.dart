/// Extension methods for formatting numeric values.
///
/// Provides utilities for converting byte values to human-readable formats.
///
/// ## Usage
/// ```dart
/// // Format bytes
/// print(1024.formatBytes); // '1.0 KB'
/// print(1048576.formatBytes); // '1.0 MB'
/// print(1073741824.formatBytes); // '1.0 GB'
/// ```
extension NumExtension<T extends num> on T? {
  // Size constants for better performance (avoid repeated pow() calls)
  static const int _kb = 1000;
  static const int _mb = 1000000;
  static const int _gb = 1000000000;

  /// Formats a numeric byte value to a human-readable string.
  ///
  /// Converts bytes to the most appropriate unit (B, KB, MB, GB).
  ///
  /// **Behavior:**
  /// - Values less than 1,000 are displayed as bytes
  /// - Values between 1,000 and 999,999 display as KB
  /// - Values between 1,000,000 and 999,999,999 display as MB
  /// - Values >= 1,000,000,000 display as GB
  ///
  /// **Example:**
  /// ```dart
  /// int bytes1 = 500;
  /// print(bytes1.formatBytes); // '500'
  ///
  /// int bytes2 = 1500;
  /// print(bytes2.formatBytes); // '1.5 KB'
  ///
  /// int bytes3 = 2000000;
  /// print(bytes3.formatBytes); // '2.0 MB'
  ///
  /// int bytes4 = 3000000000;
  /// print(bytes4.formatBytes); // '3.0 GB'
  /// ```
  String get formatBytes {
    final number = this;
    if (number == null || number == 0) return '0.0 B';
    if (number < _kb) {
      return number.toString();
    } else if (number < _mb) {
      return '${(number / _kb).toStringAsFixed(1)} KB';
    } else if (number < _gb) {
      return '${(number / _mb).toStringAsFixed(1)} MB';
    } else {
      return '${(number / _gb).toStringAsFixed(1)} GB';
    }
  }
}
