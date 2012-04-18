#import('lib/sqljocky.dart');
#import('lib/crypto/hash.dart');
#import('lib/crypto/sha1.dart');
#import('options.dart');

void main() {
  Log log = new Log("main");
  
  OptionsFile options = new OptionsFile('connection.options');
  String user = options.getString('user');
  String password = options.getString('password');
  int port = options.getInt('port', 3306);
  String db = options.getString('db');
  String host = options.getString('host', 'localhost');
  
  {
    SyncConnection cnx = new SyncMySqlConnection();
    cnx.connect(user:user, password:password, port:port, db:db, host:host).then((nothing) {
      print("connected");
      cnx.useDatabase(db);
      Results results = cnx.query("select name as bob, age as wibble from people p");
      for (Field field in results.fields) {
        print("Field: ${field.name}");
      }
      for (List<Dynamic> row in results) {
        for (Dynamic field in row) {
          print(field);
        }
      }
      results = cnx.query("select * from blobby");
      Query query = cnx.prepare("select * from types");
      query.execute();
      query.close();
      cnx.close();
    });
  }

  log.debug("starting");
  AsyncConnection cnx = new AsyncMySqlConnection();
  cnx.connect(user:user, password:password, port:port, db:db, host:host).then((nothing) {
    log.debug("got connection");
    cnx.useDatabase(db).then((dummy) {
      cnx.query("select name as bob, age as wibble from people p").then((Results results) {
        log.debug("queried");
        for (Field field in results.fields) {
          print("Field: ${field.name}");
        }
        for (List<Dynamic> row in results) {
          for (Dynamic field in row) {
            log.debug(field);
          }
        }
        cnx.query("select * from blobby").then((Results results2) {
          log.debug("queried");
          
          testPreparedQuery(cnx, log);
        });
      });
    });
  });
}

void testPreparedQuery(AsyncConnection cnx, Log log) {
  cnx.prepare("select * from types").then((query) {
    log.debug("prepared $query");
//    query[0] = 35;
    var res = query.execute().then((dummy) {
      query.close();
      log.debug("stmt closed");
      testPreparedQuery2(cnx, log);
    });
  });
}

void testPreparedQuery2(AsyncConnection cnx, Log log) {
  log.debug('------------------------');
  cnx.prepare("update types set adatetime = ?").then((query) {
    query[0] = new Date.now();
    var res = query.execute().then((dummy) {
      query.close();
      log.debug("stmt closed");
      cnx.close();
    });
  });
}