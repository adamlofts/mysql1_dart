library sqljocky.connection_helpers;

import 'connection.dart';
import 'mysql_exception.dart';

/// For implementation use only
abstract class ConnectionHelpers {
  releaseReuseThrow(Connection cnx, dynamic e) {
    if (!(e is MySqlException)) {
      removeConnection(cnx);
    }
    throw e;
  }

  removeConnection(Connection cnx);
}
