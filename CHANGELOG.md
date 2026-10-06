Changelog
=========

v0.21.1
--

05 Oct 2026
* An account with a password on MySQL 8 can log in over a connection which
  is not TLS or a unix socket. A `caching_sha2_password` account has to send
  the server its password the first time it logs in, and the driver now
  encrypts it with the server's RSA public key, which it asks the server for.
  It used to refuse.
* `ConnectionSettings.serverPublicKey` takes that key in PEM, for anyone who
  would rather give it than have the server asked.

v0.21.0
--

05 Oct 2026

The connection has been rewritten, and most of this release is what that
fixed. Several changes are breaking.

Breaking:
* Requires Dart 3.0.
* The MySQL optimizer does not work well on prepared statements.
  Therefore, query parameters are now written into the statement as literals
  and sent as plain SQL, and prepared statements are no longer used. The
  connection character set must be utf8 or utf8mb4, and the server must not
  be in `NO_BACKSLASH_ESCAPES` mode.
* A query which times out closes the connection. Its response was otherwise
  liable to be taken for the answer to the next query.
* `useSSL` implemented.
* `ConnectionSettings.useCompression` is removed. It never worked.
* A `DateTime` parameter is sent with its fractional seconds, which the server
  rounds to the precision of the column. It used to be cut to whole seconds.
* Almost all `FINE` logging is gone.
* `affectedRows` is never null. For a statement which returns rows it is the
  number of rows, where it used to be null.
* `ResultRow`'s constructor takes the result's schema, which breaks a subclass
  of it outside this package.

Added:
* The result API is closer to `package:postgres`, so code which reads rows
  looks the same against either driver. `Results` is now `Result`, a list of
  rows, and `Field` is now `ResultSchemaColumn`; the old names still work and
  are deprecated. `Result` and `ResultRow` have a `schema`, and `ResultRow`
  has `toColumnMap()` and `isSqlNull()`.

Fixed:
* Logging in to MySQL 8 with a password. `caching_sha2_password` accounts
  left the connection one packet out of step, which showed up as the first
  query returning nothing, each query returning the previous query's rows,
  `RangeError ... Not in inclusive range 0..5`, "Got packets out of order" or
  "Socket has been closed". An account whose plugin is not the server's
  default now logs in too.
* A `caching_sha2_password` account the server has not cached can log in over
  TLS or a unix socket. Over plain TCP it is refused with a message saying so.
* `CALL`: every query after a stored procedure call returned the results of
  the one before it.
* `DATETIME(n)` and `TIMESTAMP(n)` parameters lost their fraction. Reading a
  `TIME(n)` column hung, and a negative `TIME` was read wrongly.
* A value of 16MB or more returned no rows, and a row which exactly filled a
  packet sent the driver into a loop ("Illegal length 0").
* A value which cannot be decoded, such as a `POINT`, fails the query at once.
  It used to hang until the timeout and close the connection.
* An error from the server part way through a result is reported instead of
  being dropped.

Performance:
* Reading a large result is about ten times faster.

v0.20.0
--

30 June 2022
* Add return to transaction
* null safety fixes

v0.19.2
--

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

Earlier releases, as SQLJocky, are listed in the changelog of
https://github.com/jamesots/sqljocky.
