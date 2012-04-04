interface Connection {
  Future connect();
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
