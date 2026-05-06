import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'string_extension.dart';
import 'date_time_extension.dart';
import 'dynamic_extension.dart';
import 'geo_point_extension.dart';

/// Extension for comparing maps.
extension MapExtension<Key extends dynamic, Value extends dynamic>
    on Map<Key, Value> {
  /// Compares this map with another for equality.
  ///
  /// Returns `true` if both maps have identical entries.
  bool equals(Map<Key, Value>? other) =>
      other == null ||
      Object.hashAll(entries.map((entry) => entry.toString())) ==
          Object.hashAll(other.entries.map((entry) => entry.toString()));
}

/// Extension methods for type-safe Map access and conversion.
///
/// Provides safe getters for common data types from dynamic maps,
/// particularly useful when working with Firestore documents or JSON data.
///
/// ## Usage
/// ```dart
/// final data = {
///   'name': 'John',
///   'age': 30,
///   'isAdmin': true,
///   'createdAt': Timestamp.now(),
/// };
///
/// print(data.getString('name')); // 'John'
/// print(data.getInt('age')); // 30
/// print(data.getBool('isAdmin')); // true
/// print(data.getDateTime('createdAt')); // DateTime instance
/// ```
extension MapStringDynamicExtension on Map<String, dynamic> {
  /// Converts the map to JSON-safe format.
  ///
  /// Converts Firestore-specific types (Timestamp, GeoPoint) to
  /// JSON-compatible formats.
  Map<String, dynamic> mapCanConvertToJson() {
    return {
      for (var entry in entries)
        if (entry.value is Map<String, dynamic>)
          entry.key: (entry.value as Map<String, dynamic>).mapCanConvertToJson()
        else if (entry.value is List<dynamic>)
          entry.key:
              (entry.value as List<dynamic>)
                  .take(3)
                  .map(
                    (e) =>
                        e is Map<String, dynamic> ? e.mapCanConvertToJson() : e,
                  )
                  .toList()
        else if (entry.value is Timestamp)
          entry.key: (entry.value as Timestamp).toDate().toIso8601String()
        else if (entry.value is DateTime)
          entry.key: (entry.value as DateTime).toIso8601String()
        else if (entry.value is GeoPoint)
          entry.key: (entry.value as GeoPoint).toMap()
        else
          entry.key: entry.value,
    };
  }

  /// Converts the map to Firestore-safe format.
  ///
  /// Converts DateTime fields to Timestamp based on common field names.
  Map<String, dynamic> mapCanConvertToFirebase() {
    return {
      for (var entry in entries)
        if (entry.value is Map<String, dynamic>)
          entry.key:
              (entry.value as Map<String, dynamic>).mapCanConvertToFirebase()
        else if (entry.value is List<dynamic>)
          entry.key:
              (entry.value as List<dynamic>)
                  .take(3)
                  .map(
                    (e) =>
                        e is Map<String, dynamic>
                            ? e.mapCanConvertToFirebase()
                            : e,
                  )
                  .toList()
        else if (DateTimeTag.values.any((e) => entry.key == e.name))
          entry.key: (entry.value as Object?)?.objectToTimestamp()
        else
          entry.key: entry.value,
    };
  }

  /// Compares this map with another for equality.
  bool equals(Map<String, dynamic>? other) =>
      other == null ||
      Object.hashAll(entries.map((entry) => entry.toString())) ==
          Object.hashAll(other.entries.map((entry) => entry.toString()));

  /// Converts the map to a JSON string.
  ///
  /// Example:
  /// ```dart
  /// final data = {'name': 'John'};
  /// print(data.toJson()); // '{"name":"John"}'
  /// ```
  String toJson() => json.encode(this);

  /// Gets a DocumentReference value from the map.
  ///
  /// Handles both String paths and DocumentReference values.
  DocumentReference<Map<String, dynamic>>? getDocumentReference(String tag) {
    try {
      final value = this[tag];
      if (value is String) {
        return FirebaseFirestore.instance.doc(value);
      } else if (value is DocumentReference<Map<String, dynamic>>) {
        return value;
      } else {
        return null;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Gets a Timestamp value from the map.
  ///
  /// Handles Timestamp, DateTime, and ISO string values.
  Timestamp? getTimestamp(String tag) {
    try {
      final Object? value = this[tag];
      return value?.objectToTimestamp();
    } catch (e) {
      rethrow;
    }
  }

  /// Gets a DateTime value from the map.
  ///
  /// Handles DateTime, Timestamp, and ISO string values.
  DateTime? getDateTime(String tag) {
    try {
      final Object? value = this[tag];
      return value?.objectToDateTime();
    } catch (e) {
      rethrow;
    }
  }

  /// Gets a String value from the map.
  ///
  /// Returns `null` if the key doesn't exist or value is not a String.
  String? getString(String? tag) {
    try {
      return this[tag] as String?;
    } catch (e) {
      rethrow;
    }
  }

  /// Gets a bool value from the map.
  ///
  /// Returns `null` if the key doesn't exist or value is not a bool.
  bool? getBool(String tag) {
    try {
      return this[tag] as bool?;
    } catch (e) {
      rethrow;
    }
  }

  /// Gets an int value from the map.
  ///
  /// Attempts to parse string values to int.
  int? getInt(String tag) {
    try {
      return !containsKey(tag) ? null : int.tryParse(this[tag].toString());
    } catch (e) {
      rethrow;
    }
  }

  /// Gets a double value from the map.
  ///
  /// Attempts to parse string values to double.
  double? getDouble(String tag) {
    try {
      return !containsKey(tag)
          ? null
          : double.tryParse(this[tag].toString()) ?? getInt(tag)?.toDouble();
    } catch (e) {
      rethrow;
    }
  }

  /// Gets a nested Map value from the map.
  ///
  /// Converts dynamic maps to typed maps if necessary.
  Map<String, dynamic>? getMap(String tag) {
    try {
      var map = this[tag];
      if (map is Map<String, dynamic>) {
        return map;
      } else if (map is Map<dynamic, dynamic>) {
        return map.toStringDynamicMap();
      } else {
        return null;
      }
    } catch (e) {
      throw '[$tag] type: ${this[tag].runtimeType} , value: ${this[tag]}\n$e';
    }
  }

  /// Gets a typed List from the map.
  ///
  /// Returns `null` if the key doesn't exist.
  List<T>? getList<T>(String tag) {
    try {
      var data = this[tag];
      return data == null ? null : List.from(data).cast<T>();
    } catch (e) {
      return null;
    }
  }

  /// Gets a Uint8List from the map.
  ///
  /// Expects the value to be a JSON-encoded list of integers.
  Uint8List? getUint8List(String tag) {
    var list = getString(tag)?.toList<int>();
    if (list == null) return null;
    return Uint8List.fromList(list);
  }

  /// Returns a new map with null values removed.
  Map<String, dynamic> withoutNullValues() {
    return {
      for (var entry in entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }
}

/// Extension for converting dynamic maps to String-keyed maps.
extension MapDynamicDynamicExtension on Map<dynamic, dynamic> {
  /// Converts a dynamic-keyed map to a String-keyed map.
  Map<String, dynamic> toStringDynamicMap() => {
    for (final entry in entries) entry.key.toString(): entry.value,
  };
}
