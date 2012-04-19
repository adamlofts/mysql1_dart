#import('lib/sqljocky.dart');
#import('tests/unittests.dart');

void main() {
  Log.initialize();
  
  print("Starting tests");
  BufferTest bufferTest = new BufferTest();
  bufferTest.runAll();
  MathsTest mathsTest = new MathsTest();
  mathsTest.runAll();
  print("Finished tests");
}