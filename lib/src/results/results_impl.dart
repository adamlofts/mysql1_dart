part of sqljocky;

class _ResultsImpl extends Results {
  final int insertId;
  final int affectedRows;
  final List<Field> fields;
  final List<Row> rows;

  _ResultsImpl._(this.insertId, this.affectedRows,
    List<Field> this.fields,
    List<Row> this.rows);
}
