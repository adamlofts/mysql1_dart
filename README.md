SQLJocky
========

This is a MySQL connector for the Dart programming language. It is in early stages of development,
so please report issues, contribute code and suggest how I could make this better. (I won't 
guarantee I'll agree with you).

Usage
-----

SqlJocky uses an asynchronous model to access the database, due to Dart's (probably sensible) lack 
of blocking reads on sockets. The API for the library can be found in lib/interfaces.dart. Examples
and suchlike may come in the future.

Licence
-------

It is released under the GPL, because it uses a modified part of mysql's include/mysql_com.h, 
which is licensed under the GPL. I would prefer to release it under the BSD Licence, but there you go.

The Name
--------

It is named after [Jocky Wilson](http://en.wikipedia.org/wiki/Jocky_Wilson), the late, great 
darts player. (Hence the lack of an 'e' in Jocky.)

Things to do
------------

* Make floating point stuff work correctly. (I'm almost 100% certain my implementation is incorrect).
* Parse string responses to non-parameterized queries
* Implement the rest of mysql's commands
* Unit testing (I would have developed using TDD, but I wasn't sure what unit testing framework to use)
* More integration tests
* DartDoc
* Example code
* Refactor everything a few times, when I think of a nicer way of doing things, or the Dart language changes
* Use idiomatic dart where possible
* Use a real logger
* Geometry type
* MySQL 4 types (old decimal, anything else?)
* Test against multiple mysql versions
* A logo.