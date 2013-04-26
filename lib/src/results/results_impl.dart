part of sqljocky;

class _ResultsImpl extends Results {
  final int insertId;
  final int affectedRows;
  final List<Field> fields;
  List<Row> _rows;
  Stream<Row> _stream;

  List<Row> get rows => _rows;
  Stream<Row> get stream => _stream;

  _ResultsImpl(this.insertId, this.affectedRows,
    List<Field> this.fields,
    {Stream<Row> stream: null,
    List<Row> rows: null}) {
    this._stream = stream;
    this._rows = rows;
  }

  //TODO: rename to toResultsList??
  Future<Results> toList() {
    return _stream.toList().then((list) {
      return new _ResultsImpl(insertId, affectedRows, fields, list: list);
    });
  }
}
