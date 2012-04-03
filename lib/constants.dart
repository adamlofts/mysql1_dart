final int CLIENT_LONG_PASSWORD = 1; /* new more secure passwords */
final int CLIENT_FOUND_ROWS = 2; /* Found instead of affected rows */
final int CLIENT_LONG_FLAG = 4; /* Get all column flags */
final int CLIENT_CONNECT_WITH_DB = 8; /* One can specify db on connect */
final int CLIENT_NO_SCHEMA = 16;  /* Don't allow database.table.column */
final int CLIENT_COMPRESS = 32;  /* Can use compression protocol */
final int CLIENT_ODBC = 64;  /* Odbc client */
final int CLIENT_LOCAL_FILES = 128; /* Can use LOAD DATA LOCAL */
final int CLIENT_IGNORE_SPACE = 256; /* Ignore spaces before '(' */
final int CLIENT_PROTOCOL_41 = 512; /* New 4.1 protocol */
final int CLIENT_INTERACTIVE = 1024;  /* This is an interactive client */
final int CLIENT_SSL = 2048;  /* Switch to SSL after handshake */
final int CLIENT_IGNORE_SIGPIPE = 4096;    /* IGNORE sigpipes */
final int CLIENT_TRANSACTIONS = 8192;  /* Client knows about transactions */
final int CLIENT_RESERVED = 16384;   /* Old flag for 4.1 protocol  */
final int CLIENT_SECURE_CONNECTION = 32768;  /* New 4.1 authentication */
final int CLIENT_MULTI_STATEMENTS = 65536;   /* Enable/disable multi-stmt support */
final int CLIENT_MULTI_RESULTS = 131072;  /* Enable/disable multi-results */

final int SERVER_STATUS_IN_TRANS = 1; /* Transaction has started */
final int SERVER_STATUS_AUTOCOMMIT = 2; /* Server in auto_commit mode */

