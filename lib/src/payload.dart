library mysql1.payload;

import 'dart:convert';
import 'dart:typed_data';

/// Reads the fields of a packet's payload in order.
///
/// Everything on the wire is little-endian and unsigned. Strings are UTF-8,
/// and one which is not is decoded with replacement characters rather than
/// failing: an error message from a server set up in another character set
/// is worth more garbled than lost.
class PayloadReader {
  final Uint8List _bytes;
  int _position = 0;

  PayloadReader(this._bytes);

  int get length => _bytes.length;

  /// Whether there is anything left to read.
  bool get hasMore => _position < _bytes.length;

  /// Pass over [count] bytes.
  void skip(int count) {
    _position += count;
  }

  int readByte() => _bytes[_position++];

  int readUint16() => _readUint(2);

  int readUint32() => _readUint(4);

  int _readUint(int width) {
    var value = 0;
    for (var i = 0; i < width; i++) {
      value |= _bytes[_position + i] << (8 * i);
    }
    _position += width;
    return value;
  }

  /// A copy of the next [count] bytes.
  Uint8List readBytes(int count) {
    final bytes = _bytes.sublist(_position, _position + count);
    _position += count;
    return bytes;
  }

  /// A copy of everything left.
  Uint8List readRest() => readBytes(_bytes.length - _position);

  String readString(int length) =>
      utf8.decode(readBytes(length), allowMalformed: true);

  /// Everything left, as a string.
  String readRestAsString() => readString(_bytes.length - _position);

  /// A string up to a zero byte, which is consumed and not returned.
  String readNullTerminatedString() {
    final end = _bytes.indexOf(0, _position);
    if (end == -1) {
      throw const FormatException('A null-terminated string has no end');
    }
    final string = readString(end - _position);
    _position++;
    return string;
  }

  /// An integer in the protocol's variable-width encoding: one byte for a
  /// value below 0xfb, otherwise a marker byte for a width of two, three or
  /// eight bytes. The marker 0xfb on its own stands for a null value.
  int? readLengthEncodedInt() {
    final first = readByte();
    switch (first) {
      case 0xfb:
        return null;
      case 0xfc:
        return _readUint(2);
      case 0xfd:
        return _readUint(3);
      case 0xfe:
        return _readUint(8);
      case 0xff:
        throw const FormatException(
            '0xff is not a length-encoded integer; it begins an error packet');
      default:
        return first;
    }
  }

  /// A string preceded by its length as a length-encoded integer, or null
  /// where the length is the null marker.
  String? readLengthEncodedString() {
    final length = readLengthEncodedInt();
    return length == null ? null : readString(length);
  }
}

/// What a [BytesBuilder] needs to build a payload: the widths the protocol
/// uses, written little-endian.
extension PayloadBuilder on BytesBuilder {
  void addUint16(int value) {
    addByte(value & 0xff);
    addByte((value >> 8) & 0xff);
  }

  void addUint32(int value) {
    addUint16(value & 0xffff);
    addUint16((value >> 16) & 0xffff);
  }

  /// [bytes] and then a zero.
  void addNullTerminated(List<int> bytes) {
    add(bytes);
    addByte(0);
  }

  void addZeros(int count) => add(Uint8List(count));
}
