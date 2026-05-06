import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'date_time_extension.dart';
import 'string_extension.dart';

/// Extension for debug printing any value.
extension DynamicExtension on dynamic {
  /// Prints the value to debug console.
  void print() {
    debugPrint(toString());
  }
}

/// Extension methods for Object type conversions.
///
/// Provides utilities for converting various types to Timestamp or DateTime.
extension ObjectExtension<T extends Object> on T {
  /// Converts an object to a Firestore Timestamp.
  ///
  /// Handles:
  /// - Timestamp (returns as-is)
  /// - DateTime (converts to Timestamp)
  /// - String (parses ISO format or custom format)
  ///
  /// Returns `null` if conversion is not possible.
  ///
  /// Example:
  /// ```dart
  /// final ts1 = DateTime.now().objectToTimestamp();
  /// final ts2 = '2024-01-15T10:30:00'.objectToTimestamp();
  /// ```
  Timestamp? objectToTimestamp() {
    final value = this;

    if (value is Timestamp) return value;
    if (value is DateTime) return value.toTimestamp();
    if (value is String) {
      final string = value.textOrNull;
      if (string == null) return null;
      if (string.contains('(')) {
        return string.parseCustomDateTime().toTimestamp();
      }
      return DateTime.tryParse(string)?.toTimestamp();
    }
    return null;
  }

  /// Converts an object to a DateTime.
  ///
  /// Handles:
  /// - DateTime (returns as-is)
  /// - String (parses ISO format or custom format)
  /// - Timestamp (converts to DateTime)
  ///
  /// Returns `null` if conversion is not possible.
  ///
  /// Example:
  /// ```dart
  /// final dt1 = Timestamp.now().objectToDateTime();
  /// final dt2 = '2024-01-15T10:30:00'.objectToDateTime();
  /// ```
  DateTime? objectToDateTime() {
    final value = this;
    if (value is DateTime) return value;
    if (value is String) {
      final string = value.textOrNull;
      if (string == null) return null;
      if (string.contains('(')) return string.parseCustomDateTime();
      return DateTime.tryParse(string);
    }
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
