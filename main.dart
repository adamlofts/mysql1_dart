#import('lib/sqljockey.dart');

void main() {
//  SyncConnection cnx = new SyncMySqlConnection();
//  cnx.connect(user:'root').then((nothing) {
//    print("connected");
//    cnx.useDatabase('bob');
//    Results results = cnx.query("select name as bob, age as wibble from people p");
//    for (Field field in results.fields) {
//      print("Field: ${field.name}");
//    }
//    for (List<Dynamic> row in results) {
//      for (Dynamic field in row) {
//        print(field);
//      }
//    }
//    cnx.close();
//  });

  AsyncConnection cnx = new AsyncMySqlConnection();
  cnx.connect(user:'root').then((nothing) {
    print("got connection");
    cnx.useDatabase('bob').then((nothing2) {
      cnx.query("select name as bob, age as wibble from people p").then((Results results) {
        print("queried");
        for (Field field in results.fields) {
          print("Field: ${field.name}");
        }
        for (List<Dynamic> row in results) {
          for (Dynamic field in row) {
            print(field);
          }
        }
        cnx.query("select * from blobby").then((Results results2) {
          print("queried");
          cnx.close();
        });
      });
    });
  });
}
