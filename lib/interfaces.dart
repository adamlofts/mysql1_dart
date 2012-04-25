interface Connection default MySqlConnection {
  Connection();
  Future connect([String host, int port, String user, String password, String db]);
  Future useDatabase(String dbName);
  Future<Results> query(String sql);
  Future<int> update(String sql);
  Future<Query> prepare(String sql);
  Future<Results> prepareExecute(String sql, List<List<Dynamic>> parameters);
  void close();
  Future ping();
  Future debug();
//  Dynamic fieldList(String table, [String column]);
//  Dynamic refresh(bool grant, bool log, bool tables, bool hosts,
//                  bool status, bool threads, bool slave, bool master);
//  Dynamic shutdown(bool def, bool waitConnections, bool waitTransactions,
//                   bool waitUpdates, bool waitAllBuffers,
//                   bool waitCriticalBuffers, bool killQuery, bool killConnection);
//  Dynamic statistics();
//  Dynamic processInfo();
//  Dynamic processKill(int id);
//  Dynamic changeUser(String user, String password, [String db]);
//  Dynamic binlogDump(options);
//  Dynamic registerSlave(options);
//  Dynamic setOptions(int option);
}

interface Query {
  Future<Results> execute();
  Future<List<Results>> executeMulti(List<List<Dynamic>> parameters);
  Future<int> executeUpdate();
  void close();
//  Dynamic longData(int index, data);
//  Dynamic reset();
//  Dynamic fetch(int rows);
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
