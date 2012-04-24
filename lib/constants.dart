/* Copyright (C) 2000 MySQL AB
   Copyright (C) 2012 James Ots

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; version 2 of the License.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA */

/*
 * This file is based on excerpts from include/mysql_com.h
 */

final int PACKET_OK = 0;
final int PACKET_ERROR = 0xFF;
final int PACKET_EOF = 0xFE;

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
final int SERVER_MORE_RESULTS_EXISTS = 8;

final int COM_SLEEP = 0x00; // (none, this is an internal thread state)
final int COM_QUIT = 0x01; // mysql_close
final int COM_INIT_DB = 0x02; // mysql_select_db 
final int COM_QUERY = 0x03; // mysql_real_query
final int COM_FIELD_LIST = 0x04; // mysql_list_fields
final int COM_CREATE_DB = 0x05; // mysql_create_db (deprecated)
final int COM_DROP_DB = 0x06; // mysql_drop_db (deprecated)
final int COM_REFRESH = 0x07; // mysql_refresh
final int COM_SHUTDOWN = 0x08; // mysql_shutdown
final int COM_STATISTICS = 0x09; // mysql_stat
final int COM_PROCESS_INFO = 0x0a; // mysql_list_processes
final int COM_CONNECT = 0x0b; // (none, this is an internal thread state)
final int COM_PROCESS_KILL = 0x0c; // mysql_kill
final int COM_DEBUG = 0x0d; // mysql_dump_debug_info
final int COM_PING = 0x0e; // mysql_ping
final int COM_TIME = 0x0f; // (none, this is an internal thread state)
final int COM_DELAYED_INSERT = 0x10; // (none, this is an internal thread state)
final int COM_CHANGE_USER = 0x11; // mysql_change_user
final int COM_BINLOG_DUMP = 0x12; // sent by the slave IO thread to request a binlog
final int COM_TABLE_DUMP = 0x13; // LOAD TABLE ... FROM MASTER (deprecated)
final int COM_CONNECT_OUT = 0x14; // (none, this is an internal thread state)
final int COM_REGISTER_SLAVE = 0x15; // sent by the slave to register with the master (optional)
final int COM_STMT_PREPARE = 0x16; // mysql_stmt_prepare
final int COM_STMT_EXECUTE = 0x17; // mysql_stmt_execute
final int COM_STMT_SEND_LONG_DATA = 0x18; // mysql_stmt_send_long_data
final int COM_STMT_CLOSE = 0x19; // mysql_stmt_close
final int COM_STMT_RESET = 0x1a; // mysql_stmt_reset
final int COM_SET_OPTION = 0x1b; // mysql_set_server_option
final int COM_STMT_FETCH = 0x1c; // mysql_stmt_fetch

final int FIELD_TYPE_DECIMAL = 0x00;
final int FIELD_TYPE_TINY = 0x01;
final int FIELD_TYPE_SHORT = 0x02;
final int FIELD_TYPE_LONG = 0x03;
final int FIELD_TYPE_FLOAT = 0x04;
final int FIELD_TYPE_DOUBLE = 0x05;
final int FIELD_TYPE_NULL = 0x06;
final int FIELD_TYPE_TIMESTAMP = 0x07;
final int FIELD_TYPE_LONGLONG = 0x08;
final int FIELD_TYPE_INT24 = 0x09;
final int FIELD_TYPE_DATE = 0x0a;
final int FIELD_TYPE_TIME = 0x0b;
final int FIELD_TYPE_DATETIME = 0x0c;
final int FIELD_TYPE_YEAR = 0x0d;
final int FIELD_TYPE_NEWDATE = 0x0e;
final int FIELD_TYPE_VARCHAR = 0x0f;
final int FIELD_TYPE_BIT = 0x10;
final int FIELD_TYPE_NEWDECIMAL = 0xf6;
final int FIELD_TYPE_ENUM = 0xf7;
final int FIELD_TYPE_SET = 0xf8;
final int FIELD_TYPE_TINY_BLOB = 0xf9;
final int FIELD_TYPE_MEDIUM_BLOB = 0xfa;
final int FIELD_TYPE_LONG_BLOB = 0xfb;
final int FIELD_TYPE_BLOB = 0xfc;
final int FIELD_TYPE_VAR_STRING = 0xfd;
final int FIELD_TYPE_STRING = 0xfe;
final int FIELD_TYPE_GEOMETRY = 0xff;

final int NOT_NULL_FLAG = 0x0001;
final int PRI_KEY_FLAG = 0x0002;
final int UNIQUE_KEY_FLAG = 0x0004;
final int MULTIPLE_KEY_FLAG = 0x0008;
final int BLOB_FLAG = 0x0010;
final int UNSIGNED_FLAG = 0x0020;
final int ZEROFILL_FLAG = 0x0040;
final int BINARY_FLAG = 0x0080;
final int ENUM_FLAG = 0x0100;
final int AUTO_INCREMENT_FLAG = 0x0200;
final int TIMESTAMP_FLAG = 0x0400;
final int SET_FLAG = 0x0800;

String fieldTypeToString(int type) {
  switch (type) {
    case 0x00: return "DECIMAL";
    case 0x01: return "TINY";
    case 0x02: return "SHORT";
    case 0x03: return "LONG";
    case 0x04: return "FLOAT";
    case 0x05: return "DOUBLE";
    case 0x06: return "NULL";
    case 0x07: return "TIMESTAMP";
    case 0x08: return "LONGLONG";
    case 0x09: return "INT24";
    case 0x0a: return "DATE";
    case 0x0b: return "TIME";
    case 0x0c: return "DATETIME";
    case 0x0d: return "YEAR";
    case 0x0e: return "NEWDATE";
    case 0x0f: return "VARCHAR";
    case 0x10: return "BIT";
    case 0xf6: return "NEWDECIMAL";
    case 0xf7: return "ENUM";
    case 0xf8: return "SET";
    case 0xf9: return "TINY_BLOB";
    case 0xfa: return "MEDIUM_BLOB";
    case 0xfb: return "LONG_BLOB";
    case 0xfc: return "BLOB";
    case 0xfd: return "VAR_STRING";
    case 0xfe: return "STRING";
    case 0xff: return "GEOMETRY";
    default: return "UNKNOWN";
  }
}
