// ignore_for_file: strong_mode_implicit_dynamic_list_literal, strong_mode_implicit_dynamic_parameter, argument_type_not_assignable, invalid_assignment, non_bool_condition, strong_mode_implicit_dynamic_variable, deprecated_member_use

library mysql1.test.unit.connection_test;

import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:mysql1/src/buffer.dart';
import 'package:mysql1/src/buffered_socket.dart';
import 'package:mysql1/src/mysql_client_error.dart';

import 'package:mysql1/src/single_connection.dart';
import 'package:test/test.dart';

class FakeBuffer extends Fake implements Buffer {}

void main() {
  late final FakeBuffer fakeBuffer;

  setUpAll(() {
    fakeBuffer = FakeBuffer();
    registerFallbackValue<Buffer>(fakeBuffer);
  });

  group('Connection', () {
    test('should throw error if buffer is too big', () {
      final MAX_PACKET_SIZE = 10;
      var socket = MockSocket();
      var cnx = ReqRespConnection(socket, null, null, MAX_PACKET_SIZE);
      final PACKET_SIZE = 11;
      var buffer = Buffer(PACKET_SIZE);
      expect(() {
        cnx.sendBuffer(buffer);
      }, throwsA(isInstanceOf<MySqlClientError>()));
    });

    test(
      'should send buffer',
      () async {
        final MAX_PACKET_SIZE = 16 * 1024 * 1024;
        var socket = MockSocket();
        var cnx = ReqRespConnection(socket, null, null, MAX_PACKET_SIZE);
        when(() => socket.writeBuffer(any<Buffer>()))
            .thenAnswer((_) => Future<Buffer>.value(fakeBuffer));
        when(() =>
                socket.writeBufferPart(any<Buffer>(), any<int>(), any<int>()))
            .thenAnswer((_) => Future<Buffer>.value(fakeBuffer));

        var buffer = Buffer.fromList([1, 2, 3]);
        await cnx.sendBuffer(buffer);
        var captured =
            verify(() => socket.writeBuffer(captureAny<Buffer>())).captured;
        expect(captured[0], hasLength(4));
        expect(captured[0].list, equals([3, 0, 0, 1]));
        captured = verify(() => socket.writeBufferPart(
                captureAny<Buffer>(), captureAny<int>(), captureAny<int>()))
            .captured;
        expect(captured[0].list, equals([1, 2, 3]));
        expect(captured[1], equals(0));
        expect(captured[2], equals(3));

        buffer = Buffer.fromList([1, 2, 3]);
        await cnx.sendBuffer(buffer);
        captured =
            verify(() => socket.writeBuffer(captureAny<Buffer>())).captured;
        expect(captured[0], hasLength(4));
        expect(captured[0].list, equals([3, 0, 0, 2]));
        captured = verify(() => socket.writeBufferPart(
                captureAny<Buffer>(), captureAny<int>(), captureAny<int>()))
            .captured;
        expect(captured[0].list, equals([1, 2, 3]));
        expect(captured[1], equals(0));
        expect(captured[2], equals(3));
      },
    );

    test(
      'should send large buffer',
      () async {
        final MAX_PACKET_SIZE = 32 * 1024 * 1024;
        var socket = MockSocket();
        var cnx = ReqRespConnection(socket, null, null, MAX_PACKET_SIZE);

        /* FIXME(rxlabz) */
        var buffers = [];
        when(() => socket.writeBuffer(any<Buffer>())).thenAnswer((mirror) {
          var buffer = mirror.positionalArguments[0];
          buffers.add(List<int>.from(buffer.list));
          return Future.value(fakeBuffer);
        });
        when(() =>
                socket.writeBufferPart(any<Buffer>(), any<int>(), any<int>()))
            .thenAnswer((_) => Future<Buffer>.value(fakeBuffer));

        final PACKET_SIZE = 17 * 1024 * 1024;
        var buffer = Buffer(PACKET_SIZE);
        await cnx.sendBuffer(buffer);
        verify(() => socket.writeBuffer(any<Buffer>())).called(2);
        expect(buffers[0], equals([0xff, 0xff, 0xff, 1]));
        expect(buffers[1], equals([1, 0, 16, 2]));
        var captured = verify(
          () => socket.writeBufferPart(
              captureAny<Buffer>(), captureAny<int>(), captureAny<int>()),
        ).captured;
        expect(captured, hasLength(6));
        expect(captured[1], equals(0));
        expect(captured[2], equals(0xffffff));
        expect(captured[4], equals(0xffffff));
        expect(captured[5], equals(PACKET_SIZE - 0xffffff));
      },
    );

//    test('should receive buffer', () async {
//      final MAX_PACKET_SIZE = 16 * 1024 * 1024;
//      var socket = MockSocket();
//      var cnx = ReqRespConnection(
//          socket, MAX_PACKET_SIZE, null, null, null, false, false, null);
//
//      var c = Completer();
//
//      var buffer;
//      cnx.dataHandler = (newBuffer) {
//        buffer = newBuffer;
//        c.complete();
//      };
//
//      var bufferReturnCount = 0;
//      when(socket.readBuffer(any)).thenAnswer((_) async {
//        if (bufferReturnCount == 0) {
//          bufferReturnCount++;
//          return Buffer.fromList([3, 0, 0, 1]);
//        } else {
//          bufferReturnCount++;
//          return Buffer.fromList([1, 2, 3]);
//        }
//      }); // 2
//
//      cnx.readPacket();
//
//      await c.future;
//
//      verify(socket.readBuffer(any)).called(2);
//      expect(buffer.list, equals([1, 2, 3]));
//    }, skip: "API Update");
//
//    test('should receive large buffer', () async {
//      final MAX_PACKET_SIZE = 32 * 1024 * 1024;
//      var socket = MockSocket();
//      var cnx = ReqRespConnection(
//          socket, MAX_PACKET_SIZE, null, null, null, false, false, null);
//
//      var c = Completer();
//
//      var buffer;
//      cnx.dataHandler = (newBuffer) {
//        buffer = newBuffer;
//        c.complete();
//      };
//
//      var bufferReturnCount = 0;
//      var bufferReturn = (_) {
//        if (bufferReturnCount == 0) {
//          bufferReturnCount++;
//          return Future.value(Buffer.fromList([0xff, 0xff, 0xff, 1]));
//        } else if (bufferReturnCount == 1) {
//          bufferReturnCount++;
//          var bigBuffer = Buffer(0xffffff);
//          bigBuffer.list[0] = 1;
//          bigBuffer.list[0xffffff - 1] = 2;
//          return Future.value(bigBuffer);
//        } else if (bufferReturnCount == 2) {
//          bufferReturnCount++;
//          return Future.value(Buffer.fromList([3, 0, 0, 2]));
//        } else {
//          bufferReturnCount++;
//          var bufferSize = 17 * 1024 * 1024 - 0xffffff;
//          var littleBuffer = Buffer(bufferSize);
//          littleBuffer[0] = 3;
//          littleBuffer[bufferSize - 1] = 4;
//          return Future.value(littleBuffer);
//        }
//      };
//      when(socket.readBuffer(any)).thenAnswer(bufferReturn); // 4
//
//      cnx.readPacket();
//
//      await c.future;
//      verify(socket.readBuffer(any)).called(4);
//      expect(buffer.list.length, equals(17 * 1024 * 1024));
//      expect(buffer.list[0], equals(1));
//      expect(buffer.list[0xffffff - 1], equals(2));
//      expect(buffer.list[0xffffff], equals(3));
//      expect(buffer.list[buffer.list.length - 1], equals(4));
//    }, skip: "API Update");
  });
}

class MockSocket extends Mock implements BufferedSocket {}
