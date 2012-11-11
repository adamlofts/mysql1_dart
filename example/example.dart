import 'package:sqljocky/sqljocky.dart';
import 'package:sqljocky/utils.dart';
import 'package:options_file/options_file.dart';

class Example {
  Connection cnx;
  
  Example(this.cnx);
  
  Future run() {
    var completer = new Completer();
    // drop the tables if they already exist
    dropTables().chain((x) {
      // then recreate the tables
      return createTables();
    }).chain((x) {
      // add some data
      return addData();
    }).chain((x) {
      // and read it back out
      return readData();
    }).then((x) {
      completer.complete(null);
    });
    return completer.future;
  }

  Future dropTables() {
    var dropper = new TableDropper(cnx, ['people']);
    return dropper.dropTables();
  }
  
  Future createTables() {
    var querier = new QueryRunner(cnx, ["create table people (id integer not null auto_increment, "
                                        'name varchar(255), age integer, '
                                        'primary key (id))']);
    return querier.executeQueries();
  }
  
  Future addData() {
    var completer = new Completer();
    cnx.prepare("insert into people (name, age) values (?, ?)").chain((query) {
      var parameters = [
          ["Dave", 15],
          ["John", 16],
          ["Mavis", 93]
        ];
      return query.executeMulti(parameters);
    }).then((results) {
      completer.complete(null);
    });
    return completer.future;
  }
  
  Future readData() {
    var completer = new Completer();
    cnx.query("select id, name, age from people").then((result) {
      for (var row in result) {
        print("ID: ${row[0]}, Name: ${row[1]}, Age: ${row[2]}");
      }
      completer.complete(null);
    });
    return completer.future;
  }
}

void main() {
  OptionsFile options = new OptionsFile('connection.options');
  String user = options.getString('user');
  String password = options.getString('password');
  int port = options.getInt('port', 3306);
  String db = options.getString('db');
  String host = options.getString('host', 'localhost');

  // create a connection
  var cnx = new Connection();
  cnx.connect(host: host, port: port, user: user, password: password, db: db).then((x) {
    // create an example class
    var example = new Example(cnx);
    // run the example
    example.run().then((x) {
      // finally, close the connection
      cnx.close();
    });
  });
}