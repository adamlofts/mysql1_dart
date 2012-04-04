class Buffer {
  int _writePos = 0;
  int _readPos = 0;
  
  List<int> _list;
  
  Buffer(int size) {
    _list = new List<int>(size);
  }
  
  int readFrom(Socket socket, int count) {
    int bytesRead = socket.readList(_list, _writePos, count);
    _writePos += bytesRead;
    return bytesRead;
  }
  
  int writeTo(Socket socket, int count) {
    print("writing $_list from $_readPos");
    int bytesWritten = socket.writeList(_list, _readPos, count);
    _readPos += bytesWritten;
    return bytesWritten;
  }
  
  int operator[](int index) {
    return _list[index];
  }
  
  int operator[]=(int index, value) {
    _list[index] = value;
  }
  
  void reset() {
    _readPos = 0;
    _writePos = 0;
  }
  
  int get length() {
    return _list.length;
  }
  
  void seek(int pos) {
    _readPos = pos;
  }
  
  void skip(int bytes) {
    _readPos += bytes;
  }
  
  void seekWrite(int pos) {
    _writePos = pos;
  }
  
  void skipWrite(int bytes) {
    _writePos += bytes;
  }
  
  void fill(int bytes, int value) {
    while (bytes > 0) {
      writeByte(value);
      bytes--;
    }
  }
  
  List<int> readNullTerminatedList() {
    List<int> s = new List<int>();
    while (_list[_readPos] != 0) {
      s.add(_list[_readPos]);
      _readPos++;
    }
    _readPos++;
    
    return s;
  }
  
  void writeNullTerminatedList(List<int> list) {
    writeList(list);
    writeByte(0);
  }
  
  String readNullTerminatedString() {
    return new String.fromCharCodes(readNullTerminatedList());
  }
  
  void writeNullTerminatedString(String s) {
    writeNullTerminatedList(s.charCodes());
  }
  
  int readByte() {
    return _list[_readPos++];
  }
  
  void writeByte(int b) {
    _list[_writePos++] = b;
  }
  
  int readInt16() {
    return _list[_readPos++] + (_list[_readPos++] << 8);
  }
  
  void writeInt16(int i) {
    _list[_writePos++] = i & 0xFF;
    _list[_writePos++] = (i & 0xFF00) >> 8;
  }

  int readInt32() {
    return _list[_readPos++] + (_list[_readPos++] << 8)
        + (_list[_readPos++] << 16) + (_list[_readPos++] << 24);
  }

  void writeInt32(int i) {
    _list[_writePos++] = i & 0xFF;
    _list[_writePos++] = (i & 0xFF00) >> 8;
    _list[_writePos++] = (i & 0xFF0000) >> 16;
    _list[_writePos++] = (i & 0xFF000000) >> 24;
  }

  int readInt64() {
    return _list[_readPos++] + (_list[_readPos++] << 8)
        + (_list[_readPos++] << 16) + (_list[_readPos++] << 24)
        + (_list[_readPos++] << 32) + (_list[_readPos++] << 40)
        + (_list[_readPos++] << 48) + (_list[_readPos++] << 56);
  }
  
  void writeInt64(int i) {
    _list[_writePos++] = i & 0xFF;
    _list[_writePos++] = (i & 0xFF00) >> 8;
    _list[_writePos++] = (i & 0xFF0000) >> 16;
    _list[_writePos++] = (i & 0xFF000000) >> 24;
    _list[_writePos++] = (i & 0xFF00000000) >> 32;
    _list[_writePos++] = (i & 0xFF0000000000) >> 40;
    _list[_writePos++] = (i & 0xFF000000000000) >> 48;
    _list[_writePos++] = (i & 0xFF00000000000000) >> 56;
  }

  List<int> readList(int size) {
    List<int> list = _list.getRange(_readPos, size);
    _readPos += size;
    return list;
  }
  
  void writeList(List<int> list) {
    _list.setRange(_writePos, list.length, list);
    _writePos += list.length;
  }
}

