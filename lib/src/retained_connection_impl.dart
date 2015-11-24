library sqljocky.retained_connection_impl;

import 'dart:async';

import 'connection.dart';
import 'connection_helpers.dart';
import 'connection_pool_impl.dart';
import 'query.dart';
import 'query_impl.dart';
import 'queriable_connection.dart';
import 'retained_connection.dart';
import 'transaction.dart';

import 'query/query_stream_handler.dart';

import 'results/results.dart';

class TransactionImpl extends _RetainedConnectionBase implements Transaction {
  TransactionImpl(cnx, pool) : super(cnx, pool);

  Future commit() async {
    _checkReleased();
    _released = true;

    var handler = new QueryStreamHandler("commit");
    var results = await _cnx.processHandler(handler);
    _cnx.inTransaction = false;
    _cnx.release();
    _pool.reuseConnectionForQueuedOperations(_cnx);
    return results;
  }

  Future rollback() async {
    _checkReleased();
    _released = true;

    var handler = new QueryStreamHandler("rollback");
    var results = await _cnx.processHandler(handler);
    _cnx.inTransaction = false;
    _cnx.release();
    _pool.reuseConnectionForQueuedOperations(_cnx);
    return results;
  }

  void _checkReleased() {
    if (_released) {
      throw new StateError("Transaction has already finished");
    }
  }
}

class _TransactionPool extends ConnectionPoolImpl {
  final Connection cnx;

  _TransactionPool(this.cnx);

  Future<Connection> getConnectionInternal() => new Future.value(cnx);

  removeConnection(Connection cnx) {}
}

abstract class _RetainedConnectionBase extends Object
    with ConnectionHelpers
    implements QueriableConnection {
  Connection _cnx;
  ConnectionPoolImpl _pool;
  bool _released;

  _RetainedConnectionBase(this._cnx, this._pool) : _released = false;

  Future<Results> query(String sql) {
    _checkReleased();
    var handler = new QueryStreamHandler(sql);
    return _cnx.processHandler(handler);
  }

  Future<Query> prepare(String sql) async {
    _checkReleased();
    var query =
        new QueryImpl.forTransaction(new _TransactionPool(_cnx), _cnx, sql);
    await query.prepare(true);
    return new Future.value(query);
  }

  Future<Results> prepareExecute(String sql, List parameters) async {
    _checkReleased();
    var query = await prepare(sql);
    var results = await query.execute(parameters);
    //TODO is it right to close here? Query might still be running
    query.close();
    return new Future.value(results);
  }

  void _checkReleased();

  removeConnection(Connection cnx) {
    _pool.removeConnection(cnx);
  }

  bool get usingSSL => _cnx.usingSSL;
}

class RetainedConnectionImpl extends _RetainedConnectionBase
    implements RetainedConnection {
  RetainedConnectionImpl(cnx, pool) : super(cnx, pool);

  Future release() {
    _checkReleased();
    _released = true;

    _cnx.inTransaction = false;
    _cnx.release();
    _pool.reuseConnectionForQueuedOperations(_cnx);
    return new Future.value();
  }

  void _checkReleased() {
    if (_released) {
      throw new StateError("Connection has already been released");
    }
  }
}
