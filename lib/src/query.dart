library sqljocky.query;

import 'dart:async';

import 'results/results.dart';

/**
 * Query is created by `ConnectionPool.prepare(sql)` and `Transaction.prepare(sql)`. It holds
 * a prepared query.
 *
 * In MySQL, a query must be prepared on a specific connection. If you execute this
 * query and a connection is used from the pool which doesn't yet have the prepared query
 * in its cache, it will first prepare the query on that connection before executing it.
 */
abstract class Query {
  Query._();

  String get sql;

  /// Closes this query and removes it from all connections in the pool.
  Future close();

  /**
   * Executes the query, returning a future [Results] object.
   */
  Future<Results> execute([List values]);

  /**
   * Executes the query once for each set of [parameters], and returns a future list
   * of results, one for each set of parameters, that completes when the query has been executed.
   *
   * Because this method has to wait for all the results to return from the server before it
   * can move onto the next query, it ends up keeping all the results in memory, rather than
   * streaming them, which can be less efficient.
   */
  Future<List<Results>> executeMulti(List<List> parameters);
}
