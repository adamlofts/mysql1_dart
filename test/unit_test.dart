library sqljocky;

import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:collection';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart';

import 'package:sqljocky/constants.dart';
import 'package:sqljocky/src/buffer.dart';
import 'package:sqljocky/src/results.dart';

part '../lib/src/auth/auth_handler.dart';
part '../lib/src/blob.dart';
part '../lib/src/handlers/handler.dart';
part '../lib/src/handlers/ok_packet.dart';
part '../lib/src/mysql_client_error.dart';
part '../lib/src/mysql_exception.dart';
part '../lib/src/prepared_statements/binary_data_packet.dart';
part '../lib/src/prepared_statements/prepare_ok_packet.dart';
part '../lib/src/results/field_impl.dart';
part '../lib/src/results/results_impl.dart';
part '../lib/src/query/query_stream_handler.dart';
part '../lib/src/query/result_set_header_packet.dart';
part '../lib/src/query/standard_data_packet.dart';

part 'unit/buffer_test.dart';
part 'unit/handlers_test.dart';
part 'unit/prepared_statements_test.dart';
part 'unit/serialize_test.dart';
part 'unit/types_test.dart';
part 'unit/field_by_name_test.dart';

void main() {
  runBufferTests();
  runSerializationTests();
  runTypesTests();
  runPreparedStatementTests();
  runAuthHandlerTests();
  runFieldByNameTests();
}
