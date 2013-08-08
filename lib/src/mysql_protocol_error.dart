part of sqljocky;

/**
 * [MySqlProtocolError] is thrown when something unexpected is read from the the MySQL protocol.
 */
class MySqlProtocolError extends Error {
  final String message;
  
  /**
   * Create a [MySqlProtocolError]
   */
  MySqlProtocolError._(this.message);
}


