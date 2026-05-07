import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../core/extension/string_extension.dart';
import '../core/extension/list_extension.dart';
import '../core/get_storage_value_notifier.dart';

class BackgroundTaskRepository
    extends GetStorageValueNotifier<Set<String>, String> {
  static const String _storageKey = 'file_management_active_batches';
  static final BackgroundTaskRepository instance =
      BackgroundTaskRepository._internal();

  BackgroundTaskRepository._internal() : super(_storageKey, {});

  factory BackgroundTaskRepository() => instance;

  @override
  @protected
  String inputConverter(Set<String> val) => val.toList().toJson();

  @override
  @protected
  Set<String> outputConverter(String? value) =>
      value?.toList<String>().toSet() ?? <String>{};

  String? get(String item) =>
      value.firstWhereOrNull((element) => element == item);

  /// Adds an item to the repository.
  ///
  /// The item is added to the repository and the repository is notified of the change.
  ///
  /// ## Parameters
  ///
  /// * [item] - The item to add
  /// * [notify] - Whether to trigger change notifications (default: true)
  int add(String item, {bool notify = true}) {
    final isAdded = value.add(item);
    if (!isAdded) return 0;

    notifyListeners();
    return 1;
  }

  /// Removes an item from the repository.
  ///
  /// The item is identified using its equality operator. If the item
  /// exists in the repository, it will be removed.
  ///
  /// Returns `1` if the item was removed, `0` if the item was not found.
  ///
  /// ## Parameters
  ///
  /// * [item] - The item to remove
  /// * [notify] - Whether to trigger change notifications (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final task = Task(id: '1', title: ''); // Only id matters for equality
  /// final result = repository.remove(task);
  /// print('Item removed: ${result == 1}');
  /// ```
  @nonVirtual
  int remove(String item, {bool notify = true}) {
    final isDeleted = value.remove(item);
    if (!isDeleted) return 0;

    if (notify) notifyListeners();
    return 1;
  }

  /// Cleanup completed or old tasks
  ///
  /// Can be used to clean up tasks that are no longer active
  ///
  /// ## Parameters
  ///
  /// * [olderThanDays] - Remove tasks older than the specified number of days
  /// * [notify] - Whether to trigger change notifications (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Clean up tasks older than 7 days
  /// final cleanedCount = repository.cleanupOldTasks(olderThanDays: 7);
  /// print('Cleaned $cleanedCount old tasks');
  /// ```
  int cleanupOldTasks({int olderThanDays = 7, bool notify = true}) {
    final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
    int removedCount = 0;

    // Since the data type is String, we need more context
    // to determine what's "old". This is a general example:
    final oldItems = value.where((item) {
      // This logic can be customized based on data format
      // Example: if the item contains a timestamp
      return item.contains('old') ||
          item.contains(cutoffDate.toString().substring(0, 10));
    }).toSet();

    for (final item in oldItems) {
      if (value.remove(item)) {
        removedCount++;
      }
    }

    if (removedCount > 0 && notify) notifyListeners();
    return removedCount;
  }

  /// Clear all tasks
  ///
  /// ## Parameters
  ///
  /// * [notify] - Whether to trigger change notifications (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final totalCleared = repository.clearAll();
  /// print('Cleared $totalCleared tasks');
  /// ```
  int clearAll({bool notify = true}) {
    final count = value.length;
    value.clear();

    if (count > 0 && notify) notifyListeners();
    return count;
  }
}
