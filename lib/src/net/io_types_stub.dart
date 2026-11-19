/// Stand-ins for the `dart:io` types the connection settings mention.
///
/// They exist so the same API compiles in the browser. A browser has no
/// socket and no way to upgrade one to TLS, so none of these can be used to
/// open a database connection.
class SocketException implements Exception {
  final String message;
  final OSError? osError;

  const SocketException(this.message, {this.osError});

  const SocketException.closed()
    : message = 'Socket has been closed',
      osError = null;

  @override
  String toString() => 'SocketException: $message';
}

class OSError {
  final String message;
  final int errorCode;

  const OSError([this.message = '', this.errorCode = 0]);

  @override
  String toString() => 'OS Error: $message, errno = $errorCode';
}

class HandshakeException implements Exception {
  final String message;

  HandshakeException([this.message = '']);

  @override
  String toString() => 'HandshakeException: $message';
}

class SecurityContext {
  SecurityContext();
}

class X509Certificate {
  X509Certificate();
}
