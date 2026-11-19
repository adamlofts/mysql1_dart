mysql1
======

A MySQL driver for the Dart programming language. Works on Flutter and on the server.

This library aims to provide an easy to use interface to MySQL. `mysql1` originated 
as a fork of the SQLJocky driver.

Principles
----------

- Keep behavior and defaults close to the major MySQL drivers: MySQLdb
  (`mysqlclient`), the C client (`libmysqlclient`), Connector/J and
  `go-sql-driver/mysql`.
- Keep the API similar to `package:postgres`.
- Good defaults.

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

Flutter Web
-----------

A page cannot open a TCP socket, so it cannot connect to MySQL's port on its
own. No change in this package removes that: browsers withhold raw sockets on
purpose, and a web app which could open port 3306 could also open every other
port of every machine the user can reach. The protocol code is the same. On
the web those bytes are carried over a WebSocket to a bridge, and the bridge
is what opens the database connection.

The bridge connects only to the host it was started with. The page does not
get to choose the address.

```
MYSQL_BRIDGE_TOKEN   required, at least 16 characters
MYSQL_HOST           default 127.0.0.1
MYSQL_PORT           default 3306
MYSQL_BRIDGE_BIND    default 127.0.0.1
MYSQL_BRIDGE_PORT    default 8080
MYSQL_BRIDGE_ORIGIN  if set, the only Origin which is upgraded
```

```
dart run mysql1:mysql_bridge
```

From Flutter web:

```dart
var conn = await MySqlConnection.connect(ConnectionSettings(
  user: 'bob',
  password: 'wibble',
  db: 'mydb',
  bridgeUrl: 'ws://localhost:8080/mysql',
  bridgeToken: 'a long random secret',
));
```

`useSSL` stays off on that connection. The browser cannot perform MySQL's TLS
upgrade. Use `wss://` when the bridge is not on the same machine as the
browser. A page served with HTTPS cannot open a `ws://` URL. An account using
`caching_sha2_password` which has not logged in from the bridge's address
before needs `serverPublicKey`, because the password would otherwise have to
travel inside MySQL's TLS upgrade.

`user`, `password` and `bridgeToken` are part of the built web app. Anyone
who can load the app can read them and use the bridge. Give that database
user only what the app needs, and leave the bridge on loopback unless the
people who can open it are the people who should be able to log in.

On a server, on Flutter mobile and on the desktop, `connect` still opens a
socket to `host` and `port`. `bridgeUrl` is not required there. Setting it
uses the bridge from those targets too.
