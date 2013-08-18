part of sqljocky;

class _PrepareOkPacket {
  int _statementHandlerId;
  int _columnCount;
  int _parameterCount;
  int _warningCount;

  int get statementHandlerId => _statementHandlerId;
  int get columnCount => _columnCount;
  int get parameterCount => _parameterCount;
  int get warningCount => _warningCount;
  
  _PrepareOkPacket(Buffer buffer) {
    buffer.seek(1);
    _statementHandlerId = buffer.readUint32();
    _columnCount = buffer.readUint16();
    _parameterCount = buffer.readUint16();
    buffer.skip(1);
    _warningCount = buffer.readUint16();
  }
  
  String toString() => "OK: statement handler id: $_statementHandlerId, columns: $_columnCount, "
      "parameters: $_parameterCount, warnings: $_warningCount";
}
