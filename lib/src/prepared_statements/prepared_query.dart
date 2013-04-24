part of sqljocky;

class _PreparedQuery {
  final String sql;
  final List<_FieldImpl> parameters;
  final List<_FieldImpl> columns;
  final int statementHandlerId;
  dynamic cnx; // should be a Connection

  _PreparedQuery(_PrepareHandler handler) :
      sql = handler.sql,
      parameters = handler.parameters,
      columns = handler.columns,
      
      statementHandlerId = handler.okPacket.statementHandlerId;
}
