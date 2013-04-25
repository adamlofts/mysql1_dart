part of sqljocky;

class _ResultsImpl extends Results {
  final int insertId;
  final int affectedRows;
  final List<Field> fields;
  final List<Row> _rows;
  Stream<Row> _stream;

  _ResultsImpl._(this.insertId, this.affectedRows,
    List<Field> this.fields,
    List<Row> this._rows,
    [Stream<Row> stream]) {
    if (?stream) {
      _stream = stream;
    }
  }

  Stream<Row> get stream => _stream;

  int get length => _rows.length;

  void set length(int newLength) {
    throw new UnsupportedError("Cannot change length");
  }

  Row operator[](int index) => _rows[index];

  void operator[]=(int index, Row value) {
    throw new UnsupportedError("Cannot change results");
  }
}
