part of sqljocky;

/**
 * [MySqlClientError] is thrown when the client is used improperly.
 */
class MySqlClientError implements Error {
  final String message;
  
  /**
   * Create a [MySqlClientError]
   */
  const MySqlClientError._(this.message);
  
  String toString() => "MySQL Client Error: $message";
}




