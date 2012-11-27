library unittests;

import 'package:sqljocky/buffer.dart';
import 'package:unittest/unittest.dart';

part 'unit/buffertest.dart';
part 'unit/serializetest.dart';

void main() {
  runBufferTests();
  runSerializationTests();
}