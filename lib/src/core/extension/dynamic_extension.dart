import 'package:flutter/foundation.dart';

import 'string_extension.dart';

/// Extension for debug printing any value.
extension DynamicExtension on dynamic {
  /// Prints the value to debug console.
  void print() {
    debugPrint(toString());
  }
}

/// Extension methods for Object type conversions.
extension ObjectExtension<T extends Object> on T {
  /// Converts an object to a DateTime.
  ///
  /// Handles DateTime and ISO string values.
  DateTime? objectToDateTime() {
    final value = this;
    if (value is DateTime) return value;
    if (value is String) {
      final string = value.textOrNull;
      if (string == null) return null;
      if (string.contains('(')) return string.parseCustomDateTime();
      return DateTime.tryParse(string);
    }
    return null;
  }
}
