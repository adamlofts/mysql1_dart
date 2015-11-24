library sqljocky.query_impl;

import 'dart:async';

import 'package:logging/logging.dart';

import 'connection.dart';
import 'connection_helpers.dart';
import 'connection_pool_impl.dart';
import 'query.dart';

import 'prepared_statements/execute_query_handler.dart';
import 'prepared_statements/prepare_handler.dart';
import 'prepared_statements/prepared_query.dart';

import 'results/results_impl.dart';
import 'results/results.dart';

class QueryImpl extends Object with ConnectionHelpers implements Query {
  final ConnectionPoolImpl _pool;
  final Connection _cnx;
  final String sql;
  final Logger _log;
  final _inTransaction;
  bool _executed = false;

  QueryImpl(this._pool, this.sql)
      : _cnx = null,
        _inTransaction = false,
        _log = new Logger("Query");

  QueryImpl.forTransaction(this._pool, Connection cnx, this.sql)
      : _cnx = cnx,
        _inTransaction = true,
        _log = new Logger("Query");

  Future<Connection> _getConnection() async {
    if (_cnx != null) {
      return _cnx;
    }
    return _pool.getConnectionInternal();
  }

  Future<PreparedQuery> prepare(bool retainConnection) async {
    _log.fine("Getting prepared query for: $sql");

    var cnx = await _getConnection();
    cnx.autoRelease = !retainConnection;
    _log.fine("Got cnx#${cnx.number}");
    var preparedQuery = _useCachedQuery(cnx);
    if (preparedQuery != null) {
      if (!retainConnection) {
        // didn't actually use the connection, so the auto-release
        // mechanism will never get fired, so we'd better give up
        // on the connection now
        cnx.release();
      }
      return preparedQuery;
    } else {
      return await _prepareAndCacheQuery(cnx, retainConnection);
    }
  }

  /**
   * Returns true if there was already a cached query which has been used.
   */
  PreparedQuery _useCachedQuery(Connection cnx) {
    var preparedQuery = cnx.getPreparedQueryFromCache(sql);
    if (preparedQuery == null) {
      return null;
    }

    _log.fine("Got prepared query from cache in cnx#${cnx.number} for: $sql");
    return preparedQuery;
  }

  _prepareAndCacheQuery(Connection cnx, retainConnection) async {
    _log.fine("Preparing new query in cnx#${cnx.number} for: $sql");
    var handler = new PrepareHandler(sql);
    cnx.use();
    cnx.autoRelease = !retainConnection;
    var preparedQuery = await cnx.processHandler(handler);
    try {
      _log.fine("Prepared new query in cnx#${cnx.number} for: $sql");
      preparedQuery.cnx = cnx;
      cnx.putPreparedQueryInCache(sql, preparedQuery);
      return preparedQuery;
    } catch (e) {
      releaseReuseThrow(cnx, e);
    }
  }

  /// Closes this query and removes it from all connections in the pool.
  close() async {
    _pool.closeQuery(this, _inTransaction);
  }

  /**
   * Executes the query, returning a future [Results] object.
   */
  Future<Results> execute([List values]) async {
    _log.fine("Prepare...");
    var preparedQuery = await prepare(true);
    _log.fine("Prepared, now to execute");
    Results results =
        await _execute(preparedQuery, values == null ? [] : values);
    _log.fine(
        "Got prepared query results on #${preparedQuery.cnx.number} for: ${sql}");
    return results;
  }

  Future<Results> _execute(PreparedQuery preparedQuery, List values,
      {bool retainConnection: false}) async {
    _log.finest("About to execute");
    var handler = new ExecuteQueryHandler(preparedQuery, _executed, values);
    preparedQuery.cnx.autoRelease = !retainConnection;
    try {
      Results results = await preparedQuery.cnx.processHandler(handler);
      _log.finest("Prepared query got results");
      return results;
    } catch (e) {
      releaseReuseThrow(preparedQuery.cnx, e);
    }
  }

  /**
   * Executes the query once for each set of [parameters], and returns a future list
   * of results, one for each set of parameters, that completes when the query has been executed.
   *
   * Because this method has to wait for all the results to return from the server before it
   * can move onto the next query, it ends up keeping all the results in memory, rather than
   * streaming them, which can be less efficient.
   */
  Future<List<Results>> executeMulti(List<List> parameters) async {
    var preparedQuery = await prepare(true);
    _log.fine(
        "Prepared query for multi execution. Number of values: ${parameters.length}");
    var resultList = new List<Results>();

    for (int i = 0; i < parameters.length; i++) {
      try {
        _log.fine("Executing query, loop $i");
        Results results = await _execute(preparedQuery, parameters[i],
            retainConnection: true);
        _log.fine("Got results, loop $i");
        Results deStreamedResults = await ResultsImpl.destream(results);
        resultList.add(deStreamedResults);
      } catch (e) {
        releaseReuseThrow(preparedQuery.cnx, e);
      }
    }
    preparedQuery.cnx.release();
    return resultList;
  }

  removeConnection(Connection cnx) {
    if (!_inTransaction) {
      _pool.removeConnection(cnx);
    }
  }
//  dynamic longData(int index, data);
//  dynamic reset();
//  dynamic fetch(int rows);
}
