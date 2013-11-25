Changelog
=========

v0.9.0
------
* Added ConnectionPool.getConnection() which returns a RetainedConnection. Useful
if you need to keep a specific connection around (for example, if you need to
lock tables).

v0.8.3
------
* Fixed connection retention error in Query.executeMulti

v0.8.1
------
* Can now access fields by name.

v0.8.0
------
* Breaking change: Results no longer has a 'stream' property - it now implements Stream itself.
As a result, it also no longer has a 'rows' property, or a 'toResultsList()' method - you
can use 'toList()' to convert it into a list instead.

v0.7.0
------
* Rewritten some connection handling code to make it more robust, and
so that it handles stream operations such as 'first' correctly (i.e.
without hanging forever).
* Updated spec for Dart 1.0

v0.6.2
------
* Support for latest SDK (removal of dart:utf8 library)

v0.6.1
------
* Support for latest SDK

v0.6.0
------
* Change prepared statement syntax. Values must now be passed into the execute() method
in an array. This change was made because otherwise prepared statements couldn't be used
asynchronously correctly - if you used the same prepared query object for multiple queries 
'at the same time', the wrong values could get used.

v0.5.8
------
* Handle errors in the utils package properly
* Pre-emptively fixed some errors, wrote more tests.

v0.5.7
------
* Fixed error with large fields.

v0.5.6
------
* Hopefully full unicode support
* Fixed problem with null values in prepared queries.

v0.5.5
------
* Some initial changes for better unicode handling.

v0.5.4
------
* Blobs and Texts which are bigger than 250 characters now work.

v0.5.3
------
* Make ConnectionPool and Transaction implement QueriableConnection
* Improved tests.

v0.5.2
------
* Fix for new SDK

v0.5.1
------
* Made an internal class private

v0.5.0
------
* Breaking change: Now uses streams to return results.

v0.4.1
------
* Major refactoring so that only the parts of sqljocky which are supposed to be exposed are.

v0.4.0
------
* Support for M4.

v0.3.0
------
* Support for M3.
* Bit fields are now numbers, not lists. 
* Dates now use the DateTime class instead of the Date class. 
* Use new IO classes.

v0.2.0
------
* Support for the new SDK.
 
v0.1.3
------
* SQLJocky now uses a connection pooling model, so the API has changed somewhat.
