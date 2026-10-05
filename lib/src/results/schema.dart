import 'field.dart';

/// The columns of a result, in the order their values appear in each row.
class ResultSchema {
  final List<ResultSchemaColumn> columns;

  ResultSchema(this.columns);

  @override
  String toString() =>
      'ResultSchema(${columns.map((c) => c.columnName).join(', ')})';
}
