import 'dart:convert';

/// Extension for converting lists to JSON strings.
extension APIListExtension<T> on List<T> {
  /// Converts the list to a JSON string.
  ///
  /// Example:
  /// ```dart
  /// final list = [1, 2, 3];
  /// print(list.toJson()); // '[1,2,3]'
  /// ```
  String toJson() => json.encode(this);
}
