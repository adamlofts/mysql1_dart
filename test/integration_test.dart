#library('integrationtests');

#import("package:sqljocky/sqljocky.dart");
#import("dart:scalarlist");
#import("package:unittest/unittest.dart");
#import("package:logging/logging.dart");
#import('dart:io');
#import('package:optionsfile/options.dart');

#source("integration/one.dart");

void main() {
  Logger.root.level = Level.ALL;
  var loggerHandlerList = new LoggerHandlerList(Logger.root);
  loggerHandlerList.add((LogRecord r) {
    print("${r.time}: ${r.message}");
  });

  OptionsFile options = new OptionsFile('connection.options');
  String user = options.getString('user');
  String password = options.getString('password');
  int port = options.getInt('port', 3306);
  String db = options.getString('db');
  String host = options.getString('host', 'localhost');
  
  runIntTests(user, password, db, port, host);
}
