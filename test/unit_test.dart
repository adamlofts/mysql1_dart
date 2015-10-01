library sqljocky;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:sqljocky/constants.dart';
import 'package:sqljocky/src/buffer.dart';
import 'package:sqljocky/src/buffered_socket.dart';
import 'package:sqljocky/src/results/field_impl.dart';
import 'package:sqljocky/src/results/results.dart';
import 'package:sqljocky/src/results/row.dart';
import 'package:test/test.dart';

import 'package:sqljocky/src/blob.dart';
import 'package:sqljocky/src/auth/handshake_handler.dart';
import 'package:sqljocky/src/auth/ssl_handler.dart';
import 'package:sqljocky/src/handlers/handler.dart';
import 'package:sqljocky/src/handlers/ok_packet.dart';
import 'package:sqljocky/src/mysql_client_error.dart';
import 'package:sqljocky/src/mysql_exception.dart';
import 'package:sqljocky/src/mysql_protocol_error.dart';

import 'package:sqljocky/src/prepared_statements/prepare_ok_packet.dart';
import 'package:sqljocky/src/prepared_statements/binary_data_packet.dart';

import 'package:sqljocky/src/results/results_impl.dart';

import 'package:sqljocky/src/query/query_stream_handler.dart';
import 'package:sqljocky/src/query/result_set_header_packet.dart';
import 'package:sqljocky/src/query/standard_data_packet.dart';

part '../lib/src/connection.dart';
part '../lib/src/connection_pool.dart';
part '../lib/src/handlers/use_db_handler.dart';
part '../lib/src/prepared_statements/execute_query_handler.dart';
part '../lib/src/prepared_statements/prepared_query.dart';
part '../lib/src/prepared_statements/prepare_handler.dart';

part 'unit/test_field_by_name.dart';
part 'unit/test_binary_data_packet.dart';
part 'unit/test_execute_query_handler.dart';
part 'unit/test_connection.dart';

void main() {
  runFieldByNameTests();
  runBinaryDataPacketTests();
  runExecuteQueryHandlerTests();
  runConnectionTests();
}
