import 'package:sqljocky5/sqljocky.dart';
import 'package:options_file/options_file.dart';
import 'dart:async';

/*
 * This example drops a couple of tables if they exist, before recreating them.
 * It then stores some data in the database and reads it back out.
 * You must have a connection.options file in order for this to connect.
 */

class Example {
  MySqlConnection conn;

  Example(this.conn);

  Future run() async {
    // drop the tables if they already exist
//    await dropTables();
//    print("dropped tables");
    // then recreate the tables
    await createTables();
    print("created tables");
    // add some data
    await addData();
    // and read it back out
    await readData();
  }

//  Future dropTables() {
//    print("dropping tables");
//    var dropper = new TableDropper(pool, ['pets', 'people']);
//    return dropper.dropTables();
//  }

  Future createTables() async {
    print("creating tables");
    await conn.query('create table people (id integer not null auto_increment, '
        'name varchar(255), '
        'age integer, '
        'primary key (id))');
    await conn.query('create table pets (id integer not null auto_increment, '
        'name varchar(255), '
        'species text, '
        'owner_id integer, '
        'primary key (id),'
        'foreign key (owner_id) references people (id))');
    print("executing queries");
  }

  Future addData() async {
    var query =
        await conn.queryMulti("insert into people (name, age) values (?, ?)", [
      ["Dave", 15],
      ["John", 16],
      ["Mavis", 93]
    ]);
    print("executed query 1");

    query = await conn.queryMulti(
        "insert into pets (name, species, owner_id) values (?, ?, ?)", [
      ["Rover", "Dog", 1],
      ["Daisy", "Cow", 2],
      ["Spot", "Dog", 2]
    ]);
    print("executed query 2");
  }

  Future readData() async {
    print("querying");
    var result =
        await conn.query('select p.id, p.name, p.age, t.name, t.species '
            'from people p '
            'left join pets t on t.owner_id = p.id');
    print("got results");
    return result.forEach((row) {
      if (row[3] == null) {
        print("ID: ${row[0]}, Name: ${row[1]}, Age: ${row[2]}, No Pets");
      } else {
        print(
            "ID: ${row[0]}, Name: ${row[1]}, Age: ${row[2]}, Pet Name: ${row[3]}, Pet Species ${row[4]}");
      }
    });
  }
}

main() async {
  OptionsFile options = new OptionsFile('connection.options');
  String user = options.getString('user');
  String password = options.getString('password');
  int port = options.getInt('port', 3306);
  String db = options.getString('db');
  String host = options.getString('host', 'localhost');

  ConnectionSettings settings = new ConnectionSettings(
      host: host, port: port, user: user, password: password, db: db);

  // create a connection
  print("opening connection");
  var conn = await MySqlConnection.connect(settings);
  print("connection open");
  // create an example class
  var example = new Example(conn);
  // run the example
  print("running example");
  await example.run();
  // finally, close the connection
  print("K THNX BYE!");
  await conn.close();
}
