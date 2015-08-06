part of sqljocky;

void runConnectionTests() {
  group('Connection', () {
    test('should throw error if buffer is too big', () {
      final MAX_PACKET_SIZE = 10;
      var cnx = new _Connection(null, 15, MAX_PACKET_SIZE);
      final PACKET_SIZE = 11;
      var buffer = new Buffer(PACKET_SIZE);
      expect(() {
        cnx._sendBuffer(buffer);
      }, throwsA(new isInstanceOf<MySqlClientError>()));
    });

    test('should send buffer', () async {
      final MAX_PACKET_SIZE = 16 * 1024 * 1024;
      var cnx = new _Connection(null, 15, MAX_PACKET_SIZE);
      var socket = new MockSocket();
      cnx._socket = socket;

      socket.when(callsTo('writeBuffer')).alwaysReturn(new Future.value());
      socket.when(callsTo('writeBufferPart')).alwaysReturn(new Future.value());

      var buffer = new Buffer.fromList([1, 2, 3]);
      await cnx._sendBuffer(buffer);
      socket.getLogs(callsTo('writeBuffer')).verify(happenedExactly(1));
      socket.getLogs(callsTo('writeBufferPart')).verify(happenedExactly(1));
      expect(socket.getLogs(callsTo('writeBuffer')).logs[0].args[0].list, equals([3, 0, 0, 1]));
      expect(socket.getLogs(callsTo('writeBufferPart')).logs[0].args[0].list, equals([1, 2, 3]));
      expect(socket.getLogs(callsTo('writeBufferPart')).logs[0].args[1], equals(0));
      expect(socket.getLogs(callsTo('writeBufferPart')).logs[0].args[2], equals(3));

      buffer = new Buffer.fromList([1, 2, 3]);
      await cnx._sendBuffer(buffer);
      socket.getLogs(callsTo('writeBuffer')).verify(happenedExactly(2));
      socket.getLogs(callsTo('writeBufferPart')).verify(happenedExactly(2));
      expect(socket.getLogs(callsTo('writeBuffer')).logs[1].args[0].list, equals([3, 0, 0, 2]));
      expect(socket.getLogs(callsTo('writeBufferPart')).logs[1].args[0].list, equals([1, 2, 3]));
      expect(socket.getLogs(callsTo('writeBufferPart')).logs[1].args[1], equals(0));
      expect(socket.getLogs(callsTo('writeBufferPart')).logs[1].args[2], equals(3));
    });

    test('should send large buffer', () async {
      final MAX_PACKET_SIZE = 32 * 1024 * 1024;
      var cnx = new _Connection(null, 15, MAX_PACKET_SIZE);
      var socket = new MockSocket();
      cnx._socket = socket;

      var buffers = [];
      socket.when(callsTo('writeBuffer')).alwaysCall((buffer) {
        buffers.add(new List.from(buffer.list));
        return new Future.value();
      });
      socket.when(callsTo('writeBufferPart')).alwaysReturn(new Future.value());

      final PACKET_SIZE = 17 * 1024 * 1024;
      var buffer = new Buffer(PACKET_SIZE);
      await cnx._sendBuffer(buffer);
      socket.getLogs(callsTo('writeBuffer')).verify(happenedExactly(2));
      socket.getLogs(callsTo('writeBufferPart')).verify(happenedExactly(2));
      expect(buffers[0], equals([0xff, 0xff, 0xff, 1]));
      expect(buffers[1], equals([1, 0, 16, 2]));
      expect(socket.getLogs(callsTo('writeBufferPart')).logs[0].args[1], equals(0));
      expect(socket.getLogs(callsTo('writeBufferPart')).logs[0].args[2], equals(0xffffff));
      expect(socket.getLogs(callsTo('writeBufferPart')).logs[1].args[1], equals(0xffffff));
      expect(socket.getLogs(callsTo('writeBufferPart')).logs[1].args[2], equals(PACKET_SIZE - 0xffffff));
    });

    test('should receive buffer', () async {
      final MAX_PACKET_SIZE = 16 * 1024 * 1024;
      var cnx = new _Connection(null, 15, MAX_PACKET_SIZE);
      var socket = new MockSocket();
      cnx._socket = socket;

      var c = new Completer();

      var buffer;
      cnx._dataHandler = (newBuffer) {
        buffer = newBuffer;
        c.complete();
      };

      var bufferReturnCount = 0;
      var bufferReturn = (_) async {
        if (bufferReturnCount == 0) {
          bufferReturnCount++;
          return new Buffer.fromList([3, 0, 0, 1]);
        } else {
          bufferReturnCount++;
          return new Buffer.fromList([1, 2, 3]);
        }
      };
      socket.when(callsTo('readBuffer')).thenCall(bufferReturn, 2);

      cnx._readPacket();

      await c.future;

      socket.getLogs(callsTo('readBuffer')).verify(happenedExactly(2));
      expect(buffer.list, equals([1, 2, 3]));
    });

    test('should receive large buffer', () async {
      final MAX_PACKET_SIZE = 32 * 1024 * 1024;
      var cnx = new _Connection(null, 15, MAX_PACKET_SIZE);
      var socket = new MockSocket();
      cnx._socket = socket;

      var c = new Completer();

      var buffer;
      cnx._dataHandler = (newBuffer) {
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
      socket.when(callsTo('readBuffer')).thenCall(bufferReturn, 4);

      cnx._readPacket();

      await c.future;
      socket.getLogs(callsTo('readBuffer')).verify(happenedExactly(4));
      expect(buffer.list.length, equals(17 * 1024 * 1024));
      expect(buffer.list[0], equals(1));
      expect(buffer.list[0xffffff - 1], equals(2));
      expect(buffer.list[0xffffff], equals(3));
      expect(buffer.list[buffer.list.length - 1], equals(4));
    });
  });

}

class MockSocket extends Mock implements BufferedSocket {}
class MockConnection extends Mock implements _Connection {}