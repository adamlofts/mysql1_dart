part of sqljocky;

class _AuthHandler extends _Handler {
  final String _username;
  final String _password;
  final String _db;
  final List<int> _scrambleBuffer;
  final int _clientFlags;
  final int _maxPacketSize;
  final int _collation;
  
  _AuthHandler(String this._username, String this._password, String this._db,
    List<int> this._scrambleBuffer, int this._clientFlags,
    int this._maxPacketSize, int this._collation) {
    log = new Logger("AuthHandler");
  }
  
  _Buffer createRequest() {
    // calculate the mysql password hash
    List<int> hash;
    if (_password == null) {
      hash = <int>[];
    } else {
      var hasher = new SHA1();
      hasher.add(_password.codeUnits);
      var hashedPassword = hasher.close();
      
      hasher = new SHA1();
      hasher.add(hashedPassword);
      var doubleHashedPassword = hasher.close();
      
      hasher = new SHA1();
      hasher.add(_scrambleBuffer);
      hasher.add(doubleHashedPassword);
      var hashedSaltedPassword = hasher.close();
      
      hash = new List<int>(hashedSaltedPassword.length);
      for (var i = 0; i < hash.length; i++) {
        hash[i] = hashedSaltedPassword[i] ^ hashedPassword[i];
      }
    }

    var size = hash.length + _username.length + 2 + 32;
    var clientFlags = _clientFlags;
    if (_db != null) {
      size += _db.length + 1;
      clientFlags |= CLIENT_CONNECT_WITH_DB;
    }
    
    var buffer = new _Buffer(size);
    buffer.seekWrite(0);
    buffer.writeInt32(clientFlags);
    buffer.writeInt32(_maxPacketSize);
    buffer.writeByte(_collation);
    buffer.fill(23, 0);
    buffer.writeNullTerminatedString(_username);
    buffer.writeByte(hash.length);
    buffer.writeList(hash);
    
    if (_db != null) {
      buffer.writeNullTerminatedString(_db);
    }
    
    return buffer;
  }
  
  dynamic processResponse(_Buffer response) {
    var result = checkResponse(response);
    _finished = true;
    return result;
  }
}
