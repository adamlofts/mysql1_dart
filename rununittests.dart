#import('lib/sqljocky.dart');
#import('tests/unittests.dart');

void main() {
  Log.initialize();
  
  runBufferTests();
  runSerializationTests();
}