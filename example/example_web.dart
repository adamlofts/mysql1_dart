import 'package:mysql1/mysql1.dart';

/// The same calls as `example.dart`, pointed at the bridge instead of a socket.
///
/// Run `dart run mysql1:mysql_bridge` where it can reach MySQL, with
/// `MYSQL_BRIDGE_TOKEN` set to the token below, then run this. `host` and
/// `port` are not where the database is: the bridge was given that when it
/// started. The browser cannot open port 3306 itself.
Future<void> main() async {
  final conn = await MySqlConnection.connect(
    ConnectionSettings(
      user: 'root',
      password: 'secret',
      db: 'testdb',
      bridgeUrl: 'ws://localhost:8080/mysql',
      bridgeToken: 'replace-with-a-long-secret',
    ),
  );

  final result = await conn.query(
    'insert into users (name, email, age) values (?, ?, ?)',
    ['Bob', 'bob@bob.com', 25],
  );
  print('Inserted row id=${result.insertId}');

  final results = await conn.query(
    'select name, email, age from users where id = ?',
    [result.insertId],
  );
  for (final row in results) {
    print('Name: ${row[0]}, email: ${row[1]} age: ${row[2]}');
  }

  await conn.close();
}
