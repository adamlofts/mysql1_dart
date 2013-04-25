library integrationtests;

import 'package:sqljocky/sqljocky.dart';
import 'package:sqljocky/constants.dart';
import 'package:options_file/options_file.dart';
import 'package:unittest/unittest.dart';
import 'package:logging/logging.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typeddata';
import 'package:sqljocky/utils.dart';

part 'integration/one.dart';

void main() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.ALL;
  new Logger("ConnectionPool").level = Level.ALL;
  new Logger("Query").level = Level.ALL;
  var listener = (LogRecord r) {
    var name = r.loggerName;
    if (name.length > 15) {
      name = name.substring(0, 15);
    }
    while (name.length < 15) {
      name = "$name ";
    }
    print("${r.time}: $name: ${r.message}");
  };
  Logger.root.onRecord.listen(listener);

  var options = new OptionsFile('connection.options');
  var user = options.getString('user');
  var password = options.getString('password');
  var port = options.getInt('port', 3306);
  var db = options.getString('db');
  var host = options.getString('host', 'localhost');
  
  runIntTests(user, password, db, port, host);
}
