library buffered_socket_test;

import 'package:unittest/unittest.dart';
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
    var list = new List<int>();
    list.addAll(data);
    _data.removeRange(0, count);
    return list;
  }
  
  addData(List<int> data) {
    _data.addAll(data);
    _streamController.add(RawSocketEvent.READ);
  }
  
  InternetAddress get address => null;

  Future<RawSocket> close() {}

  int get port => null;

  bool get readEventsEnabled => null;

  void set readEventsEnabled(bool value) {}

  InternetAddress get remoteAddress => null;

  int get remotePort => null; 

  bool setOption(SocketOption option, bool enabled) {}

  void shutdown(SocketDirection direction) {}

  int write(List<int> buffer, [int offset, int count]) {}

  void set writeEventsEnabled(bool value) {}

  bool get writeEventsEnabled => null;
}

void runBufferedSocketTests() {
  group('buffered socket', () {
    var rawSocket;
    var factory;

    setUp(() {
      var streamController = new StreamController<RawSocketEvent>();
      factory = (host, port) {
        var c = new Completer();
        rawSocket = new MockSocket(streamController);
        c.complete(rawSocket);
        return c.future;
      };
    });
    
    test('can read data which is already available', () {
      var c = new Completer();
      
      var socket;
      BufferedSocket.connect('localhost', 100, 
          onDataReady: (){
            var buffer = new Buffer(4);
            socket.readBuffer(buffer).then((_) {
              expect(buffer.list, equals([1, 2, 3, 4]));
              c.complete();
            });
          }, onDone: (){}, onError: (e){}, socketFactory: factory).then((thesocket) {
            socket = thesocket;
            rawSocket.addData([1, 2, 3, 4]);
          });
      return c.future;
    });

    test('can read data which is partially available', () {
      var c = new Completer();
      
      var socket;
      BufferedSocket.connect('localhost', 100, 
          onDataReady: (){
            var buffer = new Buffer(4);
            socket.readBuffer(buffer).then((_) {
              expect(buffer.list, equals([1, 2, 3, 4]));
              c.complete();
            });
            rawSocket.addData([3, 4]);
          }, onDone: (){}, onError: (e){}, socketFactory: factory).then((thesocket) {
            socket = thesocket;
            rawSocket.addData([1, 2]);
          });
      return c.future;
    });

    test('can read data which is not yet available', () {
      var c = new Completer();
      
      var socket;
      BufferedSocket.connect('localhost', 100, 
          onDataReady: (){
          }, onDone: (){}, onError: (e){}, socketFactory: factory).then((thesocket) {
            socket = thesocket;
            var buffer = new Buffer(4);
            socket.readBuffer(buffer).then((_) {
              expect(buffer.list, equals([1, 2, 3, 4]));
              c.complete();
            });
            rawSocket.addData([1, 2, 3, 4]);
          });
      return c.future;
    });

    test('can read data which is not yet available, arriving in two chunks', () {
      var c = new Completer();
      
      BufferedSocket.connect('localhost', 100, 
          onDataReady: (){
          }, onDone: (){}, onError: (e){}, socketFactory: factory).then((socket) {
            var buffer = new Buffer(4);
            socket.readBuffer(buffer).then((_) {
              expect(buffer.list, equals([1, 2, 3, 4]));
              c.complete();
            });
            rawSocket.addData([1, 2]);
            rawSocket.addData([3, 4]);
          });
      return c.future;
    });

    test('cannot read data when already reading', () {
      var c = new Completer();
      
      BufferedSocket.connect('localhost', 100, 
          onDataReady: (){
          }, onDone: (){}, onError: (e){}, socketFactory: factory).then((socket) {
            var buffer = new Buffer(4);
            socket.readBuffer(buffer).then((_) {
              expect(buffer.list, equals([1, 2, 3, 4]));
            });
            expect(() {
              socket.readBuffer(buffer); 
            }, throwsA(new isInstanceOf<StateError>()));
            c.complete();
          });
      return c.future;
    });
  });
}

void main() {
//  hierarchicalLoggingEnabled = true;
//  Logger.root.level = Level.ALL;
//  var listener = (LogRecord r) {
//    var name = r.loggerName;
//    if (name.length > 15) {
//      name = name.substring(0, 15);
//    }
//    while (name.length < 15) {
//      name = "$name ";
//    }
//    print("${r.time}: $name: ${r.message}");
//  };
//  Logger.root.onRecord.listen(listener);

  runBufferedSocketTests();
}
