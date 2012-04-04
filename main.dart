#import('lib/sqljockey.dart');

void main() {
  Connection cnx = new MySqlConnection(user:'james');
  Future whenConnected = cnx.connect();
  whenConnected.then((nothing) {
    print("got connection");
    Future whenUsingDb = cnx.useDatabase('bob');
    whenUsingDb.then((nothing2) {
      cnx.query("select * from bill");
    });
  });
//  Database db = cnx.openDatabase('large');
//  
//  Results results = db.query('select * from projects');
//  print(results.count);
//  for (Result r in results) {
//    print(r.index);
//    print(r.value);
//  }
//  
//  Query q = db.prepare('select * from projects where fingerprint = ?');
//  q[0] = 135246234234;
//  results = q.execute();
//  
//  cnx.close();
}
