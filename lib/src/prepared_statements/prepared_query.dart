part of sqljocky;

class _PreparedQuery {
  final String sql;
  final List<FieldImpl> parameters;
  final List<FieldImpl> columns;
  final int statementHandlerId;
  _Connection cnx;

  _PreparedQuery(_PrepareHandler handler)
      : sql = handler.sql,
        parameters = handler.parameters,
        columns = handler.columns,
        statementHandlerId = handler.okPacket.statementHandlerId;
}
