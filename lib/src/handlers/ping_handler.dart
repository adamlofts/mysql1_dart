library sqljocky.ping_handler;

import 'package:logging/logging.dart';

import '../../constants.dart';
import '../buffer.dart';
import 'handler.dart';

class PingHandler extends Handler {
  PingHandler() : super(new Logger("PingHandler"));

  Buffer createRequest() {
    log.finest("Creating buffer for PingHandler");
    var buffer = new Buffer(1);
    buffer.writeByte(COM_PING);
    return buffer;
  }
}
