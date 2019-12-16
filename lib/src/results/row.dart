library mysql1.row;

import 'dart:collection';

import 'field.dart';
import '../buffer.dart';

/// A row of data. Fields can be retrieved by index, or by name.
///
/// When retrieving a field by name, only fields which are valid Dart
/// identifiers, and which aren't part of the List object, can be used.
abstract class Row extends ListBase<dynamic> {
  /// Values as List
  List<dynamic> values;

  /// Values as Map
  final Map<String, dynamic> fields = <String, dynamic>{};

  @override
  int get length => values.length;

  @override
  set length(int newLength) {
    throw UnsupportedError('Cannot set length of results');
  }

  @override
  dynamic operator [](dynamic index) {
    if (index is int) {
      return values[index];
    } else {
      return fields[index.toString()];
    }
  }

  @override
  void operator []=(int index, dynamic value) {
    throw UnsupportedError('Cannot modify row');
  }

  @override
  String toString() => 'Fields: $fields';

  Object readField(Field field, Buffer buffer);
}
