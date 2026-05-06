import 'package:flutter/foundation.dart';

/// A Map that notifies listeners when values are added, updated, or removed.
///
/// Extends ChangeNotifier to provide reactive updates for map changes.
class MapNotifier<K, V> extends ChangeNotifier {
  /// The internal map storage
  Map<K, V> _value;

  /// Creates a MapNotifier with an optional initial map
  MapNotifier([Map<K, V>? initial]) : _value = initial ?? {};

  /// Gets the current map value
  Map<K, V> get value => _value;

  /// Sets the entire map value and notifies listeners
  set value(Map<K, V> newValue) {
    _value = newValue;
    notifyListeners();
  }

  /// Gets a value by key
  V? operator [](K key) => _value[key];

  /// Sets a value by key and notifies listeners
  void operator []=(K key, V value) {
    _value[key] = value;
    notifyListeners();
  }

  /// Adds a key-value pair and returns the value
  V add(K key, V value) {
    _value[key] = value;
    notifyListeners();
    return value;
  }

  /// Removes a key-value pair and notifies listeners
  V? remove(K key) {
    final removed = _value.remove(key);
    if (removed != null) {
      notifyListeners();
    }
    return removed;
  }

  /// Clears all entries and notifies listeners
  void clear() {
    if (_value.isNotEmpty) {
      _value.clear();
      notifyListeners();
    }
  }

  /// Checks if the map contains a key
  bool containsKey(K key) => _value.containsKey(key);

  /// Checks if the map contains a value
  bool containsValue(V value) => _value.containsValue(value);

  /// Gets all keys
  Iterable<K> get keys => _value.keys;

  /// Gets all values
  Iterable<V> get values => _value.values;

  /// Gets all entries
  Iterable<MapEntry<K, V>> get entries => _value.entries;

  /// Gets the number of entries
  int get length => _value.length;

  /// Checks if the map is empty
  bool get isEmpty => _value.isEmpty;

  /// Checks if the map is not empty
  bool get isNotEmpty => _value.isNotEmpty;

  /// Updates a value with a function
  void update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    _value.update(key, update, ifAbsent: ifAbsent);
    notifyListeners();
  }

  /// Adds all entries from another map
  void addAll(Map<K, V> other) {
    if (other.isNotEmpty) {
      _value.addAll(other);
      notifyListeners();
    }
  }

  /// Removes entries that match the predicate
  void removeWhere(bool Function(K key, V value) predicate) {
    final originalLength = _value.length;
    _value.removeWhere(predicate);
    if (_value.length != originalLength) {
      notifyListeners();
    }
  }

  /// Iterates over each entry
  void forEach(void Function(K key, V value) action) {
    _value.forEach(action);
  }
}
