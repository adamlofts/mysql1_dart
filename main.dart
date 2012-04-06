#import('lib/sqljockey.dart');

void main() {
//  Connection cnx = new MySqlConnection.sync();
//  cnx.connect(user:'root').then((nothing) {
//    print("connected");
//    cnx.useDatabase('test');
//    cnx.query("select * from bill");
//  });

  Connection cnx = new MySqlConnection.sync();
  cnx.connect(user:'root').then((nothing) {
    print("got connection");
    cnx.useDatabase('test').then((nothing2) {
      cnx.query("select * from bill").then((Results results) {
        print("queried");
      });
    });
  });
}
