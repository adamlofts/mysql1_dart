Changelog
=========

v0.20.0

30 June 2022
* Add return to transaction
* null safety fixes

v0.19.2

06 May 2021
* Add mysql8 to test matrix & support caching_sha2_password auth

v0.19.1
--

05 May 2021
* Correct parsing of DateTime in non-utc client timezone

v0.19.0
--

02 Apr 2021
* Breaking: migrate to Dart 2.12.0 with null safety enabled

v0.18.1
--

31 Mar 2021
* Supporting Unix socket connections.

v0.18.0
--

* Breaking: Rename `Row` to `ResultRow` so name doesn't conflict with `Row` from Flutter. (#10)

v0.17.1
--

19 Dec 2019

* Fix analysis errors

v0.17.0+1
--

23 Apr 2019

* Make result field values accessible by name on BinaryDataPackets
* Require `List` type in public query API

v0.17.0
--

23 Apr 2019

* Make result field values accessible by name on BinaryDataPackets
* Require `List` type in public query API

v0.16.3
--

28 Nov 2018

* Improve docs
* Breaking: Test for correct query parameter count on the client side
* Breaking: Tidy up old field by name access code
* Tidy up `Field` class


v0.16.2
--

23 Oct 2018

* Make `Field` a concrete class
* Breaking: Don't export `mysql.constants`. These are internal.

v0.16.1
--

23 Oct 2018

* Simplify example

v0.16.0
--

* Breaking: Validate that all `DateTime` values passed to and returned from `query` and `queryMulti` are UTC.

v0.15.2
--

* Add types to `query` and `queryMulti` interface. This makes the package easier to use with `implicit-dynamic: false`

v0.15.1
--

* Documentation updates

v0.15.0
-------

* Publish first version post-fork

SQLJockey historical changelog
--

v0.14.5
-------
* Fix package references

v0.14.3
-------
* Merged in Kevin Moore's PR from original SQLJockey

v0.14.1
-------
* Fix the changelog formatting, so you can actually see what changed in v0.14.0

v0.14.0
-------
* Requires Dart 1.11
* Use newer logging library
* Use async/await in library code and examples.
* Fix bug with closing prepared queries, where it sometimes tried to close a query which was in use.
* Don't throw an error if username is null.
* Fix bug in blobs, where it was trying to decode binary blobs as UTF-8 strings.
* Close connections and return them to the pool when a connection times out on the server.

v0.13.0
-------
* Fixes an issue with executeMulti being broken.
* Fixes an issue with query failing if the first field in a SELECT is an empty string

v0.12.0
-------
* Breaking change: ConnectionPool.close() has been renamed to ConnectionPool.closeConnectionsNow.
  It is a dangerous method to call as it closes all connections even if they are in the middle
  of an operation. ConnectionPool.closeConnectionsWhenNotInUse has been added, which is much
  safer.
* Fixed an issue with closing prepared queries which caused connections to remain open.

v0.11.0
-------
* Added support for packets larger than 16 MB. ConnectionPool's constructor has a new parameter,
  'maxPacketSize', which specifies the maximum packet size in bytes. Using packets larger than
  16 MB is not currently particularly optimised.
* Fixed some issues with authentication. In particular, errors should now be thrown when you
  try to connect to a server which is using an old or unsupported authentication protocol.

v0.10.0
-------
* Added SSL connections. Pass 'useSSL: true' to ConnectionPool constructor. If server doesn't support
  SSL, connection will continue unsecured. You can check if the connections are secure by calling
  pool.getConnection().then((cnx) {print(cnx.usingSSL); cnx.release();});

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
