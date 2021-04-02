library mysql1.parameter_packet;

import '../buffer.dart';

// not using this one yet
class ParameterPacket {
  final int _type;
  final int _flags;
  final int _decimals;
  final int _length;

  int get type => _type;
  int get flags => _flags;
  int get decimals => _decimals;
  int get length => _length;

  ParameterPacket(Buffer buffer)
      : _type = buffer.readUint16(),
        _flags = buffer.readUint16(),
        _decimals = buffer.readByte(),
        _length = buffer.readUint32();
}
