import 'dart:convert';

import 'package:intl/intl.dart';

/// Extension methods for String manipulation and parsing.
///
/// Provides utilities for JSON parsing and URL detection.
///
/// ## Usage
/// ```dart
/// // Parse JSON string to Map
/// final jsonStr = '{"name": "John"}';
/// final map = jsonStr.toMap();
///
/// // Check if string is HTTP URL
/// print('https://example.com'.isHttpUrl); // true
/// print('/local/path'.isHttpUrl); // false
/// ```
extension StringFunctions on String {
  /// Parses a JSON string into a Map.
  ///
  /// Throws [FormatException] if the string is not valid JSON.
  ///
  /// Example:
  /// ```dart
  /// final json = '{"key": "value"}';
  /// final map = json.toMap();
  /// print(map['key']); // 'value'
  /// ```
  Map<String, dynamic> toMap() => json.decode(this) as Map<String, dynamic>;

  /// Parses a JSON array string into a List of Maps.
  ///
  /// Example:
  /// ```dart
  /// final json = '[{"id": 1}, {"id": 2}]';
  /// final list = json.toListMap();
  /// print(list.length); // 2
  /// ```
  List<Map<String, dynamic>> toListMap() {
    return (json.decode(this) as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  /// Parses a JSON array string into a typed List.
  ///
  /// Example:
  /// ```dart
  /// final json = '[1, 2, 3]';
  /// final numbers = json.toList<int>();
  /// ```
  List<T> toList<T>() {
    return (json.decode(this) as List).map((e) => e as T).toList();
  }

  /// Checks if the string starts with 'http' (case-insensitive).
  ///
  /// Returns `true` for HTTP and HTTPS URLs.
  ///
  /// Example:
  /// ```dart
  /// print('https://example.com'.isHttpUrl); // true
  /// print('HTTP://example.com'.isHttpUrl); // true
  /// print('/local/path'.isHttpUrl); // false
  /// ```
  bool get isHttpUrl => toLowerCase().startsWith('http');

  /// Returns the trimmed string or null if empty.
  ///
  /// Useful for handling optional string fields.
  ///
  /// Example:
  /// ```dart
  /// print('  hello  '.textOrNull); // 'hello'
  /// print('   '.textOrNull); // null
  /// print(''.textOrNull); // null
  /// ```
  String? get textOrNull => trim().isNotEmpty ? trim() : null;

  /// Parses a custom date-time string format.
  ///
  /// Handles strings like:
  /// "Wed May 15 2024 15:36:38 GMT+0300 (Arabian Standard Time)"
  ///
  /// Returns the equivalent local DateTime.
  DateTime parseCustomDateTime() {
    final cleaned = split(' (').first.trim();
    final formatter = DateFormat("EEE MMM dd yyyy HH:mm:ss 'GMT'Z", 'en_US');
    return formatter.parseUTC(cleaned).toLocal();
  }
}
