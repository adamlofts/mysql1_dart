part of sqljocky;

void runHandshakeHandlerTests() {
  createHandshake(protocolVersion, serverVersion, threadId, scrambleBuffer, serverCapabilities,
                  [serverLanguage, serverStatus, serverCapabilities2, scrambleLength, scrambleBuffer2,
                  pluginName, pluginNameNull]) {
    var length = 1 + serverVersion.length + 1 + 4 + 8 + 1 + 2;
    if (serverLanguage != null) {
      length += 1 + 2 + 2 + 1 + 10;
      if (scrambleBuffer2 != null) {
        length += scrambleBuffer2.length + 1;
      }
      if (pluginName != null) {
        length += pluginName.length;
        if (pluginNameNull) {
          length++;
        }
      }
    }

    var response = new Buffer(length);
    response.writeByte(protocolVersion);
    response.writeNullTerminatedList(serverVersion.codeUnits);
    response.writeInt32(threadId);
    response.writeList(scrambleBuffer.codeUnits);
    response.writeByte(0);
    response.writeInt16(serverCapabilities);
    if (serverLanguage != null) {
      response.writeByte(serverLanguage);
      response.writeInt16(serverStatus);
      response.writeInt16(serverCapabilities2);
      response.writeByte(scrambleLength);
      response.fill(10, 0);
      if (scrambleBuffer2 != null) {
        response.writeNullTerminatedList(scrambleBuffer2.codeUnits);
      }
      if (pluginName != null) {
        response.writeList(pluginName.codeUnits);
        if (pluginNameNull) {
          response.writeByte(0);
        }
      }
    }
    return response;
  }

  group('HandshakeHandler._readResponseBuffer', () {
    test('throws if handshake protocol is not 10', () {
      var handler = new _HandshakeHandler("", "");
      var response = new Buffer.fromList([9]);
      expect(() {
        handler._readResponseBuffer(response);
      }, throwsA(new isInstanceOf<MySqlProtocolError>()));
    });

    test('set values and does not throw if handshake protocol is 10', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler = new _HandshakeHandler(user, password, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = 0;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = "ijklmnopqrstuvwxyz";
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var responseBuffer = createHandshake(10, serverVersion, threadId, scrambleBuffer1,
          serverCapabilities1, serverLanguage, serverStatus, serverCapabilities2, scrambleLength, scrambleBuffer2);
      handler._readResponseBuffer(responseBuffer);

      expect(handler.serverVersion, equals(serverVersion));
      expect(handler.threadId, equals(threadId));
      expect(handler.serverLanguage, equals(serverLanguage));
      expect(handler.serverStatus, equals(serverStatus));
      expect(handler.serverCapabilities, equals(serverCapabilities1));
      expect(handler.scrambleLength, equals(scrambleLength));
      expect(handler.scrambleBuffer, equals((scrambleBuffer1 + scrambleBuffer2).codeUnits));
    });

    test('should cope with no data past first capability flags', () {
      var serverVersion = "version 1";
      var scrambleBuffer1 = "abcdefgh";
      var threadId = 123882394;
      var serverCapabilities = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;

      var responseBuffer = createHandshake(10, serverVersion, threadId, scrambleBuffer1, serverCapabilities);

      var handler = new _HandshakeHandler("", "");
      handler._readResponseBuffer(responseBuffer);

      expect(handler.serverVersion, equals(serverVersion));
      expect(handler.threadId, equals(threadId));
      expect(handler.serverCapabilities, equals(serverCapabilities));
      expect(handler.serverLanguage, equals(null));
      expect(handler.serverStatus, equals(null));
    });

    test('should read plugin name', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler = new _HandshakeHandler(user, password, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = "ijklmnopqrstuvwxyz";
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var pluginName = "plugin name";
      var responseBuffer = createHandshake(10, serverVersion, threadId, scrambleBuffer1,
          serverCapabilities1, serverLanguage, serverStatus, serverCapabilities2, scrambleLength, scrambleBuffer2,
          pluginName, false);
      handler._readResponseBuffer(responseBuffer);

      expect(handler.pluginName, equals(pluginName));
    });

    test('should read plugin name with null', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler = new _HandshakeHandler(user, password, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = "ijklmnopqrstuvwxyz";
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var pluginName = "plugin name";
      var responseBuffer = createHandshake(10, serverVersion, threadId, scrambleBuffer1,
          serverCapabilities1, serverLanguage, serverStatus, serverCapabilities2, scrambleLength, scrambleBuffer2,
          pluginName, true);
      handler._readResponseBuffer(responseBuffer);

      expect(handler.pluginName, equals(pluginName));
    });

    test('should read buffer without scramble data', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler = new _HandshakeHandler(user, password, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41;
      var serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = null;
      var scrambleLength = scrambleBuffer1.length;
      var pluginName = "plugin name";
      var responseBuffer = createHandshake(10, serverVersion, threadId, scrambleBuffer1,
          serverCapabilities1, serverLanguage, serverStatus, serverCapabilities2, scrambleLength, scrambleBuffer2,
          pluginName, true);
      handler._readResponseBuffer(responseBuffer);

      expect(handler.pluginName, equals(pluginName));
    });
  });

  group('HandshakeHandler.processResponse', () {
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
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = 0;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = "ijklmnopqrstuvwxyz";
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var responseBuffer = createHandshake(10, serverVersion, threadId, scrambleBuffer1, serverCapabilities1, serverLanguage,
          serverStatus, serverCapabilities2, scrambleLength, scrambleBuffer2);
      var response = handler.processResponse(responseBuffer);

      expect(handler.useCompression, isFalse);
      expect(handler.useSSL, isFalse);

      expect(response, new isInstanceOf<_HandlerResponse>());
      expect(response.nextHandler, new isInstanceOf<_AuthHandler>());

      _AuthHandler authHandler = response.nextHandler;
      expect(authHandler._username, equals(user));
      expect(authHandler._password, equals(password));
      expect(authHandler._scrambleBuffer, equals((scrambleBuffer1 + scrambleBuffer2).codeUnits));
      expect(authHandler._db, equals(db));

      //TODO test with SSL turned on
    });
  });
}
