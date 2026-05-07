/// Common date-time field tags used in documents.
///
/// These tags are used for automatic conversion when
/// serializing/deserializing data.
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
  // intentionally empty after removing Firestore-specific toTimestamp()
}
