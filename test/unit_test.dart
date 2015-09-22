library sqljocky;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:sqljocky/constants.dart';
import 'package:sqljocky/src/buffer.dart';
import 'package:sqljocky/src/buffered_socket.dart';
import 'package:sqljocky/src/results.dart';
import 'package:test/test.dart';

import 'unit/buffered_socket_test.dart';

part '../lib/src/auth/auth_handler.dart';
part '../lib/src/auth/handshake_handler.dart';
part '../lib/src/auth/ssl_handler.dart';
part '../lib/src/auth/character_set.dart';
part '../lib/src/blob.dart';
part '../lib/src/connection.dart';
part '../lib/src/connection_pool.dart';
part '../lib/src/handlers/handler.dart';
part '../lib/src/handlers/ok_packet.dart';
part '../lib/src/handlers/use_db_handler.dart';
part '../lib/src/mysql_client_error.dart';
part '../lib/src/mysql_exception.dart';
part '../lib/src/mysql_protocol_error.dart';
part '../lib/src/prepared_statements/binary_data_packet.dart';
part '../lib/src/prepared_statements/prepare_ok_packet.dart';
part '../lib/src/prepared_statements/execute_query_handler.dart';
part '../lib/src/prepared_statements/prepared_query.dart';
part '../lib/src/prepared_statements/prepare_handler.dart';
part '../lib/src/results/field_impl.dart';
part '../lib/src/results/results_impl.dart';
part '../lib/src/query/query_stream_handler.dart';
part '../lib/src/query/result_set_header_packet.dart';
part '../lib/src/query/standard_data_packet.dart';

part 'unit/buffer_test.dart';
part 'unit/auth_handler_test.dart';
part 'unit/prepared_statements_test.dart';
part 'unit/serialize_test.dart';
part 'unit/types_test.dart';
part 'unit/field_by_name_test.dart';
part 'unit/binary_data_packet_test.dart';
part 'unit/execute_query_handler_test.dart';
part 'unit/handshake_handler_test.dart';
part 'unit/connection_test.dart';

void main() {
  runBufferTests();
  runBufferedSocketTests();
  runSerializationTests();
  runTypesTests();
  runPreparedStatementTests();
  runAuthHandlerTests();
  runFieldByNameTests();
  runBinaryDataPacketTests();
  runExecuteQueryHandlerTests();
  runHandshakeHandlerTests();
  runConnectionTests();
}
