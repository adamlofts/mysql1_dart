library sqljocky.transaction;

import 'dart:async';

import 'queriable_connection.dart';

/**
 * Start a transaction by using [ConnectionPool.startTransaction]. Once a transaction
 * is started it retains its connection until the transaction is committed or rolled
 * back. You must use the [commit] and [rollback] methods to do this, otherwise
 * the connection will not be released back to the pool.
 */
abstract class Transaction extends QueriableConnection {
  /**
   * Commits the transaction and released the connection. An error will be thrown
   * if any queries are executed after calling commit.
   */
  Future commit();

  /**
   * Rolls back the transaction and released the connection. An error will be thrown
   * if any queries are executed after calling rollback.
   */
  Future rollback();
}
