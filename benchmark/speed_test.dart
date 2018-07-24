@Skip("API Update")

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:options_file/options_file.dart';
import 'package:sqljocky5/sqljocky.dart';
import 'package:test/test.dart';

class SpeedTest {
  static const SIMPLE_INSERTS = 200;
  static const PREPARED_INSERTS = 200;
  static const POOL_SIZE = 1;

  ConnectionPool pool;
  Logger log;

  SpeedTest(this.pool) : log = new Logger("Speed");

  Future run() async {
    await dropTables();
    await createTables();
    await insertSimpleData();
    await insertPreparedData();
    await selectPreparedData();
    await pool.closeConnectionsWhenNotInUse();
  }

  Future dropTables() {
    log.fine("dropping tables");
    var dropper = new TableDropper(pool, ['pets', 'people']);
    return dropper.dropTables();
  }

  Future createTables() {
    log.fine("creating tables");
    var querier = new QueryRunner(pool, [
      'create table people (id integer not null auto_increment, '
          'name varchar(255), '
          'age integer, '
          'primary key (id))',
      'create table pets (id integer not null auto_increment, '
          'name varchar(255), '
          'species varchar(255), '
          'owner_id integer, '
          'primary key (id),'
          'foreign key (owner_id) references people (id))'
    ]);
    log.fine("executing queries");
    return querier.executeQueries();
  }

  Future insertSimpleData() async {
    log.fine("inserting simple data");
    var sw = new Stopwatch()..start();
    var futures = <Future>[];
    for (var i = 0; i < SIMPLE_INSERTS; i++) {
      futures.add(
          pool.query("insert into people (name, age) values ('person$i', $i)"));
    }
    await Future.wait(futures);
    logTime("simple insertions", sw);
    log.fine("inserted");
  }

  Future insertPreparedData() async {
    log.fine("inserting prepared data");
    var sw = new Stopwatch()..start();
    var futures = <Future>[];
    var query =
        await pool.prepare("insert into people (name, age) values (?, ?)");
    for (var i = 0; i < PREPARED_INSERTS; i++) {
      futures.add(query.execute(["person$i", i]));
    }
    await Future.wait(futures);
    logTime("prepared insertions", sw);
    log.fine("inserted");
  }

  Future selectPreparedData() async {
    log.fine("inserting prepared data");
    var sw = new Stopwatch()..start();
    var futures = <Future>[];
    var query = await pool.prepare("select * from people where id = ?");
    for (var i = 0; i < PREPARED_INSERTS; i++) {
      futures.add(query.execute([1]));
    }
    await Future.wait(futures);
    logTime("prepared selections", sw);
    log.fine("selected");
  }

  void logTime(String operation, Stopwatch sw) {
    var time = sw.elapsedMicroseconds;
    var seconds = time / 1000000;
    log.fine("$operation took: ${seconds}s");
  }
}

main() async {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.OFF;
//  new Logger("ConnectionPool").level = Level.ALL;
//  new Logger("Connection.Lifecycle").level = Level.ALL;
//  new Logger("Query").level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord r) {
    print("${r.time}: ${r.loggerName}: ${r.message}");
  });

  var log = new Logger("Speed");
  log.level = Level.ALL;

  var options = new OptionsFile('connection.options');
  var user = options.getString('user');
  var password = options.getString('password');
  var port = options.getInt('port', 3306);
  var db = options.getString('db');
  var host = options.getString('host', 'localhost');

  // create a connection
  log.fine("opening connection");
  var pool = new ConnectionPool(
      host: host,
      port: port,
      user: user,
      password: password,
      db: db,
      max: SpeedTest.POOL_SIZE);
  log.fine("connection open");

  var stopwatch = new Stopwatch()..start();
  await new SpeedTest(pool).run();
  var time = stopwatch.elapsedMicroseconds;
  var seconds = time / 1000000;
  log.fine("Time taken: ${seconds}s");
}
