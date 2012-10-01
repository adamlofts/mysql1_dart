part of sqljocky;

/**
 * The class [Buffer] provides methods to read and write strings, lists and
 * various sized integers on a buffer (implemented as an integer list).
 *
 * The ints in the backing list must all be 8-bit values. If larger values are
 * entered, behaviour is undefined.
 *
 * As per mysql spec, numbers here are all unsigned.
 * Which makes things much easier.
 */
class Buffer {
  final Logger log;
  int _writePos = 0;
  int _readPos = 0;
  
  final Uint8List _list;
  
  Uint8List get list => _list;
  
  /**
   * Creates a [Buffer] of the given [size]
   */
  Buffer(int size) : _list = new Uint8List(size),
                     log = new Logger("Buffer");
  
  /**
   * Creates a [Buffer] with the given [list] as backing storage
   */
  Buffer.fromList(List<int> list) : _list = new Uint8List(list.length),
                                    log = new Logger("Buffer") {
    _list.addAll(list);
  }
  
  /**
   * Returns true if more data can be read from the buffer, false otherwise.
   */
  bool canReadMore() => _readPos < _list.lengthInBytes();
  
  /**
   * Reads up to [count] bytes from the [socket] into the buffer.
   * Returns the number of bytes read.
   */
  int readFrom(Socket socket, int count) {
    int bytesRead = socket.readList(_list, _writePos, count);
    _writePos += bytesRead;
    return bytesRead;
  }
  
  /**
   * Writes up to [count] bytes to the [socket] from the buffer.
   *
   * Returns true if the data could be written immediately. Otherwise data is buffered
   * and sent as soon as possible (as per [OutputStream.write()])
   */
  bool writeTo(Socket socket, int count) {
    log.fine("writing $count of $_list from $_readPos");
    log.fine("writing $count of [${Buffer.listChars(_list)}] from $_readPos");
    return socket.outputStream.writeFrom(_list, _readPos, count);
  }
  
  /**
   * Write all of the buffer to the [socket].
   *
   * Returns true if the data could be written immediately. Otherwise data is buffered
   * and sent as soon as possible (as per [OutputStream.write()])
   */
  bool writeAllTo(Socket socket) {
    reset();
    return writeTo(socket, _list.length);
  }
  
  /**
   * Returns the int at the specified [index]
   */
  int operator[](int index) => _list[index];
  
  /**
   * Sets the int at the specified [index] to the given [value]
   */
  void operator[]=(int index, value) {
    _list[index] = value;
  }
  
  /**
   * Resets the read and write positions markers to the start of
   * the buffer */
  void reset() {
    _readPos = 0;
    _writePos = 0;
  }
  
  /**
   * Returns the size of the buffer
   */
  int get length => _list.length;
  
  /**
   * Moves the read marker to the given [position]
   */
  void seek(int position) {
    _readPos = position;
  }
  
  /**
   * Moves the read marker forwards by the given [numberOfBytes]
   */
  void skip(int numberOfBytes) {
    _readPos += numberOfBytes;
  }
  
  /**
   * Moves the write marker to the given [position]
   */
  void seekWrite(int position) {
    _writePos = position;
  }
  
  /**
   * Moves the write marker forwards by the given [numberOfBytes]
   */
  void skipWrite(int numberOfBytes) {
    _writePos += numberOfBytes;
  }
  
  /**
   * Fills the next [numberOfBytes] with the given [value]
   */
  void fill(int numberOfBytes, int value) {
    while (numberOfBytes > 0) {
      writeByte(value);
      numberOfBytes--;
    }
  }
  
  /**
   * Reads a null terminated list of ints from the buffer.
   * Returns the list of ints from the buffer, without the terminating zero
   */
  List<int> readNullTerminatedList() {
    List<int> s = <int>[];
    while (_list[_readPos] != 0) {
      s.add(_list[_readPos]);
      _readPos++;
    }
    _readPos++;
    
    return s;
  }
  
  /**
   * Writes a null terminated list of ints from the buffer. The given [list]
   * should not contain the terminating zero.
   */ 
  void writeNullTerminatedList(List<int> list) {
    writeList(list);
    writeByte(0);
  }
  
  /**
   * Reads a null terminated string from the buffer.
   * Returns the string, without a terminating null.
   */
  String readNullTerminatedString() => new String.fromCharCodes(readNullTerminatedList());
  
  /**
   * Writes a null terminated string to the buffer.
   * The given [string] does not need to contain the terminating null.
   */
  void writeNullTerminatedString(String string) {
    writeNullTerminatedList(string.charCodes());
  }
  
  /**
   * Reads a string from the buffer, terminating when the end of the
   * buffer is reached.
   */
  String readStringToEnd() => readString(_list.length - _readPos);
  
  /**
   * Writes a [string] to the buffer, without any length indicators or
   * terminating nulls.
   */  
  void writeString(String string) {
    writeList(string.charCodes());
  }
  
  /**
   * Reads a string of the given [length] from the buffer.
   */
  String readString(int length) {
    String s = new String.fromCharCodes(_list.getRange(_readPos, length));
    _readPos += length;
    return s;
  }
  
  /**
   * Reads a length coded binary from the buffer. This is specified in the mysql docs.
   * It will read up to nine bytes from the stream, depending on the first byte.
   * Returns an unsigned integer. 
   */
  int readLengthCodedBinary() {
    int first = readByte();
    if (first < 251) {
      return first;
    }
    switch (first) {
      case 251:
        return null;
      case 252:
        return readInt16();
      case 253:
        return readInt24();
      case 254:
        return readInt64();
    }
  }
  
  /**
   * Will write a length coded binary value, once implemented!
   */
  void writeLengthCodedBinary(int value) {
    throw "not implemented writeLengthCodedBinary yet";
  }

  /**
   * Returns a length coded string, read from the buffer.
   */
  String readLengthCodedString() {
    int length = readLengthCodedBinary();
    if (length == null) {
      return null;
    }
    return readString(length);
  }
  
  /**
   * Returns a single byte, read from the buffer.
   */
  int readByte() => _list[_readPos++];
  
  /**
   * Writes a single [byte] to the buffer.
   */ 
  void writeByte(int byte) {
    _list.asByteArray().setInt8(_writePos++, byte);
  }
  
  /**
   * Returns a 16-bit integer, read from the buffer 
   */
  int readInt16() {
    int result = _list.asByteArray().getInt16(_readPos);
    _readPos += 2;
    return result;
  }
  
  /**
   * Writes a 16 bit [integer] to the buffer.
   */
  void writeInt16(int integer) {
    _list.asByteArray().setInt16(_writePos, integer);
    _writePos += 2;
  }

  /**
   * Returns a 24-bit integer, read from the buffer.
   */
  int readInt24() => _list[_readPos++] + (_list[_readPos++] << 8)
        + (_list[_readPos++] << 16);

  /**
   * Writes a 24 bit [integer] to the buffer.
   */
  void writeInt24(int integer) {
    _list[_writePos++] = integer & 0xFF;
    _list[_writePos++] = integer >> 8 & 0xFF;
    _list[_writePos++] = integer >> 16 & 0xFF;
  }

  /**
   * Returns a 32-bit integer, read from the buffer.
   */
  int readInt32() {
    int val = _list.asByteArray().getInt32(_readPos);
    _readPos += 4;
    return val;
  }

  /**
   * Writes a 32 bit [integer] to the buffer.
   */
  void writeInt32(int integer) {
    _list.asByteArray().setInt32(_writePos, integer);
    _writePos += 4;
  }

  /**
   * Returns a 64-bit integer, read from the buffer.
   */
  int readInt64() {
    int val = _list.asByteArray().getInt64(_readPos);
    _readPos += 8;
    return val;
  }
  
  /**
   * Writes a 64 bit [integer] to the buffer.
   */
  void writeInt64(int integer) {
    _list.asByteArray().setInt64(_writePos, integer);
    _writePos += 8;
  }

  /**
   * Returns a list of the given [numberOfBytes], read from the buffer.
   */
  List<int> readList(int numberOfBytes) {
    List<int> list = _list.getRange(_readPos, numberOfBytes);
    _readPos += numberOfBytes;
    return list;
  }
  
  /**
   * Writes the give [list] of bytes to the buffer.
   */
  void writeList(List<int> list) {
    _list.setRange(_writePos, list.length, list);
    _writePos += list.length;
  }
  
  double readFloat() {
    double val = _list.asByteArray().getFloat32(_readPos);
    _readPos += 4;
    return val;
  }
  
  void writeFloat(double value) {
    _list.asByteArray().setFloat32(_writePos, value);
    _writePos += 4;
  }
  
  double readDouble() {
    double val = _list.asByteArray().getFloat64(_readPos);
    _readPos += 8;
    return val;
  }
  
  void writeDouble(double value) {
    _list.asByteArray().setFloat64(_writePos, value);
    _writePos += 8;
  }
  
  static String listChars(Uint8List list) {
    var result = new StringBuffer();
    for (final e in list) {
      if (e >= 32 && e < 127) {
        result.add(new String.fromCharCodes([e]));
      } else {
        result.add('?');
      }
    }
    return result.toString();
  }
}

