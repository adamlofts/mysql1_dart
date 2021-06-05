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

The results returned from the query can be accessed both as a list and as a Map. 

Use the results as an index:

```dart
for (var row in results) {
  print('Name: ${row[0]}, email: ${row[1]}');
});
```

Use the results as a Map:

```dart
for (var row in results) {
  print('Name: ${row['Name']}, email: ${row['email']})
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

After making an update or addition, get number of affected rows:

```dart
print('${result.affectedRows}')
```
