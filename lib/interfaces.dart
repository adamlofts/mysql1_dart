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
  operator [](int pos);
  void operator []=(int index, value);
}

interface Results extends Iterable default ResultsImpl {
  int get count();
  operator [](int pos);
  void operator []=(int index, value);
}

interface Result default ResultImpl {
  get value();
  int get index();
}
