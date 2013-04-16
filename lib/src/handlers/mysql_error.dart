part of sqljocky;

class MySqlError {
  int _errorNumber;
  String _sqlState;
  String _message;
  
  int get errorNumber => _errorNumber;
  String get sqlState => _sqlState;
  String get message => _message;
  
  /**
   * Create a [MySqlError] based on an error response from the mysql server
   */
  MySqlError(Buffer buffer) {
    buffer.seek(1);
    _errorNumber = buffer.readInt16();
    buffer.skip(1);
    _sqlState = buffer.readString(5);
    _message = buffer.readStringToEnd();
  }
  
  String toString() => "Error $errorNumber ($sqlState): $message";
}
