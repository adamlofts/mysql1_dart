double listToFloat(List<int> list) {
  int num = (list[3] << 24) + (list[2] << 16) + (list[1] << 8) + list[0];
  if (num > 0xFF800000) {
    return -0/0; // -NaN
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
    return -0/0; // -NaN
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
  //TODO: handle infinities and nans
  List<int> list = new List<int>(4);
  if (num.isInfinite()) {
    if (num.isNegative()) {
      // -Infinity
      list[0] = 0x00;
      list[1] = 0x00;
      list[2] = 0x00;
      list[3] = 0xF8;
      return list;
    } else {
      // +Infinity
      list[0] = 0x00;
      list[1] = 0x00;
      list[2] = 0x80;
      list[3] = 0x7F;
      return list;
    }
  } else if (num.isNaN()) {
    if (num.isNegative()) {
      // -NaN
      list[0] = 0x01;
      list[1] = 0x00;
      list[2] = 0x80;
      list[3] = 0xFF;
      return list;
    } else {
      // +NaN
      list[0] = 0x01;
      list[1] = 0x00;
      list[2] = 0x80;
      list[3] = 0x7F;
      return list;
    }
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
  list[3] = (sign << 7) + ((exp & 0xFE) >> 1);
  list[2] = ((exp & 0x01) << 7) + ((sig >> 16) & 0x7F);
  list[1] = (sig >> 8) & 0xFF;
  list[0] = sig & 0xFF;
  return list;
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

