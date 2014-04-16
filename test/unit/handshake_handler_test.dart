part of sqljocky;

void runHandshakeHandlerTests() {
  group('HandshakeHandler._createNullMap', () {
    createHandshake(protocolVersion, serverVersion, threadId, scrambleBuffer,
        serverCapabilities, serverLanguage, serverStatus, serverCapabilities2,
        scrambleLength, scrambleBuffer2) {
      var response = new Buffer(100);
      response.writeByte(protocolVersion);
      response.writeNullTerminatedList(serverVersion.codeUnits);
      response.writeInt32(threadId);
      response.writeList(scrambleBuffer.codeUnits);
      response.writeByte(0);
      response.writeInt16(serverCapabilities);
      response.writeByte(serverLanguage);
      response.writeInt16(serverStatus);
      response.writeInt16(serverCapabilities2);
      response.writeByte(scrambleLength);
      response.fill(10, 0);
      response.writeNullTerminatedList(scrambleBuffer2.codeUnits);
      return response;
    }

    test('throws if handshake protocol is not 10', () {
      var handler = new _HandshakeHandler("", "");
      var response = new Buffer.fromList([9]);
      expect(() {
        handler.processResponse(response);
      }, throwsA(new isInstanceOf<MySqlProtocolError>()));
    });

    test('throws if server protocol is not 4.1', () {
      var handler = new _HandshakeHandler("", "");
      var response = createHandshake(10, "version 1", 123, "abcdefgh", 0, 0, 0, 0, 0, "buffer");
      expect(() {
        handler.processResponse(response);
      }, throwsA(new isInstanceOf<MySqlClientError>()));
    });

    test('set values and does not throw if handshake protocol is 10 and server protocol is 4.1', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler = new _HandshakeHandler(user, password, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41;
      var serverCapabilities2 = 0;
      var scrambleLength = 10;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = "ijklmnopqrstuvwxyz";
      var responseBuffer = createHandshake(10, serverVersion, threadId, scrambleBuffer1, serverCapabilities1, serverLanguage,
          serverStatus, serverCapabilities2, scrambleLength, scrambleBuffer2);
      var response = handler.processResponse(responseBuffer);

      expect(handler.serverVersion, equals(serverVersion));
      expect(handler.threadId, equals(threadId));
      expect(handler.serverLanguage, equals(serverLanguage));
      expect(handler.serverStatus, equals(serverStatus));
      expect(handler.serverCapabilities, equals(serverCapabilities1));
      expect(handler.scrambleLength, equals(scrambleLength));
      expect(handler.useCompression, isFalse);
      expect(handler.useSSL, isFalse);
      expect(handler.scrambleBuffer, equals((scrambleBuffer1 + scrambleBuffer2).codeUnits));

      expect(response, new isInstanceOf<_HandlerResponse>());
      expect(response.nextHandler, new isInstanceOf<_AuthHandler>());

      _AuthHandler authHandler = response.nextHandler;
      expect(authHandler._username, equals(user));
      expect(authHandler._password, equals(password));
      expect(authHandler._scrambleBuffer, equals((scrambleBuffer1 + scrambleBuffer2).codeUnits));
      expect(authHandler._db, equals(db));

      //TODO test with SSL turned on
      //TODO test with CLIENT_PLUGIN_AUTH set
      //TODO need to set CLIENT_SECURE_CONNECTION and read it in the handler
    });
  });
}
