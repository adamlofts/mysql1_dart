part of sqljocky;

/**
 * [MySqlClientError] is thrown when the client is used improperly.
 */
class MySqlClientError extends Error {
  final String message;
  
  /**
   * Create a [MySqlClientError]
   */
  MySqlClientError._(this.message);
  
  String toString() => "MySQL Client Error: $message";
}




