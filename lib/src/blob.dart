part of sqljocky;

/**
 * Holds blob data, and can be created or accessed as either a [String] or a [List] of ints.
 */
class Blob {
  String _string;
  List<int> _bytes;
  int _hashcode;
  
  /**
   * Create a [Blob] from a [string].
   */
  Blob.fromString(String string) {
    this._string = string;
  }
  
  /**
   * Create a [Blob] from a list of [bytes].
   */
  Blob.fromBytes(List<int> bytes) {
    this._bytes = bytes;
  }
  
  /**
   * Returns the value of the blob as a [String].
   */
  String toString() {
    if (_string != null) {
      return _string;
    }
    return decodeUtf8(_bytes);
  }
  
  /**
   * Returns the value of the blob as a list of bytes.
   */
  List<int> toBytes() {
    if (_bytes != null) {
      return _bytes;
    }
    return encodeUtf8(_string);
  }
  
  int get hashCode {
    if (_hashcode == null) {
      if (_string != null) {
        _hashcode = _string.hashCode;
      } else {
        _hashcode = decodeUtf8(_bytes).hashCode;
      }
    }
    return _hashcode;
  }
  
  bool operator ==(other) => toString() == other.toString();
}
