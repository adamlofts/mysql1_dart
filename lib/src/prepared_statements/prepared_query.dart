library mysql1.prepared_query;

import '../results/field.dart';

import 'prepare_handler.dart';

class PreparedQuery {
  final String sql;
  final List<Field> parameters;
  final List<Field> columns;
  final int statementHandlerId;

  PreparedQuery(PrepareHandler handler)
      : sql = handler.sql,
        parameters = handler.parameters,
        columns = handler.columns,
        statementHandlerId = handler.okPacket.statementHandlerId;
}
