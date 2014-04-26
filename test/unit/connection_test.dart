part of sqljocky;

void runConnectionTests() {
  group('Connection', () {
    test('should throw error if buffer is too big', () {
      var cnx = new _Connection(null, 15, 10);
      var buffer = new Buffer(11);
      expect(() {
        cnx._sendBuffer(buffer);
      }, throwsA(new isInstanceOf<MySqlClientError>()));
    });

    test('should send buffer', () {
      var cnx = new _Connection(null, 15, 16 * 1024 * 1024);
      var socket = new MockSocket();
      cnx._socket = socket;

      socket.when(callsTo('writeBuffer')).alwaysReturn(new Future.value());
      socket.when(callsTo('writeBufferPart')).alwaysReturn(new Future.value());

      var buffer = new Buffer.fromList([1, 2, 3]);
      return cnx._sendBuffer(buffer).then((_) {
        socket.getLogs(callsTo('writeBuffer')).verify(happenedExactly(1));
        socket.getLogs(callsTo('writeBufferPart')).verify(happenedExactly(1));
        expect(socket.getLogs(callsTo('writeBuffer')).logs[0].args[0].list, equals([3, 0, 0, 1]));
        expect(socket.getLogs(callsTo('writeBufferPart')).logs[0].args[0].list, equals([1, 2, 3]));
        expect(socket.getLogs(callsTo('writeBufferPart')).logs[0].args[1], equals(0));
        expect(socket.getLogs(callsTo('writeBufferPart')).logs[0].args[2], equals(3));

        var buffer = new Buffer.fromList([1, 2, 3]);
        return cnx._sendBuffer(buffer).then((_) {
          socket.getLogs(callsTo('writeBuffer')).verify(happenedExactly(2));
          socket.getLogs(callsTo('writeBufferPart')).verify(happenedExactly(2));
          expect(socket.getLogs(callsTo('writeBuffer')).logs[1].args[0].list, equals([3, 0, 0, 2]));
          expect(socket.getLogs(callsTo('writeBufferPart')).logs[1].args[0].list, equals([1, 2, 3]));
          expect(socket.getLogs(callsTo('writeBufferPart')).logs[1].args[1], equals(0));
          expect(socket.getLogs(callsTo('writeBufferPart')).logs[1].args[2], equals(3));
        });

      });
    });

    test('should send large buffer', () {
      var cnx = new _Connection(null, 15, 32 * 1024 * 1024);
      var socket = new MockSocket();
      cnx._socket = socket;

      var buffers = [];
      socket.when(callsTo('writeBuffer')).alwaysCall((buffer) {
        buffers.add(new List.from(buffer.list));
        return new Future.value();
      });
      socket.when(callsTo('writeBufferPart')).alwaysReturn(new Future.value());

      var buffer = new Buffer(17 * 1024 * 1024);
      return cnx._sendBuffer(buffer).then((_) {
        socket.getLogs(callsTo('writeBuffer')).verify(happenedExactly(2));
        socket.getLogs(callsTo('writeBufferPart')).verify(happenedExactly(2));
        expect(buffers[0], equals([0xff, 0xff, 0xff, 1]));
        expect(buffers[1], equals([1, 0, 16, 2]));
        expect(socket.getLogs(callsTo('writeBufferPart')).logs[0].args[1], equals(0));
        expect(socket.getLogs(callsTo('writeBufferPart')).logs[0].args[2], equals(0xffffff));
        expect(socket.getLogs(callsTo('writeBufferPart')).logs[1].args[1], equals(0xffffff));
        expect(socket.getLogs(callsTo('writeBufferPart')).logs[1].args[2], equals(17 * 1024 * 1024 - 0xffffff));
      });
    });

    test('should receive buffer', () {
      var cnx = new _Connection(null, 15, 16 * 1024 * 1024);
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
          return new Future.value(new Buffer.fromList([3, 0, 0, 1]));
        } else {
          bufferReturnCount++;
          return new Future.value(new Buffer.fromList([1, 2, 3]));
        }
      };
      socket.when(callsTo('readBuffer')).thenCall(bufferReturn, 2);

      cnx._readPacket();

      return c.future.then((_) {

        socket.getLogs(callsTo('readBuffer')).verify(happenedExactly(2));
        expect(buffer.list, equals([1, 2, 3]));
      });
    });
  });

}

class MockSocket extends Mock implements BufferedSocket {}
class MockConnection extends Mock implements _Connection {}