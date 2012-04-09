SQLJocky
========

This is a MySQL driver for the Dart programming language.

It is released under the GPL, because it uses a modified part of mysql's include/mysql_com.h, which is licenced under the GPL. I would
prefer to release it under the BSD Licence, but there you go.


The SQLJocky Name
-----------------

It is named after [Jocky Wilson](http://en.wikipedia.org/wiki/Jocky_Wilson), the late, great darts player. (Hence the lack of an 'e' in Jocky.)

Synchronous Transport
---------------------

This driver includes a synchronous option, which only uses a Future for the initial connection. However, I'm not sure it's a good idea,
and I'm mostly concentrating on the asynchronous transport implementation, so it's probably best avoided at the moment.

Things to do
------------

* A logo.
* Implement the rest of mysql's commands
* Unit testing (I would have developed using TDD, but I wasn't sure what unit testing framework to use)
* DartDoc
* Decide whether this should be a mysql only driver, or a general db driver framework
* Refactor everything a few times, when I think of a nicer way of doing things, or the Dart language changes
* User some kind of logger

