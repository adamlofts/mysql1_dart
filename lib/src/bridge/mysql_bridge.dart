import 'dart:async';
import 'dart:io';

import 'bridge_protocol.dart';

/// A WebSocket which carries one MySQL connection's bytes.
///
/// The browser cannot open TCP, so it cannot talk to MySQL itself. This
/// process can. A client connects here, proves it knows [token], and from
/// then on every binary frame is written to the database socket and every
/// byte the database writes is sent back as a binary frame.
///
/// The database address is the one given here. It is not taken from the
/// client. A page that could name the address could point this process at
/// any host it can reach, which is a socket open to that whole network.
class MysqlBridge {
  final HttpServer _server;
  final String _token;
  final String mysqlHost;
  final int mysqlPort;
  final String? _origin;
  final Duration _mysqlTimeout;
  final int _maxFrameSize;
  final int _maxConnections;
  int _active = 0;

  MysqlBridge._(
    this._server,
    this._token,
    this.mysqlHost,
    this.mysqlPort,
    this._origin,
    this._mysqlTimeout,
    this._maxFrameSize,
    this._maxConnections,
  );

  /// The WebSocket URL a client passes as `ConnectionSettings.bridgeUrl`.
  String get url => 'ws://${_server.address.host}:${_server.port}$bridgePath';

  /// Listen on [bindHost] and [port] and forward each authenticated
  /// WebSocket to [mysqlHost]:[mysqlPort].
  ///
  /// [token] has to be at least 16 characters. It is what a client must send
  /// before any byte is exchanged with the database. [origin], when set, is
  /// the only `Origin` header that is upgraded; a browser sends that header,
  /// so this is what ties the bridge to one site. [port] 0 picks a free port,
  /// which is what tests want.
  static Future<MysqlBridge> start({
    required String token,
    String mysqlHost = '127.0.0.1',
    int mysqlPort = 3306,
    String bindHost = '127.0.0.1',
    int port = 8080,
    String? origin,
    Duration mysqlTimeout = const Duration(seconds: 10),
    int maxFrameSize = 16 * 1024 * 1024 + 4,
    int maxConnections = 64,
  }) async {
    if (token.length < 16) {
      throw ArgumentError.value(
        token.length,
        'token',
        'must be at least 16 characters. The token itself is not shown.',
      );
    }
    final server = await HttpServer.bind(bindHost, port);
    final bridge = MysqlBridge._(
      server,
      token,
      mysqlHost,
      mysqlPort,
      origin,
      mysqlTimeout,
      maxFrameSize,
      maxConnections,
    );
    server.listen((request) {
      unawaited(bridge._onRequest(request));
    });
    return bridge;
  }

  /// Stop listening and drop the sockets still open.
  Future<void> close() => _server.close(force: true);

  Future<void> _onRequest(HttpRequest request) async {
    if (request.uri.path != bridgePath) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final allowed = _origin;
    if (allowed != null &&
        request.headers.value('origin') != allowed) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    if (_active >= _maxConnections) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
      return;
    }
    _active++;
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      await _pipe(socket);
    } catch (_) {
      // The upgrade failed, or the pipe ended with an error. Either way the
      // connection is not left open: _pipe closes both ends.
    } finally {
      _active--;
    }
  }

  Future<void> _pipe(WebSocket ws) {
    final done = Completer<void>();
    final early = <List<int>>[];
    var phase = _Phase.auth;
    Socket? tcp;
    var finished = false;
    Timer? timer;

    // Idempotent. Closing the database socket makes its own done event fire,
    // and closing the WebSocket makes this run again from onDone. The first
    // call is the one that counts, and it has to complete [done] or the
    // connection is counted as open forever.
    void finish({int? code, String? reason}) {
      if (finished) {
        return;
      }
      finished = true;
      phase = _Phase.closed;
      timer?.cancel();
      tcp?.destroy();
      tcp = null;
      try {
        // A code is how the client tells a refused login from a database that
        // simply went away. Closing with none at all is a normal end, which
        // is what the database socket closing looks like.
        if (reason == null) {
          ws.close(code ?? 1000);
        } else {
          ws.close(code ?? 1000, reason);
        }
      } catch (_) {
        // Already closing. The done future below is what matters.
      }
      if (!done.isCompleted) {
        done.complete();
      }
    }

    timer = Timer(const Duration(seconds: 5), () {
      if (phase == _Phase.auth) {
        finish(code: 1008, reason: 'auth timeout');
      }
    });

    ws.pingInterval = const Duration(seconds: 30);
    ws.listen(
      (data) {
        if (phase == _Phase.closed) {
          return;
        }
        if (phase == _Phase.auth) {
          timer?.cancel();
          final text = data is String ? data : '';
          final presented = text.startsWith(bridgeAuthPrefix)
              ? text.substring(bridgeAuthPrefix.length)
              : '';
          if (!bridgeTokenMatches(presented, _token)) {
            finish(code: 1008, reason: 'unauthorized');
            return;
          }
          phase = _Phase.connecting;
          unawaited(
            _dial(
              ws,
              early,
              () => phase,
              (next) {
                phase = next;
              },
              (socket) {
                tcp = socket;
              },
              finish,
              () => finished,
            ),
          );
          return;
        }
        if (phase == _Phase.connecting) {
          _bufferClientBytes(data, early, finish);
          return;
        }
        final socket = tcp;
        if (socket == null) {
          return;
        }
        _writeToDatabase(data, socket, finish);
      },
      onError: (_, __) {
        finish();
      },
      onDone: () {
        finish();
      },
    );

    return done.future;
  }

  Future<void> _dial(
    WebSocket ws,
    List<List<int>> early,
    _Phase Function() readPhase,
    void Function(_Phase phase) writePhase,
    void Function(Socket socket) takeSocket,
    void Function({int? code, String? reason}) finish,
    bool Function() isFinished,
  ) async {
    final Socket tcp;
    try {
      tcp = await Socket.connect(mysqlHost, mysqlPort, timeout: _mysqlTimeout);
      tcp.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {
      if (isFinished()) {
        return;
      }
      finish(code: 1011, reason: 'database unreachable');
      return;
    }
    if (isFinished()) {
      tcp.destroy();
      return;
    }
    takeSocket(tcp);
    writePhase(_Phase.open);
    ws.add(bridgeAuthOk);
    for (final chunk in early) {
      tcp.add(chunk);
    }
    early.clear();
    tcp.listen(
      (chunk) {
        if (readPhase() == _Phase.open) {
          ws.add(chunk);
        }
      },
      onError: (_, __) {
        finish(code: 1011, reason: 'database closed');
      },
      onDone: () {
        finish();
      },
    );
  }

  void _bufferClientBytes(
    Object? data,
    List<List<int>> early,
    void Function({int? code, String? reason}) finish,
  ) {
    if (data is! List<int>) {
      finish(code: 1003, reason: 'binary only');
      return;
    }
    if (data.length > _maxFrameSize) {
      finish(code: 1009, reason: 'frame too large');
      return;
    }
    early.add(data);
  }

  void _writeToDatabase(
    Object? data,
    Socket tcp,
    void Function({int? code, String? reason}) finish,
  ) {
    if (data is! List<int>) {
      finish(code: 1003, reason: 'binary only');
      return;
    }
    if (data.length > _maxFrameSize) {
      finish(code: 1009, reason: 'frame too large');
      return;
    }
    tcp.add(data);
  }
}

enum _Phase { auth, connecting, open, closed }
