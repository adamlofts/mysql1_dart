library sqljocky.test.unit.connection_test;

import 'dart:async';

import 'package:mockito/mockito.dart';

//import 'package:sqljocky5/src/connection.dart';
import 'package:sqljocky5/src/buffer.dart';
import 'package:sqljocky5/src/buffered_socket.dart';
import 'package:sqljocky5/src/mysql_client_error.dart';

import 'package:sqljocky5/src/single_connection.dart';
import 'package:test/test.dart';

void main() {
  group('Connection', () {
    test('should throw error if buffer is too big', () {
      final MAX_PACKET_SIZE = 10;
      var cnx = new ReqRespConnection(null, null, null, MAX_PACKET_SIZE);
      final PACKET_SIZE = 11;
      var buffer = new Buffer(PACKET_SIZE);
      expect(() {
        cnx.sendBuffer(buffer);
      }, throwsA(new isInstanceOf<MySqlClientError>()));
    });

    test('should send buffer', () async {
      final MAX_PACKET_SIZE = 16 * 1024 * 1024;
      var socket = new MockSocket();
      var cnx = new ReqRespConnection(socket, null, null, MAX_PACKET_SIZE);

      when(socket.writeBuffer(any)).thenReturn(new Future.value());
      when(socket.writeBufferPart(any, any, any))
          .thenReturn(new Future.value());

      var buffer = new Buffer.fromList([1, 2, 3]);
      await cnx.sendBuffer(buffer);
      var captured = verify(socket.writeBuffer(captureAny)).captured;
      expect(captured[0], hasLength(4));
      expect(captured[0].list, equals([3, 0, 0, 1]));
      captured =
          verify(socket.writeBufferPart(captureAny, captureAny, captureAny))
              .captured;
      expect(captured[0].list, equals([1, 2, 3]));
      expect(captured[1], equals(0));
      expect(captured[2], equals(3));

      buffer = new Buffer.fromList([1, 2, 3]);
      await cnx.sendBuffer(buffer);
      captured = verify(socket.writeBuffer(captureAny)).captured;
      expect(captured[0], hasLength(4));
      expect(captured[0].list, equals([3, 0, 0, 2]));
      captured =
          verify(socket.writeBufferPart(captureAny, captureAny, captureAny))
              .captured;
      expect(captured[0].list, equals([1, 2, 3]));
      expect(captured[1], equals(0));
      expect(captured[2], equals(3));
    });

    test('should send large buffer', () async {
      final MAX_PACKET_SIZE = 32 * 1024 * 1024;
      var socket = new MockSocket();
      var cnx = new ReqRespConnection(socket, null, null, MAX_PACKET_SIZE);

      var buffers = [];
      when(socket.writeBuffer(any)).thenAnswer((mirror) {
        var buffer = mirror.positionalArguments[0];
        buffers.add(new List.from(buffer.list));
        return new Future.value();
      });
      when(socket.writeBufferPart(any, any, any))
          .thenReturn(new Future.value());

      final PACKET_SIZE = 17 * 1024 * 1024;
      var buffer = new Buffer(PACKET_SIZE);
      await cnx.sendBuffer(buffer);
      verify(socket.writeBuffer(any)).called(2);
      expect(buffers[0], equals([0xff, 0xff, 0xff, 1]));
      expect(buffers[1], equals([1, 0, 16, 2]));
      var captured =
          verify(socket.writeBufferPart(captureAny, captureAny, captureAny))
              .captured;
      expect(captured, hasLength(6));
      expect(captured[1], equals(0));
      expect(captured[2], equals(0xffffff));
      expect(captured[4], equals(0xffffff));
      expect(captured[5], equals(PACKET_SIZE - 0xffffff));
    });

    test('should receive buffer', () async {
      final MAX_PACKET_SIZE = 16 * 1024 * 1024;
      var socket = new MockSocket();
      var cnx = new ReqRespConnection(
          socket, MAX_PACKET_SIZE, null, null, null, false, false, null);

      var c = new Completer();

      var buffer;
      cnx.dataHandler = (newBuffer) {
        buffer = newBuffer;
        c.complete();
      };

      var bufferReturnCount = 0;
      when(socket.readBuffer(any)).thenAnswer((_) async {
        if (bufferReturnCount == 0) {
          bufferReturnCount++;
          return new Buffer.fromList([3, 0, 0, 1]);
        } else {
          bufferReturnCount++;
          return new Buffer.fromList([1, 2, 3]);
        }
      }); // 2

      cnx.readPacket();

      await c.future;

      verify(socket.readBuffer(any)).called(2);
      expect(buffer.list, equals([1, 2, 3]));
    }, skip: "API Update");

    test('should receive large buffer', () async {
      final MAX_PACKET_SIZE = 32 * 1024 * 1024;
      var socket = new MockSocket();
      var cnx = new ReqRespConnection(
          socket, MAX_PACKET_SIZE, null, null, null, false, false, null);

      var c = new Completer();

      var buffer;
      cnx.dataHandler = (newBuffer) {
        buffer = newBuffer;
        c.complete();
      };

      var bufferReturnCount = 0;
      var bufferReturn = (_) {
        if (bufferReturnCount == 0) {
          bufferReturnCount++;
          return new Future.value(new Buffer.fromList([0xff, 0xff, 0xff, 1]));
        } else if (bufferReturnCount == 1) {
          bufferReturnCount++;
          var bigBuffer = new Buffer(0xffffff);
          bigBuffer.list[0] = 1;
          bigBuffer.list[0xffffff - 1] = 2;
          return new Future.value(bigBuffer);
        } else if (bufferReturnCount == 2) {
          bufferReturnCount++;
          return new Future.value(new Buffer.fromList([3, 0, 0, 2]));
        } else {
          bufferReturnCount++;
          var bufferSize = 17 * 1024 * 1024 - 0xffffff;
          var littleBuffer = new Buffer(bufferSize);
          littleBuffer[0] = 3;
          littleBuffer[bufferSize - 1] = 4;
          return new Future.value(littleBuffer);
        }
      };
      when(socket.readBuffer(any)).thenAnswer(bufferReturn); // 4

      cnx.readPacket();

      await c.future;
      verify(socket.readBuffer(any)).called(4);
      expect(buffer.list.length, equals(17 * 1024 * 1024));
      expect(buffer.list[0], equals(1));
      expect(buffer.list[0xffffff - 1], equals(2));
      expect(buffer.list[0xffffff], equals(3));
      expect(buffer.list[buffer.list.length - 1], equals(4));
    }, skip: "API Update");
  });
}

class MockSocket extends Mock implements BufferedSocket {
  noSuchMethod(a) => super.noSuchMethod(a);
}
