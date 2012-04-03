interface Connection {
  Database openDatabase(String dbName);
  void close();
}

interface Database {
  Results query(String sql);
  int update(String sql);
  Query prepare(String sql);
  void close();
}

interface Query {
  Results execute();
  int executeUpdate();
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
