import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'get_storage_value_notifier.dart';

/// Interface for objects that can be stored and managed by [GetStorageRepository].
///
/// Classes implementing this interface must provide methods for updating
/// their state and comparing equality for change detection.
///
/// ## Usage Example
///
/// ```dart
/// class Task implements GetStorageMethods {
///   String id;
///   String title;
///   bool completed;
///
///   Task({required this.id, required this.title, this.completed = false});
///
///   @override
///   void update(GetStorageMethods item) {
///     if (item is Task) {
///       title = item.title;
///       completed = item.completed;
///     }
///   }
///
///   @override
///   bool operator ^(GetStorageMethods other) {
///     if (other is! Task) return true;
///     return title != other.title || completed != other.completed;
///   }
///
///   @override
///   bool operator ==(Object other) =>
///       identical(this, other) ||
///       other is Task && other.id == id;
///
///   @override
///   int get hashCode => id.hashCode;
/// }
/// ```
abstract class GetStorageMethods {
  /// Updates this object's state with values from [item].
  ///
  /// This method should copy relevant properties from [item] to this instance.
  /// It's called when an existing item in the repository needs to be updated.
  void update(Object item);

  /// Checks if this object has different content than [other].
  ///
  /// Returns `true` if the objects have different content (indicating an update is needed),
  /// or `false` if they have the same content. This is used to determine whether
  /// an update operation should trigger notifications.
  ///
  /// Note: This is the XOR operator (`^`) used for change detection.
  bool operator ^(covariant Object other);
}

/// An abstract repository class that manages a persistent set of items.
///
/// This class extends [GetStorageValueNotifier] to provide CRUD operations
/// for a collection of items that implement [GetStorageMethods]. The items
/// are automatically persisted to storage and the collection provides
/// reactive updates through [ValueNotifier] and [Stream] interfaces.
///
/// The repository maintains a [Set] of items, ensuring uniqueness based on
/// the items' equality operators. Items can be added, updated, or removed,
/// with automatic persistence and change notifications.
///
/// ## Usage Example
///
/// ```dart
/// class TaskRepository extends GetStorageRepository<Task> {
///   TaskRepository() : super('tasks', <Task>{});
///
///   @override
///   String inputConverter(Set<Task> val) {
///     return jsonEncode(val.map((task) => {
///       'id': task.id,
///       'title': task.title,
///       'completed': task.completed,
///     }).toList());
///   }
///
///   @override
///   Set<Task> outputConverter(String val) {
///     if (val.isEmpty) return <Task>{};
///     final List<dynamic> list = jsonDecode(val);
///     return list.map((json) => Task(
///       id: json['id'],
///       title: json['title'],
///       completed: json['completed'],
///     )).toSet();
///   }
/// }
///
/// // Usage
/// final taskRepo = TaskRepository();
///
/// // Add a new task
/// taskRepo.add(Task(id: '1', title: 'Learn Flutter'));
///
/// // Update existing task
/// taskRepo.add(Task(id: '1', title: 'Learn Flutter & Dart'));
///
/// // Listen to changes
/// taskRepo.addListener(() {
///   print('Tasks updated: ${taskRepo.value.length} items');
/// });
///
/// // Remove a task
/// taskRepo.remove(Task(id: '1', title: ''));
/// ```
///
/// ## Type Parameters
///
/// * [ValueType] - The type of items stored in the repository, must implement [GetStorageMethods]
abstract class GetStorageRepository<ValueType extends GetStorageMethods>
    extends GetStorageValueNotifier<Set<ValueType>, String> {
  /// Creates a new [GetStorageRepository] with the specified storage key and default value.
  ///
  /// ## Parameters
  ///
  /// * [key] - The storage key to identify this repository's data
  /// * [defaultValue] - The default set of items when no stored data exists
  /// * [getBox] - Optional custom storage container factory
  GetStorageRepository(super.key, super.defaultValue, {super.getBox});

  /// Adds or updates an item in the repository.
  ///
  /// If an item with the same equality already exists, it will be updated
  /// using the [GetStorageMethods.update] method. If the item is new,
  /// it will be added to the set.
  ///
  /// Returns `1` if the item was added or updated, `0` if no changes were made.
  ///
  /// ## Parameters
  ///
  /// * [item] - The item to add or update
  /// * [notify] - Whether to trigger change notifications (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final task = Task(id: '1', title: 'New Task');
  /// final result = repository.add(task);
  /// print('Changes made: $result'); // 1 if added/updated, 0 if no change
  /// ```
  @mustCallSuper
  int addOrUpdate(ValueType item, {bool notify = true}) {
    var oldValue = value.firstWhereOrNull((e) => e == item);
    if (oldValue != null) {
      if (!(oldValue ^ item)) return 0;
      oldValue.update(item);
    } else {
      value = {...value, item};
    }
    if (notify) notifyListeners();
    return 1;
  }

  /// Adds or updates multiple items in the repository.
  ///
  /// This method efficiently processes multiple items by batching
  /// the operations and triggering notifications only once at the end
  /// if any changes were made.
  ///
  /// ## Parameters
  ///
  /// * [elements] - The items to add or update
  /// * [notify] - Whether to trigger change notifications (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final tasks = [
  ///   Task(id: '1', title: 'Task 1'),
  ///   Task(id: '2', title: 'Task 2'),
  /// ];
  /// repository.addOrUpdateAll(tasks);
  /// ```
  @mustCallSuper
  void addOrUpdateAll(Set<ValueType> elements, {bool notify = true}) {
    int count = 0;
    for (var item in elements) {
      count += addOrUpdate(item, notify: false);
    }
    if (count > 0 && notify) notifyListeners();
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
  int remove(ValueType item, {bool notify = true}) {
    final isDeleted = value.remove(item);
    if (!isDeleted) return 0;

    if (notify) notifyListeners();
    return 1;
  }

  /// Removes multiple items from the repository.
  ///
  /// This method efficiently removes multiple items and returns the
  /// total count of items that were actually removed.
  ///
  /// Returns the number of items that were successfully removed.
  ///
  /// ## Parameters
  ///
  /// * [elements] - The set of items to remove
  /// * [notify] - Whether to trigger change notifications (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final tasksToRemove = {
  ///   Task(id: '1', title: ''),
  ///   Task(id: '2', title: ''),
  /// };
  /// final removedCount = repository.removeAll(tasksToRemove);
  /// print('Removed $removedCount items');
  /// ```
  @nonVirtual
  int removeAll(Set<ValueType> elements, {bool notify = true}) {
    int count = 0;
    for (final element in elements) {
      count += remove(element, notify: notify);
    }

    if (count > 0 && notify) notifyListeners();
    return count;
  }

  /// Returns a stream of the first item that matches the given test.
  /// If no item matches the test, the stream will emit null.
  Stream<ValueType?> streamFirstWhereOrNull(bool Function(ValueType) test) =>
      stream.map((value) => value.firstWhereOrNull(test));

  /// Returns the first item that matches the given test.
  /// If no item matches the test, returns null.
  ValueType? firstWhereOrNull(bool Function(ValueType) test) =>
      value.firstWhereOrNull(test);

  /// Returns a stream of the items that match the given test.
  ///
  /// ## Parameters
  ///
  /// * [test] - The test to filter the items
  ///
  /// ## Returns
  ///
  /// A stream of the items that match the given test.
  Stream<Set<ValueType>> streamWhere(bool Function(ValueType) test) =>
      stream.map((value) => value.where(test).toSet());

  /// Returns a set of items that match the given test.
  ///
  /// ## Parameters
  ///
  /// * [test] - The test to filter the items
  ///
  /// ## Returns
  Set<ValueType> where(bool Function(ValueType) test) =>
      value.where(test).toSet();

  /// Clears the repository and removes all items.
  ///
  /// This method removes all items from the repository and triggers a change
  /// notification.
  ///
  /// Returns the number of items that were removed.
  @mustCallSuper
  int clear({bool notify = true}) {
    final count = value.length;
    value = {};
    if (notify) notifyListeners();
    return count;
  }
}
