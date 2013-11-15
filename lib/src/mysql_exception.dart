part of sqljocky;

/**
 * An exception which is returned by the MySQL server.
 */
class MySqlException implements Exception {
  int _errorNumber;
  String _sqlState;
  String _message;
  
  /// The MySQL error number
  int get errorNumber => _errorNumber;
  
  /// A five character ANSI SQLSTATE value
  String get sqlState => _sqlState;
  
  /// A textual description of the error
  String get message => _message;
  
  /**
   * Create a [MySqlException] based on an error response from the mysql server
   */
  MySqlException._(Buffer buffer) {
    buffer.seek(1);
    _errorNumber = buffer.readUint16();
    buffer.skip(1);
    _sqlState = buffer.readString(5);
    _message = buffer.readStringToEnd();
  }
  
  String toString() => "Error $_errorNumber ($_sqlState): $_message";
}
