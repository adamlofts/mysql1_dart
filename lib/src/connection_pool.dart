library sqljocky.connection_pool;

import 'dart:async';

import 'queriable_connection.dart';
import 'query.dart';
import 'results/results.dart';
import 'retained_connection.dart';
import 'connection_pool_impl.dart';
import 'transaction.dart';

/**
 * Maintains a pool of database connections. When queries are executed, if there is
 * a free connection it will be used, otherwise the query is queued until a connection is
 * free.
 */
abstract class ConnectionPool implements QueriableConnection {
  /**
   * Creates a [ConnectionPool]. When connections are required they will connect to the
   * [db] on the given [host] and [port], using the [user] and [password]. The [max] number
   * of simultaneous connections can also be specified, as well as the [maxPacketSize].
   *
   * Note that no connections are created at this point, so any connection errors
   * will happen when the pool is used. If you need to find out if the connection
   * details are correct you might want to run a dummy query such as 'SELECT 1'.
   */
  factory ConnectionPool(
      {String host,
      int port,
      String user,
      String password,
      String db,
      int max,
      int maxPacketSize,
      bool useSSL}) = ConnectionPoolImpl;

  /**
   * Gets a persistent connection to the database.
   *
   * When you execute a query on the connection pool, it waits until a free
   * connection is available, executes the query and then returns the connection
   * back to the connection pool. Sometimes there may be cases where you want
   * to keep the same connection around for subsequent queries (such as when
   * you lock tables). Use this method to get a connection which isn't released
   * after each query.
   *
   * You must use [RetainedConnection.release] when you have finished with the
   * connection, otherwise it will not be available in the pool again.
   */
  Future<RetainedConnection> getConnection();

  /**
   * Sends a debug message to the server. Returns a [Future] that completes
   * when the server replies.
   */
  Future debug();

  /**
   * Pings the server. Returns a [Future] that completes when the server replies.
   */
  Future ping();

  Future<Results> prepareExecute(String sql, List parameters);

  /**
   * Closes all open connections immediately. It doesn't wait for operations to complete.
   *
   * WARNING: this will probably break things.
   */
  void closeConnectionsNow();

  /**
   * Closes all connections as soon as they are no longer in use.
   *
   * Retained connections will only be closed once they have been released.
   * Connection which are in use by a transaction will only be closed
   * once the transaction has completed.
   *
   * Any operations which are initiated after calling this method will be
   * executed on new connections, even if the current operations haven't
   * yet finished when the operation is queued.
   */
  void closeConnectionsWhenNotInUse();

  Future<Results> query(String sql);

  Future<Query> prepare(String sql);

  /**
   * Starts a transaction. Returns a [Future]<[Transaction]> that completes
   * when the transaction has been started. If [consistent] is true, the
   * transaction is started with consistent snapshot. A transaction holds
   * onto its connection until closed (committed or rolled back). You
   * must use this method rather than `query('start transaction')` otherwise
   * subsequent queries may get executed on other connections which are not
   * in the transaction. Likewise, you must use the [Transaction.commit]
   * and [Transaction.rollback] methods to commit and roll back, otherwise
   * the connection will not be released.
   */
  Future<Transaction> startTransaction({bool consistent: false});
}
