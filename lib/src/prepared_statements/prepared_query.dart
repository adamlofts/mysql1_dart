library sqljocky.prepared_query;

import '../results/field_impl.dart';

import 'prepare_handler.dart';

class PreparedQuery {
  final String sql;
  final List<FieldImpl> parameters;
  final List<FieldImpl> columns;
  final int statementHandlerId;

  PreparedQuery(PrepareHandler handler)
      : sql = handler.sql,
        parameters = handler.parameters,
        columns = handler.columns,
        statementHandlerId = handler.okPacket.statementHandlerId;
}
