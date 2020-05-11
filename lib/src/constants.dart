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

library mysql1.constants;

/*
 * This file is based on excerpts from include/mysql_com.h
 */

const int PACKET_OK = 0;
const int PACKET_ERROR = 0xFF;
const int PACKET_EOF = 0xFE;

const int CLIENT_LONG_PASSWORD = 1 << 0;
const int CLIENT_FOUND_ROWS = 1 << 1;
const int CLIENT_LONG_FLAG = 1 << 2;
const int CLIENT_CONNECT_WITH_DB = 1 << 3;
const int CLIENT_NO_SCHEMA = 1 << 4;
const int CLIENT_COMPRESS = 1 << 5;
const int CLIENT_ODBC = 1 << 6;
const int CLIENT_LOCAL_FILES = 1 << 7;
const int CLIENT_IGNORE_SPACE = 1 << 8;
const int CLIENT_PROTOCOL_41 = 1 << 9;
const int CLIENT_INTERACTIVE = 1 << 10;
const int CLIENT_SSL = 1 << 11;
const int CLIENT_IGNORE_SIGPIPE = 1 << 12;
const int CLIENT_TRANSACTIONS = 1 << 13;
const int CLIENT_RESERVED = 1 << 14;
const int CLIENT_SECURE_CONNECTION = 1 << 15;
const int CLIENT_MULTI_STATEMENTS = 1 << 16;
const int CLIENT_MULTI_RESULTS = 1 << 17;
const int CLIENT_PLUGIN_AUTH = 1 << 19;

const int SERVER_STATUS_IN_TRANS = 1;
const int SERVER_STATUS_AUTOCOMMIT = 2;
const int SERVER_MORE_RESULTS_EXISTS = 8;

const int ERROR_UNKNOWN_TABLE = 1051;
const int
    ERROR_CANNOT_DELETE_OR_UPDATE_PARENT_ROW_FOREIGN_KEY_CONSTRAINT_FAILS =
    1217;

const int COM_SLEEP = 0x00;
const int COM_QUIT = 0x01;
const int COM_INIT_DB = 0x02;
const int COM_QUERY = 0x03;
const int COM_FIELD_LIST = 0x04;
const int COM_CREATE_DB = 0x05;
const int COM_DROP_DB = 0x06;
const int COM_REFRESH = 0x07;
const int COM_SHUTDOWN = 0x08;
const int COM_STATISTICS = 0x09;
const int COM_PROCESS_INFO = 0x0a;
const int COM_CONNECT = 0x0b;
const int COM_PROCESS_KILL = 0x0c;
const int COM_DEBUG = 0x0d;
const int COM_PING = 0x0e;
const int COM_TIME = 0x0f;
const int COM_DELAYED_INSERT = 0x10;
const int COM_CHANGE_USER = 0x11;
const int COM_BINLOG_DUMP = 0x12;
const int COM_TABLE_DUMP = 0x13;
const int COM_CONNECT_OUT = 0x14;
const int COM_REGISTER_SLAVE = 0x15;
const int COM_STMT_PREPARE = 0x16;
const int COM_STMT_EXECUTE = 0x17;
const int COM_STMT_SEND_LONG_DATA = 0x18;
const int COM_STMT_CLOSE = 0x19;
const int COM_STMT_RESET = 0x1a;
const int COM_SET_OPTION = 0x1b;
const int COM_STMT_FETCH = 0x1c;

const int FIELD_TYPE_DECIMAL = 0x00;
const int FIELD_TYPE_TINY = 0x01;
const int FIELD_TYPE_SHORT = 0x02;
const int FIELD_TYPE_LONG = 0x03;
const int FIELD_TYPE_FLOAT = 0x04;
const int FIELD_TYPE_DOUBLE = 0x05;
const int FIELD_TYPE_NULL = 0x06;
const int FIELD_TYPE_TIMESTAMP = 0x07;
const int FIELD_TYPE_LONGLONG = 0x08;
const int FIELD_TYPE_INT24 = 0x09;
const int FIELD_TYPE_DATE = 0x0a;
const int FIELD_TYPE_TIME = 0x0b;
const int FIELD_TYPE_DATETIME = 0x0c;
const int FIELD_TYPE_YEAR = 0x0d;
const int FIELD_TYPE_NEWDATE = 0x0e;
const int FIELD_TYPE_VARCHAR = 0x0f;
const int FIELD_TYPE_BIT = 0x10;

const int FIELD_TYPE_JSON = 0xf5;
const int FIELD_TYPE_NEWDECIMAL = 0xf6;
const int FIELD_TYPE_ENUM = 0xf7;
const int FIELD_TYPE_SET = 0xf8;
const int FIELD_TYPE_TINY_BLOB = 0xf9;
const int FIELD_TYPE_MEDIUM_BLOB = 0xfa;
const int FIELD_TYPE_LONG_BLOB = 0xfb;
const int FIELD_TYPE_BLOB = 0xfc;
const int FIELD_TYPE_VAR_STRING = 0xfd;
const int FIELD_TYPE_STRING = 0xfe;
const int FIELD_TYPE_GEOMETRY = 0xff;

const int NOT_NULL_FLAG = 0x0001;
const int PRI_KEY_FLAG = 0x0002;
const int UNIQUE_KEY_FLAG = 0x0004;
const int MULTIPLE_KEY_FLAG = 0x0008;
const int BLOB_FLAG = 0x0010;
const int UNSIGNED_FLAG = 0x0020;
const int ZEROFILL_FLAG = 0x0040;
const int BINARY_FLAG = 0x0080;
const int ENUM_FLAG = 0x0100;
const int AUTO_INCREMENT_FLAG = 0x0200;
const int TIMESTAMP_FLAG = 0x0400;
const int SET_FLAG = 0x0800;
