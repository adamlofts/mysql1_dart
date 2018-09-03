mysql1
======

MySQL driver for the Dart programming language. It will only work in the command-line VM, not in a browser.

This is a fork of the original SQLJocky driver and SQLJocky5 with a different API.

Usage
-----

Connect to the database

```dart
ConnectionSettings settings = new ConnectionSettings(
  host: 'localhost', port: 3306, user: 'bob', password: 'wibble', db: 'mydb');
var conn = await MySqlConnection.connect(settings);
```

Execute a query with parameters:

```dart
var userId = 1;
var results = await conn.query('select name, email from users where id = ?', [userId]);
```

Use the results:

```dart
for (var row in results) {
  print('Name: ${row[0]}, email: ${row[1]}');
});
```

Insert some data

```dart
var query = await pool.prepare(
  'insert into users (name, email, age) values (?, ?, ?)');
var result = await query.query(query, ['Bob', 'bob@bob.com', 25]);
```

An insert query's results will be empty, but will have an id if there was an auto-increment column in the table:

```dart
print("New user's id: ${result.insertId}");
```

Execute a query with multiple sets of parameters:

```dart
var results = await query.executeMulti(
    'insert into users (name, email, age) values (?, ?, ?)',
    [['Bob', 'bob@bob.com', 25],
    ['Bill', 'bill@bill.com', 26],
    ['Joe', 'joe@joe.com', 37]]);
```

Licence
-------

It is released under the GPL, because it uses a modified part of mysql's include/mysql_com.h in constants.dart,
which is licensed under the GPL. I would prefer to release it under the BSD Licence, but there you go.

Things to do
------------

* Compression
* COM_SEND_LONG_DATA
* CLIENT_MULTI_STATEMENTS and CLIENT_MULTI_RESULTS for stored procedures
* More connection pool management (close after timeout, change pool size...)
* Better handling of various data types, especially BLOBs, which behave differently when using straight queries and prepared queries.
* Implement the rest of mysql's commands
* Handle character sets properly? Currently defaults to UTF8 for the connection character set. Is it
necessary to support anything else?
* Improve performance where possible
* Geometry type
* Decimal type should probably use a bigdecimal type of some sort
* MySQL 4 types (old decimal, anything else?)
* Test against multiple mysql versions
