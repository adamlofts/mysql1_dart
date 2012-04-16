class MathsTest {
  void canWriteZero() {
    double n = 0.0;
    List<int> bytes = floatToList(n);
    Expect.equals(listToHexString(bytes, true), "00000000");
  }
  
  void canWriteOneOrGreater() {
    double n = 1.0;
    List<int> bytes = floatToList(n);
    Expect.equals(listToHexString(bytes, true), "3F800000");
    
    n = 100.0;
    bytes = floatToList(n);
    Expect.equals(listToHexString(bytes, true), "42C80000");
    
    n = 123487.982374;
    bytes = floatToList(n);
    Expect.equals(listToHexString(bytes, true), "47F12FFD");

    n = 10000000000000000000000000000.0;
    bytes = floatToList(n);
    Expect.equals(listToHexString(bytes, true), "6E013F39");
    
    // TODO: test very large numbers
  }
  
  void canWriteLessThanOne() {
    double n = 0.1;
    List<int> bytes = floatToList(n);
    Expect.equals(listToHexString(bytes, true), "3DCCCCCC");
    
    // TODO: test very small numbers
  }
  
  void canWriteNonNumbers() {
    double n = 1.0/0.0;
    List<int> bytes = floatToList(n);
    Expect.equals(listToHexString(bytes, true), "7F800000");

    n = -1.0/0.0;
    bytes = floatToList(n);
    Expect.equals(listToHexString(bytes, true), "F8000000");

    n = 0.0/0.0;
    bytes = floatToList(n);
    Expect.equals(listToHexString(bytes, true), "7F800001");
}
  
  void runAll() {
    canWriteZero();
    canWriteOneOrGreater();
    canWriteLessThanOne();
    canWriteNonNumbers();
  }
}
