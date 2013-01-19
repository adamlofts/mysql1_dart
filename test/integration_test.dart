library integrationtests;

import 'package:sqljocky/sqljocky.dart';
import 'package:sqljocky/constants.dart';
import 'package:options_file/options_file.dart';
import 'package:unittest/unittest.dart';
import 'package:logging/logging.dart';
import 'dart:async';
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

  var options = new OptionsFile('connection.options');
  var user = options.getString('user');
  var password = options.getString('password');
  var port = options.getInt('port', 3306);
  var db = options.getString('db');
  var host = options.getString('host', 'localhost');
  
  runIntTests(user, password, db, port, host);
}
