library mysql1.close_statement_handler;

import 'package:logging/logging.dart';

import '../constants.dart';
import '../buffer.dart';
import '../handlers/handler.dart';

class CloseStatementHandler extends Handler {
  final int _handle;

  CloseStatementHandler(this._handle) : super(Logger('CloseStatementHandler'));

  @override
  Buffer createRequest() {
    var buffer = Buffer(5);
    buffer.writeByte(COM_STMT_CLOSE);
    buffer.writeUint32(_handle);
    return buffer;
  }
}
