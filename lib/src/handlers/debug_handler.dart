library mysql1.debug_handler;

import 'package:logging/logging.dart';

import '../constants.dart';
import '../buffer.dart';
import 'handler.dart';

class DebugHandler extends Handler {
  DebugHandler() : super(Logger('DebugHandler'));

  @override
  Buffer createRequest() {
    var buffer = Buffer(1);
    buffer.writeByte(COM_DEBUG);
    return buffer;
  }
}
