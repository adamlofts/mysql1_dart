library integrationtests;

import 'dart:async';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:options_file/options_file.dart';
import 'package:sqljocky/constants.dart';
import 'package:sqljocky/sqljocky.dart';
import 'package:sqljocky/utils.dart';
import 'package:test/test.dart';

part 'integration/base.dart';
part 'integration/blob.dart';
part 'integration/charset.dart';
part 'integration/errors.dart';
part 'integration/execute_multi.dart';
part 'integration/largeblob.dart';
part 'integration/nullmap.dart';
part 'integration/numbers.dart';
part 'integration/one.dart';
part 'integration/prepared_query.dart';
part 'integration/row.dart';
part 'integration/stored_procedures.dart';
part 'integration/stream.dart';
part 'integration/two.dart';

void main() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.OFF;
//  new Logger("ConnectionPool").level = Level.ALL;
//  new Logger("Query").level = Level.ALL;
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
  var password = options.getString('password', null);
  var port = options.getInt('port', 3306);
  var db = options.getString('db');
  var host = options.getString('host', 'localhost');

  runPreparedQueryTests(user, password, db, port, host);
  runIntTests(user, password, db, port, host);
  runIntTests2(user, password, db, port, host);
  runCharsetTests(user, password, db, port, host);
  runNullMapTests(user, password, db, port, host);
  runNumberTests(user, password, db, port, host);
  runStreamTests(user, password, db, port, host);
  runRowTests(user, password, db, port, host);
  runErrorTests(user, password, db, port, host);
  runBlobTests(user, password, db, port, host);
//  runStoredProcedureTests(user, password, db, port, host);
  runExecuteMultiTests(user, password, db, port, host);
//  if (results['large_packets'] == 'true') {
//    runLargeBlobTests(user, password, db, port, host);
//  }
}
