class Buffer {
  int _writePos = 0;
  int _readPos = 0;
  
  List _list;
  
  Buffer(int size) {
    _list = new List(size);
  }
  
  int readFrom(Socket socket, int count) {
    int bytesRead = socket.readList(_list, _writePos, count);
    _writePos += bytesRead;
    return bytesRead;
  }
  
  int operator[](int index) {
    return _list[index];
  }
  
  void reset() {
    _readPos = 0;
    _writePos = 0;
  }
  
  void seek(int pos) {
    _readPos = pos;
  }
  
  void skip(int bytes) {
    _readPos += bytes;
  }
  
  List readNullTerminatedList() {
    List s = new List();
    while (_list[_readPos] != 0) {
      s.add(_list[_readPos]);
      _readPos++;
    }
    _readPos++;
    
    return s;
  }
  
  String readNullTerminatedString() {
    return new String.fromCharCodes(readNullTerminatedList());
  }
  
  int readByte() {
    return _list[_readPos++];
  }
  
  int readInt16() {
    return _list[_readPos++] + (_list[_readPos++] << 8);
  }

  int readInt32() {
    return _list[_readPos++] + (_list[_readPos++] << 8)
        + (_list[_readPos++] << 16) + (_list[_readPos++] << 24);
  }
  
  int readInt64() {
    return _list[_readPos++] + (_list[_readPos++] << 8)
        + (_list[_readPos++] << 16) + (_list[_readPos++] << 24)
        + (_list[_readPos++] << 32) + (_list[_readPos++] << 40)
        + (_list[_readPos++] << 48) + (_list[_readPos++] << 56);
  }
  
  List readList(int size) {
    List list = _list.getRange(_readPos, size);
    _readPos += size;
    return list;
  }
}

