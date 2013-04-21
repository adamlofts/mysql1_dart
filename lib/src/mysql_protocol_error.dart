part of sqljocky;

/**
 * [MySqlProtocolError] is thrown when something unexpected is read from the the MySQL protocol.
 */
class MySqlProtocolError implements Error {
  final String message;
  
  /**
   * Create a [MySqlProtocolError]
   */
  const MySqlProtocolError._(this.message);
  
  String toString() => "MySQL Protocol Error: $message";
}


