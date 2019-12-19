library mysql1.mysql_client_error;

///
/// An error which is thrown when the client is used improperly.
///
class MySqlClientError extends Error {
  final String message;

  MySqlClientError(this.message);

  @override
  String toString() => 'MySQL Client Error: $message';
}
