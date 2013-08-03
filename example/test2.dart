import 'dart:async';

a() {
  var c = new Completer();
  Timer.run(() {
    throw "bob";
    c.complete(0);
  });
  return c.future;
}


main() {
//  try {
//    a().then((_) {
//      print("done");
//    })
//    .catchError((e) {
//      print("error $e");
//    });
//  } catch (e) {
//    print("ERROR $e");
//  }
  
  runZonedExperimental(a, onDone: () {
    print("done");
  }, onError: (e) {
    print("error $e");
  });
}