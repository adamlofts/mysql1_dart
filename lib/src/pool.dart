part of sqljocky;

class ConnectionPool {
  String _host;
  int _port;
  String _user;
  String _password;
  String _db;
  
  int _max;
  
  List<Connection> _pool;
  
  Pool({String host: 'localhost', int port: 3306, String user, String password, String db, int max: 5}) {
    _host = host;
    _port = port;
    _user = user;
    _password = password;
    _db = db;
    _pool = new List<Connection>();
    _max = max;
  }
  
  Future<Connection> connect() {
    var completer = new Completer();
    
    for (var cnx in _pool) {
      if (!cnx._inUse) {
        print("Reusing existing pooled connection");
        completer.complete(cnx);
        return;
      }
    }
    
    if (_pool.length < _max) {
      print("Creating new pooled connection");
      Connection cnx = new Connection._forPool(this);
      cnx.onClosed = _getConnectionClosedHandler(cnx);
      var future = cnx.connect(
          host: _host, 
          port: _port, 
          user: _user, 
          password: _password, 
          db: _db);
      _pool.add(cnx);
      future.then((x) {
        completer.complete(cnx);
      });
      future.handleException((e) {
        completer.completeException(e);
      });
    } else {
      completer.completeException(new NoConnectionAvailable("Connection pool full"));
    }
    return completer.future;
  }
  
  _getConnectionClosedHandler(Connection cnx) {
    return () {
      if (!_pool.contains(cnx)) {
        print("_connectionClosed handler called for unmanaged connection");
        return;
      }
      
      print("Marking pooled connection as not in use");
      cnx._inUse = false;
    };
  }
}

class NoConnectionAvailable implements Exception {
  final String message;
  
  NoConnectionAvailable(this.message);
}