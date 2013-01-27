library unit_test;

import 'unit/buffer_test.dart';
import 'unit/serialize_test.dart';
import 'unit/types_test.dart';

void main() {
  runBufferTests();
  runSerializationTests();
  runTypesTests();
}