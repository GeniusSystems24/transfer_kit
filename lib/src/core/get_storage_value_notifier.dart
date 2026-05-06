import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

/// An abstract base class that combines [ValueNotifier] with [GetStorage] persistence.
///
/// This class provides a reactive way to manage values that are automatically
/// persisted to local storage using the get_storage package. It maintains
/// synchronization between in-memory values and stored values, and provides
/// both [ValueNotifier] and [Stream] interfaces for listening to changes.
///
/// The class uses type converters to transform between the in-memory type
/// ([ValueType]) and the storage type ([StorageType]), allowing for flexible
/// data serialization.
///
/// ## Usage Example
///
/// ```dart
/// // Example: String list stored as comma-separated string
/// class StringListNotifier extends GetStorageValueNotifier<List<String>, String> {
///   StringListNotifier(String key, [List<String>? defaultValue])
///       : super(key, defaultValue ?? []);
///
///   @override
///   String inputConverter(List<String> val) => val.join(',');
///
///   @override
///   List<String> outputConverter(String val) =>
///       val.isEmpty ? [] : val.split(',');
/// }
///
/// // Usage
/// final myList = StringListNotifier('user_tags', ['default']);
/// myList.value = ['tag1', 'tag2', 'tag3']; // Automatically persisted
/// myList.addListener(() => print('List changed: ${myList.value}'));
/// ```
///
/// ## Type Parameters
///
/// * [ValueType] - The type used in memory for the value
/// * [StorageType] - The type used for storage persistence
abstract class GetStorageValueNotifier<ValueType, StorageType>
    extends ValueNotifier<ValueType> {
  final StreamController<ValueType> _streamController =
      StreamController<ValueType>.broadcast();
  late final ReadWriteValue<StorageType> _storage;

  /// Creates a new [GetStorageValueNotifier] with the specified storage key and default value.
  ///
  /// The [key] is used to identify the value in storage, and [defaultValue] is used
  /// when no stored value exists. The optional [getBox] parameter allows using
  /// a custom storage container.
  ///
  /// ## Parameters
  ///
  /// * [key] - The storage key to identify this value
  /// * [defaultValue] - The default value to use when no stored value exists
  /// * [getBox] - Optional custom storage container factory
  GetStorageValueNotifier(
    String key,
    super.defaultValue, {
    StorageFactory? getBox,
  }) {
    _storage = ReadWriteValue<StorageType>(
      key,
      inputConverter(super.value),
      getBox,
    );
    value = outputConverter(_storage.val);
    addListener(reload);
  }

  /// Converts a [ValueType] to [StorageType] for persistence.
  ///
  /// This method must be implemented by subclasses to define how the in-memory
  /// value should be converted to a format suitable for storage.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// String inputConverter(List<String> val) => jsonEncode(val);
  /// ```
  @protected
  StorageType inputConverter(ValueType val);

  /// Converts a [StorageType] to [ValueType] for in-memory use.
  ///
  /// This method must be implemented by subclasses to define how the stored
  /// value should be converted back to the in-memory format.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// List<String> outputConverter(String val) => List<String>.from(jsonDecode(val));
  /// ```
  @protected
  ValueType outputConverter(StorageType val);

  /// Notifies all listeners and persists the current value to storage.
  ///
  /// This method is automatically called when the value changes, but can also
  /// be called manually to force persistence and notification.
  @override
  @mustCallSuper
  void notifyListeners() {
    _storage.val = inputConverter(value);
    super.notifyListeners();
  }

  /// A stream that emits the current value whenever it changes.
  ///
  /// This provides an alternative to [addListener] for reactive programming
  /// patterns. The stream is broadcast, so multiple listeners are supported.
  ///
  /// Example:
  /// ```dart
  /// myNotifier.stream.listen((value) => print('New value: $value'));
  /// ```
  Stream<ValueType> get stream {
    Future.delayed(const Duration(milliseconds: 150), reload);
    return _streamController.stream;
  }

  /// Reloads the current value and notifies stream listeners.
  ///
  /// This method emits the current value to the stream without changing it.
  /// It's automatically called when the value changes via [addListener].
  @protected
  @mustCallSuper
  void reload() {
    if (_streamController.isClosed || _streamController.isPaused) return;
    _streamController.add(value);
  }

  /// Manually triggers notification of all listeners and persistence.
  ///
  /// This is a convenience method that calls [notifyListeners]. Use this
  /// when you need to force an update without changing the value.
  @nonVirtual
  void notify() => notifyListeners();
}
