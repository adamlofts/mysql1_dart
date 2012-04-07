#import('lib/sqljockey.dart');

void main() {
//  SyncConnection cnx = new SyncMySqlConnection();
//  cnx.connect(user:'root').then((nothing) {
//    print("connected");
//    cnx.useDatabase('bob');
//    cnx.query("select * from people");
//    cnx.close();
//  });

  AsyncConnection cnx = new AsyncMySqlConnection();
  cnx.connect(user:'root').then((nothing) {
    print("got connection");
    cnx.useDatabase('bob').then((nothing2) {
      cnx.query("select * from people").then((Results results) {
        print("queried");
        cnx.close();
      });
    });
  });
}
