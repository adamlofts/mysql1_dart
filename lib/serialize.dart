//TODO handle very small and very large numbers
//TODO probably should do rounded numbers?

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

double listToFloat(List<int> list) {
  int num = (list[3] << 24) + (list[2] << 16) + (list[1] << 8) + list[0];
  if (num > 0xFF800000) {
    return -0/0; // -NaN but I don't think dart cares about negativity of NaN
  } else if (num == 0xF8000000) {
    return -1/0; // -Infinity
  } else if (num > 0x7F800000 && num < 0x7FFFFFFF) {
    return 0/0; // +NaN
  } else if (num == 0x7F800000) {
    return 1/0; // +Inifinity
  } else {
    int sign = list[3] & 0x80;
    int exponent = ((list[3] & 0x7F) << 1) + ((list[2] & 0x80) >> 7) - 127;
    int significandbits = ((list[2] & 0x7F) << 16) +
        (list[1] << 8) + list[0];
    double significand = significandbits / 0x800000 + 1; 
//    print("sign $sign, exp $exponent sig $significand");
    double result = significand;
    while (exponent > 0) {
      result = result * 2;
      exponent--;
    }
    while (exponent < 0) {
      result = result / 2;
      exponent++;
    }
    if (sign != 0) {
      result = -result;
    }
    return result;
  }
}

double listToDouble(List<int> list) {
  int num = (list[7] << 54) + (list[6] << 48) + (list[5] << 40) + (list[4] << 32) + 
      (list[3] << 24) + (list[2] << 16) + (list[1] << 8) + list[0];
  if (num > 0xFF80000000000000) {
    return -0/0; // -NaN but I don't think dart cares about negativity of NaN
  } else if (num == 0xF800000000000000) {
    return -1/0; // -Infinity
  } else if (num > 0x7F80000000000000 && num < 0x7FFFFFFFFFFFFFFF) {
    return 0/0; // +NaN
  } else if (num == 0x7F80000000000000) {
    return 1/0; // +Inifinity
  } else {
    int sign = list[7] & 0x80;
    int exponent = ((list[7] & 0x7F) << 4) + ((list[6] & 0xF0) >> 4) - 1023;
    int significandbits = ((list[6] & 0x0F) << 48) + (list[5] << 40) + (list[4] << 32) + 
        (list[3] << 24) + (list[2] << 16) + (list[1] << 8) + list[0];
    double significand = significandbits / 0x10000000000000 + 1; 
//    log.debug("sign $sign, exp $exponent sig $significand");
    double result = significand;
    while (exponent > 0) {
      result = result * 2;
      exponent--;
    }
    while (exponent < 0) {
      result = result / 2;
      exponent++;
    }
    if (sign != 0) {
      result = -result;
    }
    return result;
  }
}

List<int> floatToList(double num) {
  // alg uses non-rounded method currently
  //TODO: use rounded method?
  if (num.isNegative() && num > LARGEST_NEGATIVE_SUBNORMAL_FLOAT) {
    num = 0.0;
  } else if (!num.isNegative() && num < SMALLEST_POSITIVE_SUBNORMAL_FLOAT) {
    num = 0.0;
  }
  if (num.isNegative() && num < SMALLEST_NEGATIVE_NORMAL_FLOAT) {
    num = -1/0;
  }
  if (!num.isNegative() && num > LARGEST_POSITIVE_NORMAL_FLOAT) {
    num = 1/0;
  }
  if (num.isInfinite()) {
    if (num.isNegative()) {
      // -Infinity
      return [0, 0, 0, 0xF8];
    } else {
      // +Infinity
      return [0, 0, 0x80, 0x7F];
    }
  } else if (num.isNaN()) {
    // NaN
    return [0x01, 0, 0x80, 0x7F];
  }
  if (num == 0) {
    return [0, 0, 0, 0];
  }
  
  var exp = 0;
  var sign = 0;
  if (num < 0) {
    sign = 1;
    num = -num;
  }
  if (num >=1) {
    while (num > 2) {
      exp++;
      num = num / 2;
    }
  } else {
    while (num < 1) {
      exp--;
      num = num * 2;
    }
  }
  num = num - 1;
  int sig = (num * Math.pow(2, 23)).toInt();
//  print("$num $exp $sig ($num)");
  
  exp += 127;
  return [sig & 0xFF,
          (sig >> 8) & 0xFF,
          ((exp & 0x01) << 7) + ((sig >> 16) & 0x7F),          
          (sign << 7) + ((exp & 0xFE) >> 1)];
}

List<int> doubleToList(double num) {
  // alg uses non-rounded method currently
  //TODO: use rounded method?
  if (num.isInfinite()) {
    if (num.isNegative()) {
      // -Infinity
      return [0, 0, 0, 0, 0, 0, 0xF0, 0xFF];
    } else {
      // +Infinity
      return [0, 0, 0, 0, 0, 0, 0xF0, 0x7F];
    }
  } else if (num.isNaN()) {
    // NaN
    return [0x01, 0, 0, 0, 0, 0, 0xF0, 0xFF];
  }
  if (num == 0) {
    return [0, 0, 0, 0, 0, 0, 0, 0];
  }
  
  var exp = 0;
  var sign = 0;
  if (num < 0) {
    sign = 1;
    num = -num;
  }
  if (num >=1) {
    while (num > 2) {
      exp++;
      num = num / 2;
    }
  } else {
    while (num < 1) {
      exp--;
      num = num * 2;
    }
  }
  num = num - 1;
  int sig = (num * Math.pow(2, 52)).toInt();
//  print("$num $exp $sig ($num)");
  
  exp += 1023;
  return [sig & 0xFF,
          (sig >> 8) & 0xFF,
          (sig >> 16) & 0xFF,
          (sig >> 24) & 0xFF,
          (sig >> 32) & 0xFF,
          (sig >> 40) & 0xFF,
          ((exp & 0x0F) << 4) + ((sig >> 48) & 0x0F),
          (sign << 7) + ((exp & 0x7F0) >> 4)];          
}

String listToHexString(List<int> list, [bool reverse=false]) {
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

