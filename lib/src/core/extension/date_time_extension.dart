import 'package:cloud_firestore/cloud_firestore.dart';

/// Common date-time field tags used in Firestore documents.
///
/// These tags are used for automatic Timestamp conversion when
/// serializing/deserializing documents.
enum DateTimeTag {
  createdAt,
  createAt,
  createDate,
  updatedAt,
  updateDate,
  startDate,
  endDate,
  lastModified,
  targetStartDate,
  targetEndDate,
}

/// Extension methods for DateTime conversion.
extension DateTimeExtension on DateTime {
  /// Converts a DateTime to a Firestore Timestamp.
  ///
  /// Example:
  /// ```dart
  /// final timestamp = DateTime.now().toTimestamp();
  /// ```
  Timestamp toTimestamp() => Timestamp.fromDate(this);
}
