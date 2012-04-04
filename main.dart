#import('lib/sqljockey.dart');

void main() {
  Connection cnx = new MySqlConnection(user:'james');
  cnx.connect().then((nothing) {
    print("got connection");
    cnx.useDatabase('bob').then((nothing2) {
      cnx.query("select * from bill").then((Results results) {
        print("queried");
      });
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
