#import('lib/sqljockey.dart');

void main() {
  Connection cnx = new MySqlConnection(host:'localhost', port:3307, user:'large', password:'large');
  Database db = cnx.openDatabase('large');
  
  Results results = db.query('select * from projects');
  print(results.count);
  for (Result r in results) {
    print(r.index);
    print(r.value);
  }
  
  Query q = db.prepare('select * from projects where fingerprint = ?');
  q[0] = 135246234234;
  results = q.execute();
  
  cnx.close();
}
