// Results and Field are deprecated and still exported, which is the point of
// keeping them. The analyzer in Dart 3.0 reports naming them here.
// ignore_for_file: deprecated_member_use_from_same_package

library mysql1;

export 'src/blob.dart';
export 'src/mysql_client_error.dart' show MySqlClientError;
export 'src/mysql_exception.dart' hide createMySqlException;
export 'src/mysql_protocol_error.dart' hide createMySqlProtocolError;
export 'src/single_connection.dart'
    show
        MySqlConnection,
        TransactionContext,
        Result,
        Results,
        ConnectionSettings;

export 'src/constants.dart' show CharacterSet;

export 'src/results/field.dart' show ResultSchemaColumn, Field;
export 'src/results/row.dart';
export 'src/results/schema.dart';
