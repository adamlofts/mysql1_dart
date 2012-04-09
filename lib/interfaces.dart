interface Connection {
  Dynamic connect([String host, int port, String user, String password]);
  Dynamic useDatabase(String dbName);
  Dynamic query(String sql);
  Dynamic update(String sql);
  Query prepare(String sql);
  void close();
}

interface SyncConnection extends Connection {
  Future connect([String host, int port, String user, String password]);
  void useDatabase(String dbName);
  Results query(String sql);
  int update(String sql);
  Query prepare(String sql);
  void close();
}

interface AsyncConnection extends Connection {
  Future connect([String host, int port, String user, String password]);
  Future useDatabase(String dbName);
  Future<Results> query(String sql);
  Future<int> update(String sql);
  Query prepare(String sql);
  void close();
}

interface Query {
  Future<Results> execute();
  Future<int> executeUpdate();
  Dynamic operator [](int pos);
  void operator []=(int index, Dynamic value);
}

interface Field {
  String get name();
  String get table();
  String get catalog();
  String get orgName();
  String get orgTable();
  String get db();
  int get characterSet();
  int get length();
  int get type();
  int get flags();
  int get decimals();
  int get defaultValue();
}

interface Results extends Iterable default ResultsImpl {
  int get insertId();
  int get affectedRows();
  int get count();
  List<Field> get fields();
  List<Dynamic> operator [](int pos);
}
