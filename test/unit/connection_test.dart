part of sqljocky;

void runConnectionTests() {
  group('Connection', () {
    test('should send buffer', () {
      var cnx = new _Connection(null, 15);
      var socket = new MockSocket();
      cnx._socket = socket;

      socket.when(callsTo('writeBuffer')).alwaysReturn(new Future.value());

      var buffer = new Buffer.fromList([1, 2, 3]);
      cnx._sendBuffer(buffer).then((_) {
        socket.getLogs(callsTo('writeBuffer')).verify(happenedExactly(2));
        expect(socket.getLogs(callsTo('writeBuffer')).logs[0].args[0].list, equals([3, 0, 0, 1]));
        expect(socket.getLogs(callsTo('writeBuffer')).logs[1].args[0].list, equals([1, 2, 3]));

        var buffer = new Buffer.fromList([1, 2, 3]);
        cnx._sendBuffer(buffer).then((_) {
          socket.getLogs(callsTo('writeBuffer')).verify(happenedExactly(4));
          expect(socket.getLogs(callsTo('writeBuffer')).logs[2].args[0].list, equals([3, 0, 0, 2]));
          expect(socket.getLogs(callsTo('writeBuffer')).logs[3].args[0].list, equals([1, 2, 3]));
        });

      });
    });
  });

}

class MockSocket extends Mock implements BufferedSocket {}
