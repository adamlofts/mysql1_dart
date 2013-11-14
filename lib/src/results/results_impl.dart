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
      })).transform(new MyTransformer((controller) {
        controller.close();
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
}

class MyTransformer implements StreamTransformer {
  var onDoneOrCancelled;
  
  MyTransformer(this.onDoneOrCancelled);
  
  Stream bind(Stream stream) {
    StreamController<Row> controller;
    StreamSubscription<Row> subscription;

    controller = new StreamController(onCancel: () {
        return new Future.microtask(() {
          onDoneOrCancelled(controller);
        });
      },
      onPause: () {
        subscription.pause();
      },
      onResume: () {
        subscription.resume();
      });
    
    subscription = stream.listen((data) {
        controller.add(data);
      },
      onError: controller.addError,
      onDone: () {
        onDoneOrCancelled(controller);
      });
    
    return controller.stream;
  }
}
