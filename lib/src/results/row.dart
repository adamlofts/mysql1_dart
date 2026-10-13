import 'dart:collection';

import 'schema.dart';

/// A row of data. Values can be read by index, or by column name.
///
/// A name no column of the result has reads as null.
abstract class ResultRow extends ListBase<dynamic> {
  /// The columns of the result this row is from.
  final ResultSchema schema;

  ResultRow(this.schema);

  /// The values of this row, in the order [schema] gives the columns.
  List<Object?>? values;

  /// What [toColumnMap] returns, under the name it had before.
  @Deprecated('Use toColumnMap()')
  Map<String, dynamic> get fields => toColumnMap();

  @override
  int get length => values?.length ?? 0;

  @override
  set length(int newLength) {
    throw UnsupportedError('Cannot set length of results');
  }

  @override
  dynamic operator [](Object? index) {
    final column = index is int ? index : schema.indexByName[index.toString()];
    return column == null ? null : values?[column];
  }

  @override
  void operator []=(int index, dynamic value) {
    throw UnsupportedError('Cannot modify row');
  }

  /// Whether the value at [columnIndex] is null.
  bool isSqlNull(int columnIndex) => values?[columnIndex] == null;

  /// A map from each column's name to its value in this row. Where two
  /// columns have the same name it has the value of the later one.
  Map<String, dynamic> toColumnMap() => {
        for (final column in schema.indexByName.entries)
          column.key: values?[column.value]
      };

  @override
  String toString() => 'ResultRow(${toColumnMap()})';
}
