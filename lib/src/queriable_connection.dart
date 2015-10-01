library sqljocky.queriable_connection;

import 'dart:async';

import 'query.dart';
import 'results/results.dart';

abstract class QueriableConnection {
  /**
   * Executes the [sql] query, returning a [Future]<[Results]> that completes
   * when the results start to become available.
   */
  Future<Results> query(String sql);

  /**
   * Prepares a query with the given [sql]. Returns a [Future<Query>] that
   * completes when the query has been prepared.
   */
  Future<Query> prepare(String sql);

  /**
   * Prepares and executes the [sql] with the given list of [parameters].
   * Returns a [Future]<[Results]> that completes when the query has been
   * executed.
   */
  Future<Results> prepareExecute(String sql, List<dynamic> parameters);
}
