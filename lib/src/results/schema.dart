import 'field.dart';

/// The columns of a result, in the order their values appear in each row.
class ResultSchema {
  final List<ResultSchemaColumn> columns;

  ResultSchema(this.columns);

  /// Where in a row's values each named column is. A name two columns share
  /// is held once, against the later of the two.
  late final Map<String, int> indexByName = {
    for (var i = 0; i < columns.length; i++)
      if (columns[i].name case final name?) name: i
  };

  @override
  String toString() =>
      'ResultSchema(${columns.map((c) => c.columnName).join(', ')})';
}
