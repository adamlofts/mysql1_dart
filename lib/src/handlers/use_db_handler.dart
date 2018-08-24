library sqljocky.use_db_handler;

import 'dart:convert';

import 'package:logging/logging.dart';

import '../../constants.dart';
import '../buffer.dart';
import 'handler.dart';

class UseDbHandler extends Handler {
  final String _dbName;

  UseDbHandler(String this._dbName) : super(new Logger("UseDbHandler"));

  Buffer createRequest() {
    var encoded = utf8.encode(_dbName);
    var buffer = new Buffer(encoded.length + 1);
    buffer.writeByte(COM_INIT_DB);
    buffer.writeList(encoded);
    return buffer;
  }
}
