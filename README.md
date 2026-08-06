mysql1
======

A MySQL driver for the Dart programming language. Works on Flutter and on the server.

This library aims to provide an easy to use interface to MySQL. `mysql1` originated 
as a fork of the SQLJocky driver.

Usage
-----

Connect to the database

```dart
var settings = new ConnectionSettings(
  host: 'localhost', 
  port: 3306,
  user: 'bob',
  password: 'wibble',
  db: 'mydb'
);
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
var result = await conn.query('insert into users (name, email, age) values (?, ?, ?)', ['Bob', 'bob@bob.com', 25]);
```

An insert query's results will be empty, but will have an id if there was an auto-increment column in the table:

```dart
print("New user's id: ${result.insertId}");
```

Execute a query with multiple sets of parameters:

```dart
var results = await query.queryMulti(
    'insert into users (name, email, age) values (?, ?, ?)',
    [['Bob', 'bob@bob.com', 25],
    ['Bill', 'bill@bill.com', 26],
    ['Joe', 'joe@joe.com', 37]]);
```

Update some data:

```dart
await conn.query(
    'update users set age=? where name=?',
    [26, 'Bob']);
```

Parameters
----------

Parameters are bound client side. The values are escaped, written into the
statement as literals, and the result is sent as a single query - there is no
server side prepare/execute/close. This is what `mysqlclient` does, and so how
most MySQL deployments already send their statements.

The reason to do it this way is query planning. A bound value is opaque to the
optimizer, so if the leading column of an index is a parameter it takes ref
access on that column and never builds a range, and a keyset page can degrade
into a scan.

`?` placeholders inside string literals and inside `` ` `` quoted identifiers
are left alone. `null`, `int`, `double`, `bool`, `String` and `DateTime` (UTC
only, second precision) can be bound, as can `Blob` and `List<int>` - both are
written as hex literals, so bytes which are not valid in the connection charset
survive. Anything else is bound as its `toString()`.

Escaping assumes the connection charset is utf8 or utf8mb4, and that the server
is not in `NO_BACKSLASH_ESCAPES` mode. Both hold for a connection opened by this
driver with default settings.

Flutter Web
-----------

This package opens a socket to the database. The web platform does not support sockets and so this package does not work on flutter web.
