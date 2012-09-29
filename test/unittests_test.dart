#library("unittests");

#import("package:sqljocky/sqljocky.dart");
#import("package:unittest/unittest.dart");

#source("unit/buffertest.dart");
#source("unit/serializetest.dart");

void main() {
  runBufferTests();
  runSerializationTests();
}