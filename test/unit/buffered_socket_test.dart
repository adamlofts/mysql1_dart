// ignore_for_file: strong_mode_implicit_dynamic_list_literal, strong_mode_implicit_dynamic_parameter, argument_type_not_assignable, invalid_assignment, non_bool_condition, strong_mode_implicit_dynamic_variable, deprecated_member_use, strong_mode_implicit_dynamic_type
library buffered_socket_test;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:mockito/mockito.dart';
import 'package:pedantic/pedantic.dart';
import 'package:test/test.dart';

import 'package:mysql1/src/buffered_socket.dart';
import 'package:mysql1/src/buffer.dart';

class MockSocket extends StreamView<RawSocketEvent> implements RawSocket {
  MockSocket(StreamController<RawSocketEvent> streamController)
      : super(streamController.stream) {
    _streamController = streamController;
    _data = <int>[];
  }

  StreamController<RawSocketEvent> _streamController;
  List<int> _data;
  @override
  int available() => _data.length;

  @override
  Uint8List read([int len]) {
    var count = len;
    if (count > _data.length) {
      count = _data.length;
    }
    var data = _data.getRange(0, count);
    var list = Uint8List(data.length);
    list.setRange(0, data.length, data);
    _data.removeRange(0, count);
    return list;
  }

  void addData(List<int> data) {
    _data.addAll(data);
    _streamController.add(RawSocketEvent.READ);
  }

  void closeRead() {
    _streamController.add(RawSocketEvent.READ_CLOSED);
  }

  @override
  set writeEventsEnabled(bool value) {
    if (value) {
      _streamController.add(RawSocketEvent.WRITE);
    }
  }

  @override
  bool setOption(SocketOption option, bool enabled) => true; // No-op

  @override
  Object noSuchMethod(a) => super.noSuchMethod(a);
}

class MockBuffer extends Mock implements Buffer {}

void main() {
  group('buffered socket', () {
    var rawSocket;
    SocketFactory factory;

    setUp(() {
      var streamController = StreamController<RawSocketEvent>();
      factory = (host, port, timeout, {bool isUnixSocket}) {
        rawSocket = MockSocket(streamController);
        return Future.value(rawSocket);
      };
    });

    test('can read data which is already available', () async {
      var c = Completer();

      var socket;
      var thesocket = await BufferedSocket.connect(
          'localhost', 100, const Duration(seconds: 5), onDataReady: () async {
        var buffer = Buffer(4);
        await socket.readBuffer(buffer);
        expect(buffer.list, equals([1, 2, 3, 4]));
        c.complete();
      }, onDone: () {}, onError: (e) {}, socketFactory: factory);
      socket = thesocket;
      rawSocket.addData([1, 2, 3, 4]);
      return c.future;
    });

    test('can read data which is partially available', () async {
      var c = Completer();

      var socket;
      var thesocket = await BufferedSocket.connect(
          'localhost', 100, const Duration(seconds: 5), onDataReady: () async {
        var buffer = Buffer(4);
        socket.readBuffer(buffer).then((_) {
          expect(buffer.list, equals([1, 2, 3, 4]));
          c.complete();
        });
        rawSocket.addData([3, 4]);
      }, onDone: () {}, onError: (e) {}, socketFactory: factory);
      socket = thesocket;
      rawSocket.addData([1, 2]);
      return c.future;
    });

    test('can read data which is not yet available', () async {
      var c = Completer();
      var socket = await BufferedSocket.connect(
          'localhost', 100, const Duration(seconds: 5),
          onDataReady: () {},
          onDone: () {},
          onError: (e) {},
          socketFactory: factory);
      var buffer = Buffer(4);
      unawaited(socket.readBuffer(buffer).then((_) {
        expect(buffer.list, equals([1, 2, 3, 4]));
        c.complete();
      }));
      rawSocket.addData([1, 2, 3, 4]);
      return c.future;
    });

    test('can read data which is not yet available, arriving in two chunks',
        () async {
      var c = Completer();
      var socket = await BufferedSocket.connect(
          'localhost', 100, const Duration(seconds: 30),
          onDataReady: () {},
          onDone: () {},
          onError: (e) {},
          socketFactory: factory);
      var buffer = Buffer(4);
      unawaited(socket.readBuffer(buffer).then((_) {
        expect(buffer.list, equals([1, 2, 3, 4]));
        c.complete();
      }));
      rawSocket.addData([1, 2]);
      rawSocket.addData([3, 4]);
      return c.future;
    });

    test('cannot read data when already reading', () async {
      var socket = await BufferedSocket.connect(
          'localhost', 100, const Duration(seconds: 5),
          onDataReady: () {},
          onDone: () {},
          onError: (e) {},
          socketFactory: factory);
      var buffer = Buffer(4);
      unawaited(socket.readBuffer(buffer).then((_) {
        expect(buffer.list, equals([1, 2, 3, 4]));
      }));
      expect(() {
        socket.readBuffer(buffer);
      }, throwsA(isInstanceOf<StateError>()));
    });

    test('should write buffer', () async {
      var socket = await BufferedSocket.connect(
          'localhost', 100, const Duration(seconds: 5),
          onDataReady: () {},
          onDone: () {},
          onError: (e) {},
          socketFactory: factory);
      var buffer = MockBuffer();
      when(buffer.length).thenReturn(100);
      when(buffer.writeToSocket(any, any, any)).thenReturn(25);
      await socket.writeBuffer(buffer);
      verify(buffer.writeToSocket(any, any, any)).called(4);
    });

    test('should write part of buffer', () async {
      var socket = await BufferedSocket.connect(
          'localhost', 100, const Duration(seconds: 5),
          onDataReady: () {},
          onDone: () {},
          onError: (e) {},
          socketFactory: factory);
      var buffer = MockBuffer();
      when(buffer.length).thenReturn(100);
      when(buffer.writeToSocket(any, any, any)).thenReturn(25);
      await socket.writeBufferPart(buffer, 25, 50);
      verify(buffer.writeToSocket(any, any, any)).called(2);
    });

    test('should send close event', () async {
      var closed = false;
      var onClosed = () {
        closed = true;
      };
      await BufferedSocket.connect('localhost', 100, const Duration(seconds: 5),
          onDataReady: () {},
          onDone: () {},
          onError: (e) {},
          onClosed: onClosed,
          socketFactory: factory);
      await rawSocket.closeRead();
      expect(closed, equals(true));
    });
  });
}
