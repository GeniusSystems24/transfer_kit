import 'package:cloud_firestore/cloud_firestore.dart';

/// Extension methods for GeoPoint conversion.
extension GeoPointExtension on GeoPoint {
  /// Converts a GeoPoint to a Map.
  ///
  /// Example:
  /// ```dart
  /// final point = GeoPoint(37.7749, -122.4194);
  /// final map = point.toMap();
  /// // {'latitude': 37.7749, 'longitude': -122.4194}
  /// ```
  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
  };
}
