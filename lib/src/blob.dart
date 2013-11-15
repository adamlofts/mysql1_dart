part of sqljocky;

/**
 * Holds blob data, and can be created or accessed as either a [String] or a [List] of 
 * 8-bit integers.
 * 
 * When a blob which was created as a list of integers is accessed as a string, those
 * integers are treated as UTF-8 code units (unsigned 8-bit integers).
 */
class Blob {
  String _string;
  List<int> _codeUnits;
  int _hashcode;
  
  /// Create a [Blob] from a [string].
  Blob.fromString(String string) {
    this._string = string;
  }
  
  /// Create a [Blob] from a list of [codeUnits].
  Blob.fromBytes(List<int> codeUnits) {
    this._codeUnits = codeUnits;
  }
  
  /// Returns the value of the blob as a [String].
  String toString() {
    if (_string != null) {
      return _string;
    }
    return UTF8.decode(_codeUnits);
  }
  
  /// Returns the value of the blob as a list of code units.
  List<int> toBytes() {
    if (_codeUnits != null) {
      return _codeUnits;
    }
    return UTF8.encode(_string);
  }
  
  int get hashCode {
    if (_hashcode == null) {
      if (_string != null) {
        _hashcode = _string.hashCode;
      } else {
        _hashcode = UTF8.decode(_codeUnits).hashCode;
      }
    }
    return _hashcode;
  }
  
  bool operator ==(other) => toString() == other.toString();
}
