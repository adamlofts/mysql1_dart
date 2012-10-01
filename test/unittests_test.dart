library unittests;

import 'package:sqljocky/sqljocky.dart';
import 'package:unittest/unittest.dart';

part 'unit/buffertest.dart';
part 'unit/serializetest.dart';

void main() {
  runBufferTests();
  runSerializationTests();
}