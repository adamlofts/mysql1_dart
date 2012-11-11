part of utils;

class TableDropper {
  Connection cnx;
  List<String> tableList;
  List<String> _tables = [];
  
  TableDropper(this.cnx, this.tableList);
  
  void _dropTables(Completer c) {
    String table = _tables[0];
    _tables.removeRange(0, 1);
    Future future = cnx.query('drop table $table');
    future.handleException((exception) {
      if (exception is MySqlError && (exception as MySqlError).errorNumber == 1051) {
        if (_tables.length == 0) {
          c.complete(null);
        } else {
          _dropTables(c);
        }
      }
      return true;
    });
    future.then((x) {
      if (_tables.length == 0) {
        c.complete(null);
      } else {
        _dropTables(c);
      }
    });
  }

  Future dropTables() {
    var dropCompleter = new Completer();
    _tables.clear();
    _tables.addAll(tableList);
    _dropTables(dropCompleter);
    return dropCompleter.future;
  }
}

class TableCreator {
  Connection cnx;
  List<String> createQueries;
  List<String> _queries = [];
  
  TableCreator(this.cnx, this.createQueries);
  
  Future _createTables(Completer c) {
    String query = _queries[0];
    _queries.removeRange(0, 1);
    cnx.query(query).then((x) {
      if (_queries.length == 0) {
        c.complete(null);
      } else {
        _createTables(c);
      }
    });
  }

  Future createTables() {
    Completer completer = new Completer();
    _queries.clear();
    _queries.addAll(createQueries);
    _createTables(completer);
    return completer.future;
  }
}
