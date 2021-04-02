library mysql1.prepared_query;

import '../results/field.dart';

import 'prepare_handler.dart';

class PreparedQuery {
  final String sql;

  /// You cannot rely on the type of the parameters in mysql so we do not expose it as
  /// public api
  ///
  /// See https://jira.mariadb.org/browse/CONJ-568
  final int parameterCount;
  final List<Field> columns;
  final int statementHandlerId;

  PreparedQuery(PrepareHandler handler)
      : sql = handler.sql,
        parameterCount = handler.parameters.length,
        columns =
            List.from(handler.columns.where((element) => element != null)),
        statementHandlerId = handler.okPacket.statementHandlerId;
}
