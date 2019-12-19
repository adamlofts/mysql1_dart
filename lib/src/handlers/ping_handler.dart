library mysql1.ping_handler;

import 'package:logging/logging.dart';

import '../constants.dart';
import '../buffer.dart';
import 'handler.dart';

class PingHandler extends Handler {
  PingHandler() : super(Logger('PingHandler'));

  @override
  Buffer createRequest() {
    log.finest('Creating buffer for PingHandler');
    var buffer = Buffer(1);
    buffer.writeByte(COM_PING);
    return buffer;
  }
}
