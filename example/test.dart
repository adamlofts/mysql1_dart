import 'package:sqljocky/sqljocky.dart';

void main() {
  var pool = new ConnectionPool(host: 'localhost', port: 3306, 
             user: 'test', password: 'test', db: 'test', max: 5);
  print('Connected.');
  
  pool.query('select * from test1').then((results) {
    print('Got results');
    results.stream.listen((row) {
      print('$row');
    }, onDone: () {
      pool.close();
    });
  })
  .catchError((e) {
    print('Error $e');
  });
}