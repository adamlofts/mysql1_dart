library mysql1.my_sql_exception;

import 'buffer.dart';

MySqlException createMySqlException(Buffer buffer) => MySqlException._(buffer);

/// An exception which is returned by the MySQL server.
class MySqlException implements Exception {
  /// The MySQL error number
  final int errorNumber;

  /// A five character ANSI SQLSTATE value
  final String sqlState;

  /// A textual description of the error
  final String message;

  MySqlException._raw(this.errorNumber, this.sqlState, this.message);

  /// Create a [MySqlException] based on an error response from the mysql server
  factory MySqlException._(Buffer buffer) {
    buffer.seek(1);
    var errorNumber = buffer.readUint16();
    buffer.skip(1);
    var sqlState = buffer.readString(5);
    var message = buffer.readStringToEnd();
    return MySqlException._raw(errorNumber, sqlState, message);
  }

  @override
  String toString() => 'Error $errorNumber ($sqlState): $message';
}
