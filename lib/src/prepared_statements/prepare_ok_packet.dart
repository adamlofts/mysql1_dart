library mysql1.prepare_ok_packet;

import '../buffer.dart';

class PrepareOkPacket {
  late int _statementHandlerId;
  late int _columnCount;
  late int _parameterCount;
  late int _warningCount;

  int get statementHandlerId => _statementHandlerId;
  int get columnCount => _columnCount;
  int get parameterCount => _parameterCount;
  int get warningCount => _warningCount;

  PrepareOkPacket(Buffer buffer) {
    buffer.seek(1);
    _statementHandlerId = buffer.readUint32();
    _columnCount = buffer.readUint16();
    _parameterCount = buffer.readUint16();
    buffer.skip(1);
    if (buffer.canReadMore()) {
      _warningCount = buffer.readUint16();
    } else {
      _warningCount = 0;
    }
  }

  @override
  String toString() =>
      'OK: statement handler id: $_statementHandlerId, columns: $_columnCount, '
      'parameters: $_parameterCount, warnings: $_warningCount';
}
