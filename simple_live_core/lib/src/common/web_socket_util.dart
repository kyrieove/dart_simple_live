import 'dart:async';

import 'package:web_socket_channel/io.dart';

enum SocketStatus { connected, failed, closed }

class WebScoketUtils {
  SocketStatus status = SocketStatus.closed;

  /// 链接
  final String url;

  /// 备用链接
  final String? backupUrl;

  /// 心跳时间
  final int heartBeatTime;

  /// 接收到信息
  final Function(dynamic)? onMessage;

  /// 连接关闭
  final Function(String msg)? onClose;

  /// 尝试重连
  final Function()? onReconnect;

  /// 准备就绪
  final Function()? onReady;

  /// 心跳
  final Function()? onHeartBeat;

  /// 请求头
  Map<String, dynamic>? headers;
  WebScoketUtils({
    required this.url,
    required this.heartBeatTime,
    this.onMessage,
    this.onClose,
    this.onReconnect,
    this.onReady,
    this.onHeartBeat,
    this.headers,
    this.backupUrl,
  });
  IOWebSocketChannel? webSocket;
  Timer? heartBeatTimer;

  /// 重连次数
  int reconnectTime = 0;
  Timer? reconnectTimer;

  /// 最大重连次数
  int maxReconnectTime = 5;

  StreamSubscription<dynamic>? streamSubscription;

  void connect({bool retry = false}) async {
    // 只关连接本身, 不能碰重连计划, 否则重连只会试一次
    _closeSocket();
    try {
      var wsurl = url;
      if (backupUrl != null && backupUrl!.isNotEmpty && retry) {
        wsurl = backupUrl!;
      }
      webSocket = IOWebSocketChannel.connect(
        wsurl,
        connectTimeout: Duration(seconds: 10),
        headers: headers,
      );

      await webSocket?.ready;
      ready();
    } catch (e) {
      if (!retry) {
        connect(retry: true);
        return;
      }
      // 主地址和备用地址都连不上, 交给重连逻辑继续尝试,
      // 等真的重连不上了再通知调用方
      status = SocketStatus.failed;
      reconnect();
    }
  }

  /// 连接完成
  void ready() {
    status = SocketStatus.connected;

    streamSubscription = webSocket?.stream.listen(
      (data) => receiveMessage(data),
      onError: (e, s) => onError(e, s),
      onDone: onDone,
    );

    onReady?.call();
    initHeartBeat();
  }

  void initHeartBeat() {
    heartBeatTimer = Timer.periodic(Duration(milliseconds: heartBeatTime), (
      timer,
    ) {
      onHeartBeat?.call();
    });
  }

  void receiveMessage(dynamic data) {
    //接受到一条信息才算重连成功
    reconnectTime = 0;
    onMessage?.call(data);
  }

  void onError(e, s) {
    status = SocketStatus.failed;
    onClose?.call(e.toString());
  }

  void onDone() {
    if (status == SocketStatus.closed) {
      return;
    }
    onReconnect?.call();
    reconnect();
  }

  void sendMessage(dynamic message) {
    if (status == SocketStatus.connected) {
      webSocket?.sink.add(message);
    }
  }

  /// 只关掉连接, 保留重连计划
  void _closeSocket() {
    status = SocketStatus.closed;

    streamSubscription?.cancel();
    streamSubscription = null;

    webSocket?.sink.close();
    webSocket = null;

    heartBeatTimer?.cancel();
    heartBeatTimer = null;
  }

  /// 彻底关闭, 包括重连计划
  void close() {
    _closeSocket();

    reconnectTimer?.cancel();
    reconnectTimer = null;
  }

  void reconnect() {
    status = SocketStatus.closed;
    if (reconnectTime < maxReconnectTime) {
      reconnectTime++;
      reconnectTimer?.cancel();
      // 用一次性定时器, connect() 内部不会把下一次重连取消掉
      reconnectTimer = Timer(Duration(seconds: 5), () {
        connect();
      });
    } else {
      onClose?.call("重连超过最大次数，与服务器断开连接");
      close();
      return;
    }
  }
}
