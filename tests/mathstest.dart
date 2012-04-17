class MathsTest {
  void canWriteZero() {
    double n = 0.0;
    List<int> bytes = floatToList(n);
    Expect.equals("00000000", listToHexString(bytes, true));
  }
  
  void canWriteOneOrGreater() {
    double n = 1.0;
    List<int> bytes = floatToList(n);
    Expect.equals("3F800000", listToHexString(bytes, true));
    
    n = 100.0;
    bytes = floatToList(n);
    Expect.equals("42C80000", listToHexString(bytes, true));
    
    n = 123487.982374;
    bytes = floatToList(n);
    Expect.equals("47F12FFD", listToHexString(bytes, true));

    n = 10000000000000000000000000000.0;
    bytes = floatToList(n);
    Expect.equals("6E013F39", listToHexString(bytes, true));
    
    // TODO: test very large numbers
  }
  
  void canWriteLessThanOne() {
    double n = 0.1;
    List<int> bytes = floatToList(n);
    Expect.equals("3DCCCCCC", listToHexString(bytes, true));
    
    // TODO: test very small numbers
    n = 3.4028234663852886E+38;
    print(n);
    bytes = floatToList(n);
    Expect.equals("7F7FFFFF", listToHexString(bytes, true));
    
    n = 1.1754943508222875E-38;
    print(n);
    bytes = floatToList(n);
    Expect.equals("00800000", listToHexString(bytes, true));
  }
  
  
  void canWriteNonNumbers() {
    double n = 1.0/0.0;
    List<int> bytes = floatToList(n);
    Expect.equals("7F800000", listToHexString(bytes, true));

    n = -1.0/0.0;
    bytes = floatToList(n);
    Expect.equals("F8000000", listToHexString(bytes, true));

    n = 0.0/0.0;
    bytes = floatToList(n);
    Expect.equals("7F800001", listToHexString(bytes, true));
}
  
  void runAll() {
    canWriteZero();
    canWriteOneOrGreater();
    canWriteLessThanOne();
    canWriteNonNumbers();
  }
}
