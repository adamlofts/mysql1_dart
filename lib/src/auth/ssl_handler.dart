library sqljocky.ssl_handler;

import 'package:logging/logging.dart';

import '../buffer.dart';
import '../handlers/handler.dart';

class SSLHandler extends Handler {
  final int clientFlags;
  final int maxPacketSize;
  final int characterSet;

  final Handler nextHandler;

  SSLHandler(
      this.clientFlags, this.maxPacketSize, this.characterSet, this.nextHandler)
      : super(new Logger("SSLHandler"));

  Buffer createRequest() {
    var buffer = new Buffer(32);
    buffer.seekWrite(0);
    buffer.writeUint32(clientFlags);
    buffer.writeUint32(maxPacketSize);
    buffer.writeByte(characterSet);
    buffer.fill(23, 0);

    return buffer;
  }
}
