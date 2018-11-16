/*
 * This example drops a couple of tables if they exist, before recreating them.
 * It then stores some data in the database and reads it back out.
 * You must have a connection.options file in order for this to connect.
 */

void main() {}

/*
SKIPPED - NEEDS MIGRATION

class Example {
  var insertedIds = [];
  var rnd = new Random();
  ConnectionPool pool;

  Example(this.pool);

  Future run() async {
    // drop the tables if they already exist
    await dropTables();
    print("dropped tables");
    // then recreate the tables
    await createTables();
    print("created tables");
    // add some data
    var futures = new List<Future>();
    for (var i = 0; i < 10; i++) {
      futures.add(addDataInTransaction());
      futures.add(readData());
    }
    print("queued all operations");
    await Future.wait(futures);
    print("data added and read");
  }

  Future dropTables() {
    print("dropping tables");
    var dropper = new TableDropper(pool, ['pets', 'people']);
    return dropper.dropTables();
  }

  Future createTables() {
    print("creating tables");
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
    print("executing queries");
    return querier.executeQueries();
  }

  Future addData() async {
    print("adding");
    var query =
        await pool.prepare("insert into people (name, age) values (?, ?)");
    var parameters = [
      ["Dave", 15],
      ["John", 16],
      ["Mavis", 93]
    ];
    await query.executeMulti(parameters);
    query = await pool
        .prepare("insert into pets (name, species, owner_id) values (?, ?, ?)");
    parameters = [
      ["Rover", "Dog", 1],
      ["Daisy", "Cow", 2],
      ["Spot", "Dog", 2]
    ];
    await query.executeMulti(parameters);
  }

  Future addDataInTransaction() async {
    print("adding");
    var ids = [];
    var trans; // = await pool.startTransaction();
    var query =
        await trans.prepare("insert into people (name, age) values (?, ?)");
    var parameters = [
      ["Dave", 15],
      ["John", 16],
      ["Mavis", 93]
    ];
    var results = await query.executeMulti(parameters);
    for (var result in results) {
      ids.add(result.insertId);
    }
    print("added people");
    query = await trans
        .prepare("insert into pets (name, species, owner_id) values (?, ?, ?)");
    var id1, id2, id3;
    if (insertedIds.length < 3) {
      id1 = ids[0];
      id2 = ids[1];
      id3 = ids[2];
    } else {
      id1 = insertedIds[rnd.nextInt(insertedIds.length)];
      id2 = insertedIds[rnd.nextInt(insertedIds.length)];
      id3 = insertedIds[rnd.nextInt(insertedIds.length)];
    }
    parameters = [
      ["Rover", "Dog", id1],
      ["Daisy", "Cow", id2],
      ["Spot", "Dog", id3]
    ];
    print("adding pets");
    try {
      results = await query.executeMulti(parameters);
      print("added pets");
    } catch (e) {
      print("Exception: $e");
    }
    print("committing");
    await trans.commit();
    print("committed");
    insertedIds.addAll(ids);
  }

  Future readData() async {
    print("querying");
    var result =
        await pool.query('select p.id, p.name, p.age, t.name, t.species '
            'from people p '
            'left join pets t on t.owner_id = p.id');
    print("got results");
    var list = await result.toList();
    if (list != null) {
      for (var row in list) {
        if (row[3] == null) {
          print("ID: ${row[0]}, Name: ${row[1]}, Age: ${row[2]}, No Pets");
        } else {
          print(
              "ID: ${row[0]}, Name: ${row[1]}, Age: ${row[2]}, Pet Name: ${row[3]}, Pet Species ${row[4]}");
        }
      }
    }
  }
}

void main() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.OFF;
//  new Logger("ConnectionPool").level = Level.ALL;
//  new Logger("Connection.Lifecycle").level = Level.ALL;
//  new Logger("Query").level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord r) {
    print("${r.time}: ${r.loggerName}: ${r.message}");
  });

  var log = new Logger("Interleave");
  log.level = Level.ALL;

  group('interleave', () {
    test('should complete interleaved operations', () async {
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
          max: 5);
      log.fine("connection open");
      // create an example class
      var example = new Example(pool);
      // run the example
      log.fine("running example");
      await example.run();
      // finally, close the connection
      log.fine("closing");
      pool.closeConnectionsWhenNotInUse();
      // not much of a test, is it?
      expect(true, isTrue);
    });
  }, skip: "Skipped for now");
}
*/
