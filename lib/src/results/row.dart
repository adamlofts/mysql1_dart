library mysql1.row;

import 'dart:collection';

import 'field.dart';
import '../buffer.dart';

/**
 * A row of data. Fields can be retrieved by index, or by name.
 *
 * When retrieving a field by name, only fields which are valid Dart
 * identifiers, and which aren't part of the List object, can be used.
 */
abstract class Row extends ListBase<dynamic> {
  /// Values as List
  List<dynamic> values;

  /// Values as Map
  final Map<String, dynamic> fields = <String, dynamic>{};

  int get length => values.length;

  set length(int newLength) {
    throw new UnsupportedError("Cannot set length of results");
  }

  dynamic operator [](dynamic index) {
    if (index is int) {
      return values[index];
    } else {
      return fields[index.toString()];
    }
  }

  void operator []=(int index, dynamic value) {
    throw new UnsupportedError("Cannot modify row");
  }

  String toString() => "Fields: $fields";

  Object readField(Field field, Buffer buffer);
}
