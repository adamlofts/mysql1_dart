library types;

import 'dart:typeddata';

class Blob {
  String _string;
  List<int> _bytes;
  int _hashcode;
  
  Blob.fromString(String string) {
    this._string = string;
  }
  
  Blob.fromBytes(List<int> bytes) {
    this._bytes = bytes;
  }
  
  String toString() {
    if (_string != null) {
      return _string;
    }
    return new String.fromCharCodes(_bytes);
  }
  
  List<int> toBytes() {
    if (_bytes != null) {
      return _bytes;
    }
    return _string.codeUnits;
  }
  
  int get hashCode {
    if (_hashcode == null) {
      if (_string != null) {
        _hashcode = _string.hashCode;
      } else {
        _hashcode = new String.fromCharCodes(_bytes).hashCode;
      }
    }
    return _hashcode;
  }
  
  bool operator ==(other) {
    return toString() == other.toString();
  }
}
