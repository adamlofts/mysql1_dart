import 'dart:collection';

import 'schema.dart';

/// A row of data. Fields can be retrieved by index, or by name.
///
/// When retrieving a field by name, only fields which are valid Dart
/// identifiers, and which aren't part of the List object, can be used.
abstract class ResultRow extends ListBase<dynamic> {
  /// The columns of the result this row is from.
  final ResultSchema schema;

  ResultRow(this.schema);

  /// Values as List
  List<Object?>? values;

  /// Values as Map
  final Map<String, dynamic> fields = <String, dynamic>{};

  @override
  int get length => values?.length ?? 0;

  @override
  set length(int newLength) {
    throw UnsupportedError('Cannot set length of results');
  }

  @override
  dynamic operator [](dynamic index) {
    if (index is int) {
      return values?[index];
    } else {
      return fields[index.toString()];
    }
  }

  @override
  void operator []=(int index, dynamic value) {
    throw UnsupportedError('Cannot modify row');
  }

  /// Whether the value at [columnIndex] is null.
  bool isSqlNull(int columnIndex) => values?[columnIndex] == null;

  /// A map from each column's name to its value in this row. Where two
  /// columns have the same name it has the value of the later one.
  Map<String, dynamic> toColumnMap() => Map.of(fields);

  @override
  String toString() => 'Fields: $fields';
}
