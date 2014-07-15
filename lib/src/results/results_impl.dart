part of sqljocky;

class _ResultsImpl extends StreamView<Row> implements Results {
  final int insertId;
  final int affectedRows;
  List<Field> _fields;

  List<Field> get fields => _fields;

  factory _ResultsImpl(int insertId, int affectedRows,
      List<Field> fields,
      {Stream<Row> stream: null}) {
    if (stream != null) {
      var newStream = stream.transform(new StreamTransformer.fromHandlers(handleDone: (EventSink<Row> sink) {
        sink.close();
      }));
      return new _ResultsImpl._fromStream(insertId, affectedRows, fields, newStream);
    } else {
      var newStream = new Stream.fromIterable(new List<Row>());
      return new _ResultsImpl._fromStream(insertId, affectedRows, fields, newStream);
    }
  }
  
  _ResultsImpl._fromStream(this.insertId, this.affectedRows, List<Field> fields,
    Stream<Row> stream) : super(stream) {
    _fields = new UnmodifiableListView<Field>(fields);
  }

  /**
   * Takes a _ResultsImpl and destreams it. That is, it listens to the stream, collecting
   * all the rows into a list until the stream has finished. It then returns a new
   * _ResultsImpl which wraps that list of rows.
   */
  static Future<_ResultsImpl> destream(_ResultsImpl results) {
    var rows = new List<Row>();
    return results.forEach((row) {
      rows.add(row);
    }).then((_) {
      var newStream = new Stream<Row>.fromIterable(rows);
      return new _ResultsImpl._fromStream(results.insertId, results.affectedRows,
        results.fields, newStream);
    });
  }
}
