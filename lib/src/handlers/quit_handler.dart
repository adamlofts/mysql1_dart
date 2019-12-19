library mysql1.quit_handler;

import 'package:logging/logging.dart';

import '../constants.dart';
import '../buffer.dart';
import '../mysql_protocol_error.dart';
import 'handler.dart';

class QuitHandler extends Handler {
  QuitHandler() : super(Logger('QuitHandler'));

  @override
  Buffer createRequest() {
    var buffer = Buffer(1);
    buffer.writeByte(COM_QUIT);
    return buffer;
  }

  @override
  HandlerResponse processResponse(Buffer response) {
    throw createMySqlProtocolError(
        "Shouldn't have received a response after sending a QUIT message");
  }
}
