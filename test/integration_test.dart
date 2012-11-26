library integrationtests;

import 'package:sqljocky/sqljocky.dart';
import 'package:sqljocky/constants.dart';
import 'package:options_file/options_file.dart';
import 'package:unittest/unittest.dart';
import 'package:logging/logging.dart';
import 'dart:io';
import 'dart:scalarlist';

part 'integration/one.dart';

void main() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.OFF;
  new Logger("ConnectionPool").level = Level.ALL;
  new Logger("Query").level = Level.ALL;
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
