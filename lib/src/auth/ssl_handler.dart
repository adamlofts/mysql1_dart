library mysql1.ssl_handler;

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
      : super(Logger('SSLHandler'));

  @override
  Buffer createRequest() {
    var buffer = Buffer(32);
    buffer.seekWrite(0);
    buffer.writeUint32(clientFlags);
    buffer.writeUint32(maxPacketSize);
    buffer.writeByte(characterSet);
    buffer.fill(23, 0);

    return buffer;
  }
}
