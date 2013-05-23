library buffered_socket_test;

import 'package:unittest/unittest.dart';
import 'package:unittest/mock.dart';
import 'package:logging/logging.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';

import 'package:sqljocky/src/buffered_socket.dart';
import 'package:sqljocky/src/buffer.dart';

class MockSocket extends StreamView<RawSocketEvent> implements RawSocket {
    MockSocket(StreamController<RawSocketEvent> streamController) :
      super(streamController.stream) {
    _streamController = streamController;
    _data = new List<int>();
  }
    
  StreamController<RawSocketEvent> _streamController;
  List<int> _data;
  int available() => _data.length;
  
  List<int> read([int len])  {
    var count = len;
    if (count > _data.length) {
      count = _data.length;
    }
    var data = _data.getRange(0, count);
    _data.removeRange(0, count);
    return data;
  }
  
  addData(List<int> data) {
    _data.addAll(data);
    _streamController.add(RawSocketEvent.READ);
  }
}

void runBufferedSocketTests() {
  group('buffer:', () {
    test('can write byte to buffer', () {
      var c = new Completer();
      var streamController = new StreamController<RawSocketEvent>();
      
      var rawSocket;
      var factory = (host, port) {
        var c = new Completer();
        rawSocket = new MockSocket(streamController);
        c.complete(rawSocket);
        return c.future;
      };
      
      var socket;
      BufferedSocket.connect('localhost', 100, 
          onDataReady: (){
            print("data ready");
            var buffer = new Buffer(4);
            socket.readBuffer(buffer).then((_) {
              print("read");
              expect(buffer, equals([1, 2, 3, 4]));
              c.complete();
            });
          }, onDone: (){}, onError: (e){}, socketFactory: factory).then((thesocket) {
            print("connected");
            socket = thesocket;
            rawSocket.addData([1, 2, 3, 4]);
          });
      return c.future;
    });
  });
}

void main() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.ALL;
  var listener = (LogRecord r) {
    var name = r.loggerName;
    if (name.length > 15) {
      name = name.substring(0, 15);
    }
    while (name.length < 15) {
      name = "$name ";
    }
    print("${r.time}: $name: ${r.message}");
  };
  Logger.root.onRecord.listen(listener);

  runBufferedSocketTests();
}
