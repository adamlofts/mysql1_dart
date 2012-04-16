#import('lib/sqljocky.dart');
#import('lib/crypto/hash.dart');
#import('lib/crypto/sha1.dart');

double listToDouble(List<int> list) {
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
    print("sign $sign, exp $exponent sig $significand");
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

List<int> doubleToList(double num) {
  // alg uses non-rounded method currently
  //TODO: use rounded method?
  //TODO: handle infinities and nans
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
  
  List<int> list = new List<int>(4);
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

void main() {
  Log log = new Log("main");
  
  var num = 1e-37;
  num = 1e-100;
  num = 12452345234.523452345;
  print(num);
  var list = doubleToList(num);
  var s = listToHexString(list, reverse:true);
  print(s);

  var doub = listToDouble(list);
  print(doub);
  
  return;
  {
    SyncConnection cnx = new SyncMySqlConnection();
    cnx.connect(user:'root').then((nothing) {
      print("connected");
      cnx.useDatabase('bob');
      Results results = cnx.query("select name as bob, age as wibble from people p");
      for (Field field in results.fields) {
        print("Field: ${field.name}");
      }
      for (List<Dynamic> row in results) {
        for (Dynamic field in row) {
          print(field);
        }
      }
      results = cnx.query("select * from blobby");
      Query query = cnx.prepare("select * from types");
      query.execute();
      query.close();
      cnx.close();
    });
  }

  log.debug("starting");
  AsyncConnection cnx = new AsyncMySqlConnection();
  cnx.connect(user:'test', password:'test', db:'bob').then((nothing) {
    log.debug("got connection");
    cnx.useDatabase('bob').then((dummy) {
      cnx.query("select name as bob, age as wibble from people p").then((Results results) {
        log.debug("queried");
        for (Field field in results.fields) {
          print("Field: ${field.name}");
        }
        for (List<Dynamic> row in results) {
          for (Dynamic field in row) {
            log.debug(field);
          }
        }
        cnx.query("select * from blobby").then((Results results2) {
          log.debug("queried");
          
          testPreparedQuery(cnx, log);
        });
      });
    });
  });
}

void testPreparedQuery(AsyncConnection cnx, Log log) {
  cnx.prepare("select * from types").then((query) {
    log.debug("prepared $query");
//    query[0] = 35;
    var res = query.execute().then((dummy) {
      query.close();
      log.debug("stmt closed");
      cnx.close();
    });
  });
}