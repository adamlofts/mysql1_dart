#import('lib/sqljocky.dart');
#import('tests/integration.dart');
#import('dart:io');
#import('options.dart');

void main() {
  Log.initialize(false);
  
  OptionsFile options = new OptionsFile('connection.options');
  String user = options.getString('user');
  String password = options.getString('password');
  int port = options.getInt('port', 3306);
  String db = options.getString('db');
  String host = options.getString('host', 'localhost');
  
  runTests(user, password, db, port, host);
}
