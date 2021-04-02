library sjljocky.buffer;

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';

/// This provides methods to read and write strings, lists and
/// various sized integers on a buffer (implemented as an integer list).
///
/// The ints in the backing list must all be 8-bit values. If larger values are
/// entered, behaviour is undefined.
///
/// As per mysql spec, numbers here are all unsigned.
/// Which makes things much easier.
class Buffer {
  final Logger log;
  int _writePos = 0;
  int _readPos = 0;

  final Uint8List _list;
  late ByteData _data;

  Uint8List get list => _list;

  /// Creates a [Buffer] of the given [size]
  Buffer(int size)
      : _list = Uint8List(size),
        log = Logger('Buffer') {
    _data = ByteData.view(_list.buffer);
  }

  /// Creates a [Buffer] with the given [list] as backing storage
  Buffer.fromList(List<int> list)
      : _list = Uint8List(list.length),
        log = Logger('Buffer') {
    _list.setRange(0, list.length, list);
    _data = ByteData.view(_list.buffer);
  }

  /// Returns true if more data can be read from the buffer, false otherwise.
  bool canReadMore() => _readPos < _list.lengthInBytes;

  /// Reads up to [count] bytes from the [socket] into the buffer.
  /// Returns the number of bytes read.
  int readFromSocket(RawSocket socket, int count) {
    final bytes = socket.read(count)?.toList();
    if (bytes == null) return 0;

    var bytesRead = bytes.length;
    _list.setRange(_writePos, _writePos + bytesRead, bytes);
    _writePos += bytesRead;
    return bytesRead;
  }

  /// Writes up to [count] bytes to the [socket] from the buffer.
  /// Returns the number of bytes written.
  int writeToSocket(RawSocket socket, int start, int count) {
    return socket.write(_list, start, count);
  }

  /// Returns the int at the specified [index]
  int operator [](int index) => _list[index];

  /// Sets the int at the specified [index] to the given [value]
  void operator []=(int index, int value) {
    _list[index] = value;
  }

  /// Resets the read and write positions markers to the start of
  /// the buffer */
  void reset() {
    _readPos = 0;
    _writePos = 0;
  }

  /// Returns the size of the buffer
  int get length => _list.length;

  /// Moves the read marker to the given [position]
  void seek(int position) {
    _readPos = position;
  }

  /// Moves the read marker forwards by the given [numberOfBytes]
  void skip(int numberOfBytes) {
    _readPos += numberOfBytes;
  }

  /// Moves the write marker to the given [position]
  void seekWrite(int position) {
    _writePos = position;
  }

  /// Moves the write marker forwards by the given [numberOfBytes]
  void skipWrite(int numberOfBytes) {
    _writePos += numberOfBytes;
  }

  /// Fills the next [numberOfBytes] with the given [value]
  void fill(int numberOfBytes, int value) {
    while (numberOfBytes > 0) {
      writeByte(value);
      numberOfBytes--;
    }
  }

  /// Reads a null terminated list of ints from the buffer.
  /// Returns the list of ints from the buffer, without the terminating zero
  List<int> readNullTerminatedList() {
    var s = <int>[];
    while (_list[_readPos] != 0) {
      s.add(_list[_readPos]);
      _readPos++;
    }
    _readPos++;

    return s;
  }

  /// Writes a null terminated list of ints from the buffer. The given [list]
  /// should not contain the terminating zero.
  void writeNullTerminatedList(List<int> list) {
    writeList(list);
    writeByte(0);
  }

  /// Reads a null terminated string from the buffer.
  /// Returns the string, without a terminating null.
  String readNullTerminatedString() {
    return utf8.decode(readNullTerminatedList());
  }

  /// Reads a string from the buffer, terminating when the end of the
  /// buffer is reached.
  String readStringToEnd() => readString(_list.length - _readPos);

  /// Reads a string of the given [length] from the buffer.
  String readString(int length) {
    var s = utf8.decode(_list.sublist(_readPos, _readPos + length),
        allowMalformed: true);
    _readPos += length;
    return s;
  }

  /// Reads a length coded binary from the buffer. This is specified in the mysql docs.
  /// It will read up to nine bytes from the stream, depending on the first byte.
  /// Returns an unsigned integer.
  int? readLengthCodedBinary() {
    var first = readByte();
    if (first < 251) {
      return first;
    }
    switch (first) {
      case 251:
        return null;
      case 252:
        return readUint16();
      case 253:
        return readUint24();
      case 254:
        return readUint64();
    }
    throw ArgumentError('value is out of range');
  }

  static int measureLengthCodedBinary(int value) {
    if (value < 251) {
      return 1;
    }
    if (value < (2 << 15)) {
      return 3;
    }
    if (value < (2 << 23)) {
      return 4;
    }
    if (value < (2 << 63)) {
      return 5;
    }
    throw ArgumentError('value is out of range');
  }

  /// Will write a length coded binary value, once implemented!
  void writeLengthCodedBinary(int value) {
    if (value < 251) {
      writeByte(value);
      return;
    }
    if (value < (2 << 15)) {
      writeByte(0xfc);
      writeUint16(value);
      return;
    }
    if (value < (2 << 23)) {
      writeByte(0xfd);
      writeUint24(value);
      return;
    }
    if (value < (2 << 63)) {
      writeByte(0xfe);
      writeUint64(value);
    }
  }

  /// Returns a length coded string, read from the buffer.
  String? readLengthCodedString() {
    var length = readLengthCodedBinary();
    if (length == null) {
      return null;
    }
    return readString(length);
  }

  /// Returns a single byte, read from the buffer.
  int readByte() => _list[_readPos++];

  bool get hasMore => _readPos < _list.length;

  /// Writes a single [byte] to the buffer.
  void writeByte(int byte) {
    _data.setInt8(_writePos++, byte);
  }

  /// Returns a 16-bit integer, read from the buffer
  int readInt16() {
    var result = _data.getInt16(_readPos, Endian.little);
    _readPos += 2;
    return result;
  }

  /// Writes a 16 bit [integer] to the buffer.
  void writeInt16(int integer) {
    _data.setInt16(_writePos, integer, Endian.little);
    _writePos += 2;
  }

  /// Returns a 16-bit integer, read from the buffer
  int readUint16() {
    var result = _data.getUint16(_readPos, Endian.little);
    _readPos += 2;
    return result;
  }

  /// Writes a 16 bit [integer] to the buffer.
  void writeUint16(int integer) {
    _data.setUint16(_writePos, integer, Endian.little);
    _writePos += 2;
  }

  /// Returns a 24-bit integer, read from the buffer.
  int readUint24() =>
      _list[_readPos++] + (_list[_readPos++] << 8) + (_list[_readPos++] << 16);

  /// Writes a 24 bit [integer] to the buffer.
  void writeUint24(int integer) {
    _list[_writePos++] = integer & 0xFF;
    _list[_writePos++] = integer >> 8 & 0xFF;
    _list[_writePos++] = integer >> 16 & 0xFF;
  }

  /// Returns a 32-bit integer, read from the buffer.
  int readInt32() {
    var val = _data.getInt32(_readPos, Endian.little);
    _readPos += 4;
    return val;
  }

  /// Writes a 32 bit [integer] to the buffer.
  void writeInt32(int integer) {
    _data.setInt32(_writePos, integer, Endian.little);
    _writePos += 4;
  }

  /// Returns a 32-bit integer, read from the buffer.
  int readUint32() {
    var val = _data.getUint32(_readPos, Endian.little);
    _readPos += 4;
    return val;
  }

  /// Writes a 32 bit [integer] to the buffer.
  void writeUint32(int integer) {
    _data.setUint32(_writePos, integer, Endian.little);
    _writePos += 4;
  }

  /// Returns a 64-bit integer, read from the buffer.
  int readInt64() {
    var val = _data.getInt64(_readPos, Endian.little);
    _readPos += 8;
    return val;
  }

  /// Writes a 64 bit [integer] to the buffer.
  void writeInt64(int integer) {
    _data.setInt64(_writePos, integer, Endian.little);
    _writePos += 8;
  }

  /// Returns a 64-bit integer, read from the buffer.
  int readUint64() {
    var val = _data.getUint64(_readPos, Endian.little);
    _readPos += 8;
    return val;
  }

  /// Writes a 64 bit [integer] to the buffer.
  void writeUint64(int integer) {
    _data.setUint64(_writePos, integer, Endian.little);
    _writePos += 8;
  }

  /// Returns a list of the given [numberOfBytes], read from the buffer.
  List<int> readList(int numberOfBytes) {
    List<int> list = _list.sublist(_readPos, _readPos + numberOfBytes);
    _readPos += numberOfBytes;
    return list;
  }

  /// Writes the give [list] of bytes to the buffer.
  void writeList(List<int> list) {
    _list.setRange(_writePos, _writePos + list.length, list);
    _writePos += list.length;
  }

  double readFloat() {
    var val = _data.getFloat32(_readPos, Endian.little);
    _readPos += 4;
    return val;
  }

  void writeFloat(double value) {
    _data.setFloat32(_writePos, value, Endian.little);
    _writePos += 4;
  }

  double readDouble() {
    var val = _data.getFloat64(_readPos, Endian.little);
    _readPos += 8;
    return val;
  }

  void writeDouble(double value) {
    _data.setFloat64(_writePos, value, Endian.little);
    _writePos += 8;
  }

  static String listChars(Uint8List list) {
    var result = StringBuffer();
    for (final e in list) {
      if (e >= 32 && e < 127) {
        result.write(String.fromCharCodes([e]));
      } else {
        result.write('?');
      }
    }
    return result.toString();
  }

  static String debugChars(Uint8List list) {
    var result = StringBuffer();

    var left = StringBuffer();
    var right = StringBuffer();

    for (final e in list) {
      if (e >= 32 && e < 127) {
        right.write(String.fromCharCodes([e]));
      } else {
        right.write('·');
      }
      var hex = e.toRadixString(16);
      if (hex.length == 1) {
        hex = '0$hex';
      }
      left.write('$hex ');

      if (right.length == 4) {
        left.write(' ');
      }
      if (right.length == 8) {
        result.write(left.toString());
        result.write('  ');
        result.write(right.toString());
        result.write('\n');
        left.clear();
        right.clear();
      }
    }
    if (right.length > 0) {
      while (right.length < 8) {
        left.write('   ');
        right.write(' ');
        if (right.length == 4) {
          left.write(' ');
        }
      }
      result.write(left.toString());
      result.write('  ');
      result.write(right.toString());
      result.write('\n');
    }
    return result.toString();
  }
}
