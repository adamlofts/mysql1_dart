#import('tests/tests.dart');

void main() {
  print("Starting tests");
  BufferTest bufferTest = new BufferTest();
  bufferTest.runAll();
  MathsTest mathsTest = new MathsTest();
  mathsTest.runAll();
  print("Finished tests");
}