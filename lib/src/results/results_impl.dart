part of sqljocky;

typedef _OnDone();

class _ResultsImpl extends Results {
  final int insertId;
  final int affectedRows;
  List<Field> _fields;
  List<Row> _rows;
  Stream<Row> _stream;
  _OnDone onDone;

  List<Row> get rows => _rows;
  List<Field> get fields => _fields;
  Stream<Row> get stream => _stream;

  _ResultsImpl(this.insertId, this.affectedRows,
      List<Field> fields,
      {Stream<Row> stream: null,
      List<Row> rows: null}) {
    _fields = new UnmodifiableListView<Field>(fields);
    _rows = new UnmodifiableListView<Row>(rows);
    if (stream != null) {
      this._stream = stream.transform(new _StreamDoneTransformer(() {
        if (onDone != null) {
          onDone();
        }
      }));
    }
  }

  Future<Results> toResultsList() {
    return _stream.toList().then((list) => new _ResultsImpl(insertId, affectedRows, fields, rows: list));
  }
}

class _StreamDoneTransformer extends StreamEventTransformer<Row, Row> {
  var handler;

  _StreamDoneTransformer(this.handler);

  void handleDone(EventSink<Row> sink) {
    handler();
    sink.close();
  }
}