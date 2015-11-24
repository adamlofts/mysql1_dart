library sqljocky.close_statement_handler;

import 'package:logging/logging.dart';

import '../../constants.dart';
import '../buffer.dart';
import '../handlers/handler.dart';

class CloseStatementHandler extends Handler {
  final int _handle;

  CloseStatementHandler(int this._handle)
      : super(new Logger("CloseStatementHandler"));

  Buffer createRequest() {
    var buffer = new Buffer(5);
    buffer.writeByte(COM_STMT_CLOSE);
    buffer.writeUint32(_handle);
    return buffer;
  }
}
