library mysql1.my_sql_exception;

import 'dart:typed_data';

import 'payload.dart';

/// The exception for an error packet, [payload].
MySqlException createMySqlException(Uint8List payload) =>
    MySqlException._(payload);

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
  factory MySqlException._(Uint8List payload) {
    // The marker byte, the number, a '#', the five characters of the SQL
    // state, and the message to the end.
    final reader = PayloadReader(payload)..skip(1);
    final errorNumber = reader.readUint16();
    reader.skip(1);
    final sqlState = reader.readString(5);
    return MySqlException._raw(
        errorNumber, sqlState, reader.readRestAsString());
  }

  @override
  String toString() => 'Error $errorNumber ($sqlState): $message';
}
