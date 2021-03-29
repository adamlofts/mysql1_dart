import 'dart:async';

import 'package:mysql1/mysql1.dart';

Future main() async {
  // Open a connection (testdb should already exist)
  final conn = await MySqlConnection.connect(
    ConnectionSettings(
      host: '/Applications/MAMP/tmp/mysql/mysql.sock',
      user: 'root',
      password: 'root',
      db: 'testdb',
    ),
    isUnixSocket: true,
  );

  // Create a table
  await conn.query(
    'CREATE TABLE IF NOT EXISTS trucs (id int NOT NULL AUTO_INCREMENT PRIMARY KEY, name varchar(255), email varchar(255), age int)',
  );

  // Insert some data
  var result = await conn.query(
    'insert into trucs (name, email, age) values (?, ?, ?)',
    ['Bob', 'bob@bob.com', 25],
  );
  print('Inserted row id=${result.insertId}');

  // Query the database using a parameterized query
  var results = await conn.query(
    'select name, email, age from trucs where id = ?',
    [result.insertId!],
  );
  for (var row in results) {
    print('Name: ${row[0]}, email: ${row[1]} age: ${row[2]}');
  }

  // Update some data
  await conn.query('update trucs set age=? where name=?', [26, 'Bob']);

  // Query again database using a parameterized query
  var results2 = await conn.query(
    'select name, email, age from trucs where id = ?',
    [result.insertId!],
  );
  for (var row in results2) {
    print('Name: ${row[0]}, email: ${row[1]} age: ${row[2]}');
  }

  // Finally, close the connection
  await conn.close();
}
