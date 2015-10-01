library sqljocky.debug_handler;

import 'package:logging/logging.dart';

import '../../constants.dart';
import '../buffer.dart';
import 'handler.dart';

class DebugHandler extends Handler {
  DebugHandler() : super(new Logger("DebugHandler"));

  Buffer createRequest() {
    var buffer = new Buffer(1);
    buffer.writeByte(COM_DEBUG);
    return buffer;
  }
}
