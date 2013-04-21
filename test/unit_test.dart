library unit_test;

import 'unit/buffer_test.dart';
import 'unit/serialize_test.dart';
import 'unit/types_test.dart';
import 'unit/prepared_statements_test.dart';
import 'unit/handlers_test.dart';

void main() {
  runBufferTests();
  runSerializationTests();
  runTypesTests();
  runPreparedStatementTests();
}