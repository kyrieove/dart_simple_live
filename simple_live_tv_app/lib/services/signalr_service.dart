import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/app/utils.dart';

enum SignalRConnectionState {
  connecting,
  connected,
  disconnected,
}

class SignalRService {
  static const String kUrl = "https://sync1.nsapps.cn/sync";

  SignalRConnectionState state = SignalRConnectionState.connecting;

  final _stateStreamController =
      StreamController<SignalRConnectionState>.broadcast();
  Stream<SignalRConnectionState> get stateStream =>
      _stateStreamController.stream;

  final _onFavoriteStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onFavoriteStream =>
      _onFavoriteStreamController.stream;

  final _onHistoryStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onHistoryStream =>
      _onHistoryStreamController.stream;

  final _onShieldWordStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onShieldWordStream =>
      _onShieldWordStreamController.stream;

  final _onBiliAccountStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onBiliAccountStream =>
      _onBiliAccountStreamController.stream;

  final _onRoomDestroyedStreamController = StreamController<String>.broadcast();
  Stream<String> get onRoomDestroyedStream =>
      _onRoomDestroyedStreamController.stream;

  final _onRoomUserUpdatedStreamController =
      StreamController<List<RoomUser>>.broadcast();
  Stream<List<RoomUser>> get onRoomUserUpdatedStream =>
      _onRoomUserUpdatedStreamController.stream;

  HubConnection? hubConnection;

  Future<void> connect() async {
    // 上一次连接要先停掉再换, 否则旧连接还在跑, 也没人再引用它
    await _stopHubConnection();

    var connection = HubConnectionBuilder().withUrl(kUrl).build();
    hubConnection = connection;
    connection.onclose(({Exception? error}) {
      state = SignalRConnectionState.disconnected;
      _stateStreamController.add(state);
    });
    connection.onreconnected(({String? connectionId}) {
      Log.d("reconnected: $connectionId");
      state = SignalRConnectionState.connected;
      _stateStreamController.add(state);
    });
    try {
      await connection.start();
    } catch (e) {
      // 握手失败, 或者握手还没结束连接就被销毁了
      Log.logPrint(e);
      return;
    }

    // 握手期间连接已经被换掉或者销毁了, 不能再改状态
    if (!identical(hubConnection, connection)) {
      return;
    }
    state = SignalRConnectionState.connected;
    _stateStreamController.add(state);
    _listen();
  }

  /// 停掉当前连接
  ///
  /// stop() 会等握手结束, 所以返回之后连接一定已经停了,
  /// 不会留下一个还在跑、也没人引用的连接。
  Future<void> _stopHubConnection() async {
    var connection = hubConnection;
    hubConnection = null;
    await connection?.stop();
  }

  void _listen() {
    hubConnection?.on("onFavoriteReceived", (args) {
      _onFavoriteStreamController.add((args![0] as bool, args[1] as String));
    });
    hubConnection?.on("onHistoryReceived", (args) {
      _onHistoryStreamController.add((args![0] as bool, args[1] as String));
    });
    hubConnection?.on("onShieldWordReceived", (args) {
      _onShieldWordStreamController.add((args![0] as bool, args[1] as String));
    });
    hubConnection?.on("onBiliAccountReceived", (args) {
      _onBiliAccountStreamController.add((args![0] as bool, args[1] as String));
    });
    hubConnection?.on("onRoomDestroyed", (args) {
      _onRoomDestroyedStreamController.add(args![0].toString());
    });
    hubConnection?.on("onUserUpdated", (args) {
      var list = (args![0] as List).map((e) => RoomUser.fromObject(e)).toList();
      _onRoomUserUpdatedStreamController.add(list);
    });
  }

  Future<void> disconnect() async {
    await hubConnection?.stop();
    state = SignalRConnectionState.disconnected;
    _stateStreamController.add(state);
  }

  Future<Resp<String>> createRoom() async {
    if (state != SignalRConnectionState.connected) {
      throw Exception("not connected");
    }
    String app = "Simple Live TV";
    String platform = 'tv';
    String version = Utils.packageInfo.version;
    var resp = await hubConnection
        ?.invoke("CreateRoom", args: [app, platform, version]);
    return Resp<String>.fromObject(resp);
  }

  Future<Resp> joinRoom(String roomId) async {
    if (state != SignalRConnectionState.connected) {
      throw Exception("not connected");
    }
    String app = "Simple Live TV";
    String platform = 'tv';
    String version = Utils.packageInfo.version;
    var resp = await hubConnection
        ?.invoke("JoinRoom", args: [roomId, app, platform, version]);
    return Resp.fromObject(resp);
  }

  Future<Resp> sendContent({
    required String roomName,
    required String action,
    required bool overlay,
    required String content,
  }) async {
    if (state != SignalRConnectionState.connected) {
      throw Exception("not connected");
    }
    var resp =
        await hubConnection?.invoke(action, args: [roomName, overlay, content]);
    return Resp.fromObject(resp);
  }

  Future<void> dispose() async {
    // 先停连接再关流: stop 会触发 onclose 回调, 那时候流还没关
    await _stopHubConnection();

    _stateStreamController.close();
    _onFavoriteStreamController.close();
    _onHistoryStreamController.close();
    _onShieldWordStreamController.close();
    _onBiliAccountStreamController.close();
    _onRoomDestroyedStreamController.close();
    _onRoomUserUpdatedStreamController.close();
  }
}

class Resp<T> {
  final bool isSuccess;
  final String message;
  final T? data;
  Resp(this.isSuccess, this.message, this.data);

  factory Resp.fromJson(Map<String, dynamic> json) {
    return Resp(
      json['isSuccess'],
      json['message'] ?? "",
      json['data'],
    );
  }

  factory Resp.fromObject(Object? obj) {
    if (obj is Map<String, dynamic>) {
      return Resp.fromJson(obj);
    }
    return Resp(false, "unknown", null);
  }
}

class RoomUser {
  final String connectionId;
  final String shortId;
  final String platform;
  final String version;
  final String app;
  final bool? isCreator;

  RoomUser({
    required this.connectionId,
    required this.shortId,
    required this.platform,
    required this.version,
    required this.app,
    this.isCreator = false,
  });

  factory RoomUser.fromJson(Map<String, dynamic> json) {
    return RoomUser(
      connectionId: json['connectionId'],
      shortId: json['shortId'],
      platform: json['platform'],
      version: json['version'],
      app: json['app'],
      isCreator: json['isCreator'],
    );
  }

  factory RoomUser.fromObject(Object? obj) {
    if (obj is Map<String, dynamic>) {
      return RoomUser.fromJson(obj);
    }
    return RoomUser(
      connectionId: "",
      shortId: "",
      platform: "",
      version: "",
      app: "",
    );
  }
}
