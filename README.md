SQLJocky
========

This is a MySQL connector for the Dart programming language. It isn't finished, but should
work for most normal use. The API is getting reasonably close to where I want it to
be now, so hopefully there shouldn't be too many breaking changes in the future.

It will only work in the command-line VM, not in a browser.

News
----

The changelog has now been moved to CHANGELOG.md

Usage
-----

Create a connection pool:

```dart
var pool = new ConnectionPool(
    host: 'localhost', port: 3306,
    user: 'bob', password: 'wibble',
    db: 'stuff', max: 5);
```

Execute a query:

```dart
var results = await pool.query('select name, email from users');
```

Use the results: (*Note: forEach is asynchronous.*)

```dart
results.forEach((row) {
  print('Name: ${row[0]}, email: ${row[1]}');
});
```

Or access the fields by name:

```dart
results.forEach((row) {
  print('Name: ${row.name}, email: ${row.email}');
});
```

Prepare a query:

```dart
var query = await pool.prepare(
  'insert into users (name, email, age) values (?, ?, ?)');
```

Execute the query:

```dart
var result = await query.execute(['Bob', 'bob@bob.com', 25]);
```

An insert query's results will be empty, but will have an id if there was an auto-increment column in the table:

```dart
print("New user's id: ${result.insertId}");
```

Execute a query with multiple sets of parameters:

```dart
var results = await query.executeMulti([['Bob', 'bob@bob.com', 25],
    ['Bill', 'bill@bill.com', 26],
    ['Joe', 'joe@joe.com', 37]]);
```

Use the list of results:

```dart
for (result in results) {
  print("New user's id: ${result.insertId}");
}
```

Use a transaction:

```dart
var trans = await pool.startTransaction();
var result = await trans.query('...');
await trans.commit();
```

Development
-----------

To run the examples and tests, you'll need to create a 'connection.options' file by
copying 'connection.options.example' and modifying the settings.

Licence
-------

It is released under the GPL, because it uses a modified part of mysql's include/mysql_com.h in constants.dart,
which is licensed under the GPL. I would prefer to release it under the BSD Licence, but there you go.

The Name
--------

It is named after [Jocky Wilson](http://en.wikipedia.org/wiki/Jocky_Wilson), the late, great
darts player. (Hence the lack of an 'e' in Jocky.)

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
