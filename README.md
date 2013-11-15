SQLJocky
========

This is a MySQL connector for the Dart programming language. It isn't finished, but should
work for most normal use. The API is getting reasonably close to where I want it to
be now, so hopefully there shouldn't be too many breaking changes in the future.

News
----

The changelog has now been moved to CHANGELOG.md

Usage
-----

Create a connection pool:

	var pool = new ConnectionPool(host: 'localhost', port: 3306, user: 'bob', password: 'wibble', db: 'stuff', max: 5);

Execute a query:

	pool.query('select name, email from users').then((result) {...});

Use the results:

	results.listen((row) {
		print('Name: ${row[0]}, email: ${row[1]}');
	}
	
Or access the fields by name:

	results.listen((row) {
		print('Name: ${row.name}, email: ${row.email}');
	}

Prepare a query:

	pool.prepare('insert into users (name, email, age) values (?, ?, ?)').then((query) {...});

Execute the query:

	query.execute(['Bob', 'bob@bob.com', 25]).then((result) {...});

An insert query's results will be empty, but will have an id if there was an auto-increment column in the table:

	print("New user's id: ${result.insertId}");

Execute a query with multiple sets of parameters:

	query.executeMulti([['Bob', 'bob@bob.com', 25],
			['Bill', 'bill@bill.com', 26],
			['Joe', 'joe@joe.com', 37]]).then((results) {...}); 
			
Use the list of results:

	for (result in results) {
		print("New user's id: ${result.insertId}");
	}

Use a transaction:

	pool.startTransaction().then((trans) {
		trans.query('...').then((result) {
			trans.commit().then(() {...});
		});
	});

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
* SSL
* Larger than 16MB packets
* Handle character sets properly
* COM_SEND_LONG_DATA
* Better handling of various data types, especially BLOBs, which behave differently when using straight queries and prepared queries.
* Implement the rest of mysql's commands
* Improve performance where possible
* More unit testing
* More integration tests
* DartDoc
* More Example code
* Use idiomatic dart where possible
* Geometry type
* Decimal type should probably use a bigdecimal type of some sort
* MySQL 4 types (old decimal, anything else?)
* Test against multiple mysql versions

