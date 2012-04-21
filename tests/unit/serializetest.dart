final double SMALLEST_POSITIVE_SUBNORMAL_FLOAT = 1.4012984643248170E-45;
final double LARGEST_POSITIVE_SUBNORMAL_FLOAT = 1.1754942106924411E-38;
final double SMALLEST_POSITIVE_NORMAL_FLOAT = 1.1754943508222875E-38;
final double LARGEST_POSITIVE_NORMAL_FLOAT = 3.4028234663852886E+38;

final double LARGEST_NEGATIVE_NORMAL_FLOAT = -1.1754943508222875E-38; // closest to zero
final double SMALLEST_NEGATIVE_NORMAL_FLOAT = -3.4028234663852886E+38; // most negative
final double LARGEST_NEGATIVE_SUBNORMAL_FLOAT = -1.1754942106924411E-38;
final double SMALLEST_NEGATIVE_SUBNORMAL_FLOAT = -1.4012984643248170E-45;

final double SMALLEST_POSITIVE_SUBNORMAL_DOUBLE = 4.9406564584124654E-324;
final double LARGEST_POSITIVE_SUBNORMAL_DOUBLE = 2.2250738585072010E-308;
final double SMALLEST_POSITIVE_NORMAL_DOUBLE = 2.2250738585072014E-308;
final double LARGEST_POSITIVE_NORMAL_DOUBLE = 1.7976931348623157E+308;

final double LARGEST_NEGATIVE_NORMAL_DOUBLE = -2.2250738585072014E-308; // closest to zero
final double SMALLEST_NEGATIVE_NORMAL_DOUBLE = -1.7976931348623157E+308; // most negative
final double LARGEST_NEGATIVE_SUBNORMAL_DOUBLE = -4.9406564584124654E-324;
final double SMALLEST_NEGATIVE_SUBNORMAL_DOUBLE = -2.2250738585072010E-308;

String bufferToHexString(Buffer list, [bool reverse=false]) {
  String s = "";
  for (int i = 0; i < list.length; i++) {
    var x = list[reverse ? list.length - i - 1 : i].toRadixString(16);
    if (x.length == 1) {
      s += "0";
    }
    s += x;
  }
  return s;
}

void runSerializationTests() {
  group('serialization:', () {
    test('can write zero float', () {
      Buffer buffer = new Buffer(4);
      double n = 0.0;
      buffer.writeFloat(n);
      Expect.equals("00000000", bufferToHexString(buffer, true));
    });
  
    test('can write zero double', () {
      Buffer buffer = new Buffer(8);
      double n = 0.0;
      buffer.writeDouble(n);
      Expect.equals("0000000000000000", bufferToHexString(buffer, true));
    });
  
    test('can write one or greater float', () {
      Buffer buffer = new Buffer(4);
      double n = 1.0;
      buffer.writeFloat(n);
      Expect.equals("3F800000", bufferToHexString(buffer, true));
      
      n = 100.0;
      buffer.reset();
      buffer.writeFloat(n);
      Expect.equals("42C80000", bufferToHexString(buffer, true));
      
      n = 123487.982374;
      buffer.reset();
      buffer.writeFloat(n);
      Expect.equals("47F12FFE", bufferToHexString(buffer, true));
  
      n = 10000000000000000000000000000.0;
      buffer.reset();
      buffer.writeFloat(n);
      Expect.equals("6E013F39", bufferToHexString(buffer, true));
      
      // TODO: test very large numbers
    });
  
    test('can write one or greater double', () {
      Buffer buffer = new Buffer(8);
      double n = 1.0;
      buffer.writeDouble(n);
      Expect.equals("3FF0000000000000", bufferToHexString(buffer, true));
      
      n = 100.0;
      buffer.reset();
      buffer.writeDouble(n);
      Expect.equals("4059000000000000", bufferToHexString(buffer, true));
      
      n = 123487.982374;
      buffer.reset();
      buffer.writeDouble(n);
      Expect.equals("40FE25FFB7CDCCA7", bufferToHexString(buffer, true));
  
      n = 10000000000000000000000000000.0;
      buffer.reset();
      buffer.writeDouble(n);
      Expect.equals("45C027E72F1F1281", bufferToHexString(buffer, true));
      
      // TODO: test very large numbers
    });
  
    test('can write less than one float', () {
      Buffer buffer = new Buffer(4);
      
      double n = 0.1;
      buffer.writeFloat(n);
      Expect.equals("3DCCCCCD", bufferToHexString(buffer, true));
      
      // TODO: test very small numbers
      n = 3.4028234663852886E+38;
      buffer.reset();
      buffer.writeFloat(n);
      Expect.equals("7F7FFFFF", bufferToHexString(buffer, true));
      
      n = 1.1754943508222875E-38;
      buffer.reset();
      buffer.writeFloat(n);
      Expect.equals("00800000", bufferToHexString(buffer, true));
      
      n = SMALLEST_POSITIVE_SUBNORMAL_FLOAT / 2;
      buffer.reset();
      buffer.writeFloat(n);
      Expect.equals("00000000", bufferToHexString(buffer, true));
    });
  
    test('can write less than one double', () {
      Buffer buffer = new Buffer(8);
      
      double n = 0.1;
      buffer.writeDouble(n);
      Expect.equals("3FB999999999999A", bufferToHexString(buffer, true));
      
      // TODO: test very small numbers
      n = 1.7976931348623157E+308;
      buffer.reset();
      buffer.writeDouble(n);
      Expect.equals("7FEFFFFFFFFFFFFF", bufferToHexString(buffer, true));
      
      n = -1.7976931348623157E+308;
      buffer.reset();
      buffer.writeDouble(n);
      Expect.equals("FFEFFFFFFFFFFFFF", bufferToHexString(buffer, true));
    });
  
    test('can write non numbers float', () {
      Buffer buffer = new Buffer(4);
      
      double n = 1.0/0.0;
      buffer.writeFloat(n);
      Expect.equals("7F800000", bufferToHexString(buffer, true));
  
      n = -1.0/0.0;
      buffer.reset();
      buffer.writeFloat(n);
      Expect.equals("FF800000", bufferToHexString(buffer, true));
  
      n = 0.0/0.0;
      buffer.reset();
      buffer.writeFloat(n);
      Expect.equals("FFC00000", bufferToHexString(buffer, true));
    });
  
    test('can write non numbers double', () {
      Buffer buffer = new Buffer(8);
      
      double n = 1.0/0.0;
      buffer.writeDouble(n);
      Expect.equals("7FF0000000000000", bufferToHexString(buffer, true));
  
      n = -1.0/0.0;
      buffer.reset();
      buffer.writeDouble(n);
      Expect.equals("FFF0000000000000", bufferToHexString(buffer, true));
  
      n = 0.0/0.0;
      buffer.reset();
      buffer.writeDouble(n);
      Expect.equals("FFF8000000000000", bufferToHexString(buffer, true));
    });
  });
}

