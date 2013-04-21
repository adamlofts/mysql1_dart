part of sqljocky;

class MySqlException implements Exception {
  final int errorNumber;
  final String sqlState;
  final String message;
  
  /**
   * Create a [MySqlException] based on an error response from the mysql server
   */
  MySqlException._(_Buffer buffer) {
    buffer.seek(1);
    errorNumber = buffer.readInt16();
    buffer.skip(1);
    sqlState = buffer.readString(5);
    message = buffer.readStringToEnd();
  }
  
  String toString() => "Error $errorNumber ($sqlState): $message";
}
