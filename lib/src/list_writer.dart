library list_writer;

import 'package:logging/logging.dart';
import 'dart:typed_data';
import 'dart:io';

/**
 * This provides methods to read and write strings, lists and
 * various sized integers on a buffer (implemented as an integer list).
 *
 * The ints in the backing list must all be 8-bit values. If larger values are
 * entered, behaviour is undefined.
 *
 * As per mysql spec, numbers here are all unsigned.
 * Which makes things much easier.
 */
class ListWriter {
  final Logger log;

  final List<int> _list;
  
  List<int> get list => _list;
  
  /**
   * Creates a [ListWriter] with the given [list] as backing storage
   */
  ListWriter(List<int> list) : _list = list,
                                    log = new Logger("Buffer");
  
  /**
   * Writes up to [count] bytes to the [socket] from the buffer.
   * Returns the number of bytes written.
   */
  int writeToSocket(RawSocket socket, int start, int count) {
    return socket.write(_list, start, count);
  }
  
  /**
   * Adds the [value] to the list;
   */
  void add(value) {
    _list.add(value);
  }
  
  /**
   * Returns the size of the buffer
   */
  int get length => _list.length;
  
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
   * Writes a null terminated list of ints from the buffer. The given [list]
   * should not contain the terminating zero.
   */ 
  void writeNullTerminatedList(List<int> list) {
    writeList(list);
    writeByte(0);
  }
  
  /**
   * Writes a null terminated string to the buffer.
   * The given [string] does not need to contain the terminating null.
   */
  void writeNullTerminatedString(String string) {
    writeNullTerminatedList(string.codeUnits);
  }
  
  /**
   * Writes a [string] to the buffer, without any length indicators or
   * terminating nulls.
   */  
  void writeString(String string) {
    writeList(string.codeUnits);
  }
  
  /**
   * Will write a length coded binary value, once implemented!
   */
  void writeLengthCodedBinary(int value) {
    if (value < 251) {
      writeByte(value);
      return;
    }
    if (value < (2 << 15)) {
      writeByte(0xfc);
      writeInt16(value);
      return;
    }
    if (value < (2 << 23)) {
      writeByte(0xfd);
      writeInt24(value);
      return;
    }
    if (value < (2 << 63)) {
      writeByte(0xfe);
      writeInt64(value);
    }
  }
  
  /**
   * Writes a single [byte] to the buffer.
   */ 
  void writeByte(int byte) {
    _list.add(byte);
  }
  
  /**
   * Writes a 16 bit [integer] to the buffer.
   */
  void writeInt16(int integer) {
    _list.add(integer & 0xFF);
    _list.add(integer >> 8 & 0xFF);
  }

  /**
   * Writes a 24 bit [integer] to the buffer.
   */
  void writeInt24(int integer) {
    _list.add(integer & 0xFF);
    _list.add(integer >> 8 & 0xFF);
    _list.add(integer >> 16 & 0xFF);
  }

  /**
   * Writes a 32 bit [integer] to the buffer.
   */
  void writeInt32(int integer) {
    _list.add(integer & 0xFF);
    _list.add(integer >> 8 & 0xFF);
    _list.add(integer >> 16 & 0xFF);
    _list.add(integer >> 24 & 0xFF);
  }

  /**
   * Writes a 64 bit [integer] to the buffer.
   */
  void writeInt64(int integer) {
    _list.add(integer & 0xFF);
    _list.add(integer >> 8 & 0xFF);
    _list.add(integer >> 16 & 0xFF);
    _list.add(integer >> 24 & 0xFF);
    _list.add(integer >> 32 & 0xFF);
    _list.add(integer >> 40 & 0xFF);
    _list.add(integer >> 48 & 0xFF);
    _list.add(integer >> 56 & 0xFF);
  }

  /**
   * Writes the give [list] of bytes to the buffer.
   */
  void writeList(List<int> list) {
    _list.addAll(list);
  }
}

