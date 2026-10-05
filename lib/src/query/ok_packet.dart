library mysql1.ok_packet;

import '../buffer.dart';

class OkPacket {
  late int? _affectedRows;
  late int? _insertId;
  late int _serverStatus;
  late String _message;

  int? get affectedRows => _affectedRows;
  int? get insertId => _insertId;
  int get serverStatus => _serverStatus;
  String get message => _message;

  OkPacket(Buffer buffer) {
    buffer.seek(1);
    _affectedRows = buffer.readLengthCodedBinary();
    _insertId = buffer.readLengthCodedBinary();
    _serverStatus = buffer.readUint16();
    _message = buffer.readStringToEnd();
  }

  @override
  String toString() =>
      'OK: affected rows: $affectedRows, insert id: $insertId, server status: $serverStatus, message: $message';
}
