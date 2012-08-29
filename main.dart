#import('lib/sqljocky.dart');
#import('packages/logging/logging.dart');
#import('options.dart');

// ignore this file - runintegrationtests.dart is more useful at the moment
void main() {
  Logger log = new Logger("main");
  
  OptionsFile options = new OptionsFile('connection.options');
  String user = options.getString('user');
  String password = options.getString('password');
  int port = options.getInt('port', 3306);
  String db = options.getString('db');
  String host = options.getString('host', 'localhost');
  
  log.fine("starting");
  Connection cnx = new Connection();
  Query thequery;
  cnx.connect(user:user, password:password, port:port, db:db, host:host).chain((nothing) {
    log.fine("got connection");
    return cnx.useDatabase(db);
  }).chain((dummy) {
    return cnx.query("select name as bob, age as wibble from people p");
  }).chain((Results results) {
    log.fine("queried");
    for (Field field in results.fields) {
      print("Field: ${field.name}");
    }
    for (List<Dynamic> row in results) {
      for (Dynamic field in row) {
        log.fine(field);
      }
    }
    return cnx.query("select * from blobby");
  }).chain((Results results) {
    log.fine("queried");
    
    return cnx.prepare("select * from types");
  }).chain((query) {
    thequery = query;
    log.fine("prepared $query");
    // query[0] = 35;
    return query.execute();
  }).chain((Results results) {
    thequery.close();
    log.fine("stmt closed");
    log.fine('------------------------');
    return cnx.prepare("update types set adatetime = ?");
  }).chain((query) {
    thequery = query;
    query[0] = new Date.now();
    return query.execute();
  }).then((Results results) {
    thequery.close();
    log.fine("stmt closed");
    cnx.close();
  });
}