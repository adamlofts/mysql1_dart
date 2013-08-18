part of sqljocky;

// not using this one yet
class _ParameterPacket {
  int _type;
  int _flags;
  int _decimals;
  int _length;
  
  int get type => _type;
  int get flags => _flags;
  int get decimals => _decimals;
  int get length => _length;
  
  _ParameterPacket(Buffer buffer) {
    _type = buffer.readUint16();
    _flags = buffer.readUint16();
    _decimals = buffer.readByte();
    _length = buffer.readUint32();
  }
}

