import 'dart:async';

import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/event_bus.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';
import 'package:simple_live_tv_app/models/db/history.dart';
import 'package:simple_live_tv_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_tv_app/services/db_service.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';

class LiveRoomController extends PlayerController with WidgetsBindingObserver {
  final Site pSite;
  final String pRoomId;
  late LiveDanmaku liveDanmaku;
  LiveRoomController({
    required this.pSite,
    required this.pRoomId,
  }) {
    rxSite = pSite.obs;
    rxRoomId = pRoomId.obs;
    liveDanmaku = site.liveSite.getDanmaku();
  }
  final FocusNode focusNode = FocusNode();
  late Rx<Site> rxSite;
  Site get site => rxSite.value;
  late Rx<String> rxRoomId;
  String get roomId => rxRoomId.value;

  Rx<LiveRoomDetail?> detail = Rx<LiveRoomDetail?>(null);
  var online = 0.obs;
  var followed = false.obs;
  var liveStatus = false.obs;

  /// 清晰度数据
  RxList<LivePlayQuality> qualites = RxList<LivePlayQuality>();

  /// 当前清晰度
  var currentQuality = -1;
  var currentQualityInfo = "".obs;

  /// 线路数据
  RxList<String> playUrls = RxList<String>();

  Map<String, String>? playHeaders;

  /// 当前线路
  var currentLineIndex = -1;
  var currentLineInfo = "".obs;

  /// 是否处于后台
  var isBackground = false;

  var datetime = "00:00".obs;

  /// 是否正在自动恢复播放（卡死重连 / 无画面自愈）
  var reconnecting = false.obs;

  /// 计时器
  Timer? _clockTimer;

  /// 播放看门狗
  Timer? _watchdogTimer;

  /// 上一次播放位置发生变化的时间
  DateTime _lastPositionAt = DateTime.now();

  /// 上一次记录的播放位置
  Duration _lastPosition = Duration.zero;

  /// 播放器进入缓冲状态的时间
  DateTime _bufferingSince = DateTime.now();

  /// 上一次的缓冲状态
  bool _buffering = false;

  /// 本次打开媒体后播放位置是否推进过
  ///
  /// 部分直播源没有时间戳，position 会一直是 0，这种情况不能当成卡死。
  bool _positionAdvanced = false;

  /// 连续恢复失败次数
  int _recoverFailedCount = 0;

  /// 本次打开媒体的时间
  DateTime _mediaOpenedAt = DateTime.now();

  /// 开始检测画面的时间
  DateTime _videoCheckAt = DateTime.now();

  /// 上一次检测到卡死的时间
  DateTime _lastStallAt = DateTime.now();

  /// 连续卡死次数
  int _stallRetryCount = 0;

  /// 是否正在处理无画面
  bool _handlingNoVideo = false;

  /// 是否正在处理卡死
  bool _handlingStall = false;

  /// 是否已经退回软件解码
  bool _useSoftwareDecode = false;

  /// 是否正在销毁
  bool _isDisposing = false;

  /// 本次观看的开始时间
  DateTime? _watchStartAt;

  /// 本次观看对应的直播间 id
  String? _watchRoomId;

  /// 本次观看是否已经计入观看次数
  bool _watchCounted = false;

  /// 卡死判定阈值：播放位置多久没有推进就认为卡死
  static const Duration _stallTimeout = Duration(seconds: 20);

  /// 刚打开媒体后的宽限时间，避免刚进房间就误判
  static const Duration _openGrace = Duration(seconds: 25);

  /// 无画面判定阈值
  static const Duration _noVideoTimeout = Duration(seconds: 12);

  void initTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      var now = DateTime.now();
      datetime.value =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  /// 双击退出Flag
  bool doubleClickExit = false;

  /// 双击退出Timer
  Timer? doubleClickTimer;

  @override
  void onInit() {
    // 必须注册，否则 didChangeAppLifecycleState 根本不会被调用
    WidgetsBinding.instance.addObserver(this);
    initTimer();
    startWatchdog();
    showDanmakuState.value = AppSettingsController.instance.danmuEnable.value;
    followed.value = DBService.instance.getFollowExist("${site.id}_$roomId");

    loadData();

    super.onInit();
  }

  void refreshRoom() {
    //messages.clear();

    liveDanmaku.stop();

    loadData();
  }

  /// 初始化弹幕接收事件
  void initDanmau() {
    liveDanmaku.onMessage = onWSMessage;
  }

  /// 接收到WebSocket信息
  void onWSMessage(LiveMessage msg) {
    if (msg.type == LiveMessageType.chat) {
      // 关键词屏蔽检查
      for (var keyword in AppSettingsController.instance.shieldList) {
        Pattern? pattern;
        if (Utils.isRegexFormat(keyword)) {
          String removedSlash = Utils.removeRegexFormat(keyword);
          try {
            pattern = RegExp(removedSlash);
          } catch (e) {
            // should avoid this during add keyword
            Log.d("关键词：$keyword 正则格式错误");
          }
        } else {
          pattern = keyword;
        }
        if (pattern != null && msg.message.contains(pattern)) {
          Log.d("关键词：$keyword\n已屏蔽消息内容：${msg.message}");
          return;
        }
      }

      if (!liveStatus.value || isBackground) {
        return;
      }

      addDanmaku([
        DanmakuContentItem(
          msg.message,
          color: Color.fromARGB(255, msg.color.r, msg.color.g, msg.color.b),
        ),
      ]);
    } else if (msg.type == LiveMessageType.online) {
      online.value = msg.data;
    } else if (msg.type == LiveMessageType.superChat) {
      //superChats.add(msg.data);
    }
  }

  /// 加载直播间信息
  void loadData() async {
    try {
      SmartDialog.showLoading(msg: "");
      pageLoadding.value = true;
      detail.value = await site.liveSite.getRoomDetail(roomId: roomId);

      addHistory();
      startWatchSession();
      online.value = detail.value!.online;
      liveStatus.value = detail.value!.status || detail.value!.isRecord;
      if (liveStatus.value) {
        getPlayQualites();
      }
      if (detail.value!.isRecord) {
        SmartDialog.showToast("当前主播未开播，正在轮播录像");
      }

      initDanmau();
      liveDanmaku.start(detail.value?.danmakuData);
    } catch (e) {
      SmartDialog.showToast(e.toString());
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
      pageLoadding.value = false;
    }
  }

  /// 初始化播放器
  ///
  /// - [keepCurrentQuality] 刷新播放地址时保留用户选择的清晰度
  /// - [silent] 静默模式，失败时不弹提示（自动恢复流程中使用）
  Future<void> getPlayQualites({
    bool keepCurrentQuality = false,
    bool silent = false,
  }) async {
    // 先记下原来的清晰度，刷新播放地址时尽量保持不变
    String? keepQualityName;
    if (keepCurrentQuality &&
        currentQuality >= 0 &&
        currentQuality < qualites.length) {
      keepQualityName = qualites[currentQuality].quality;
    }

    qualites.clear();
    currentQuality = -1;

    try {
      var playQualites =
          await site.liveSite.getPlayQualites(detail: detail.value!);

      if (playQualites.isEmpty) {
        if (!silent) {
          SmartDialog.showToast("无法读取播放清晰度");
        }
        return;
      }
      qualites.value = playQualites;

      // 刷新播放地址时尽量保持原来的清晰度
      if (keepQualityName != null) {
        var index = playQualites.indexWhere((e) => e.quality == keepQualityName);
        if (index >= 0) {
          currentQuality = index;
          await getPlayUrl();
          return;
        }
      }

      var qualityLevel = AppSettingsController.instance.qualityLevel.value;
      if (qualityLevel == 2) {
        //最高
        currentQuality = 0;
      } else if (qualityLevel == 0) {
        //最低
        currentQuality = playQualites.length - 1;
      } else {
        //中间值
        int middle = (playQualites.length / 2).floor();
        currentQuality = middle;
      }

      await getPlayUrl();
    } catch (e) {
      Log.logPrint(e);
      if (!silent) {
        SmartDialog.showToast("无法读取播放清晰度");
      }
    }
  }

  Future<void> getPlayUrl() async {
    if (currentQuality < 0 || currentQuality >= qualites.length) {
      return;
    }
    playUrls.clear();
    currentQualityInfo.value = qualites[currentQuality].quality;
    currentLineInfo.value = "";
    currentLineIndex = -1;
    var playUrl = await site.liveSite
        .getPlayUrls(detail: detail.value!, quality: qualites[currentQuality]);
    if (playUrl.urls.isEmpty) {
      SmartDialog.showToast("无法读取播放地址");
      return;
    }
    playUrls.value = playUrl.urls;
    playHeaders = playUrl.headers;
    currentLineIndex = 0;
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    //重置错误次数
    mediaErrorRetryCount = 0;
    await setPlayer();
  }

  Future<void> changePlayLine(int index) async {
    if (index < 0 || index >= playUrls.length) {
      return;
    }
    currentLineIndex = index;
    //重置错误次数
    mediaErrorRetryCount = 0;
    await setPlayer();
  }

  Future<void> setPlayer() async {
    if (_isDisposing) {
      return;
    }
    if (currentLineIndex < 0 || currentLineIndex >= playUrls.length) {
      return;
    }
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    errorMsg.value = "";
    _mediaOpenedAt = DateTime.now();
    _lastPositionAt = DateTime.now();
    _lastPosition = Duration.zero;
    _positionAdvanced = false;
    _buffering = false;
    _bufferingSince = DateTime.now();
    // 重新给画面检测留出时间，避免刚打开就误判没有画面
    _videoCheckAt = DateTime.now();
    // 初始化播放器并设置 ao 参数
    await initializePlayer();
    if (_isDisposing) {
      return;
    }
    try {
      await player.open(
        Media(
          playUrls[currentLineIndex],
          httpHeaders: playHeaders,
        ),
      );
    } catch (e) {
      Log.logPrint(e);
    }

    Log.d("播放链接\r\n：${playUrls[currentLineIndex]}");
  }

  /// 重新拉取直播间信息与播放地址
  ///
  /// 直播直链（尤其是抖音、B站）都带有签名与过期时间，播放一段时间后
  /// 直链会失效，此时必须重新拉取才能继续播放，这正是「看着看着卡住不动」
  /// 的根本原因。
  Future<void> refreshPlayUrl() async {
    if (_isDisposing) {
      return;
    }
    try {
      Log.d("正在刷新播放地址");
      var newDetail = await site.liveSite.getRoomDetail(roomId: roomId);
      if (_isDisposing) {
        return;
      }
      detail.value = newDetail;
      liveStatus.value = newDetail.status || newDetail.isRecord;
      await getPlayQualites(keepCurrentQuality: true, silent: true);
    } catch (e) {
      Log.logPrint(e);
      // 刷新失败，退回使用原来的直链重连
      await setPlayer();
    }
  }

  /// 手动重试（界面上的重试按钮 / 按 OK 键）
  Future<void> retryPlay() async {
    errorMsg.value = "";
    reconnecting.value = true;
    _stallRetryCount = 0;
    _videoCheckAt = DateTime.now();
    await refreshPlayUrl();
  }

  @override
  void mediaEnd() async {
    if (_isDisposing) {
      return;
    }
    if (mediaErrorRetryCount < 2) {
      Log.d("播放结束，尝试第${mediaErrorRetryCount + 1}次刷新");
      mediaErrorRetryCount += 1;
      if (mediaErrorRetryCount == 1) {
        //第一次：使用当前直链重连
        await setPlayer();
      } else {
        //第二次：直链大概率已经失效，重新拉取
        await Future.delayed(const Duration(seconds: 1));
        await refreshPlayUrl();
      }
      return;
    }

    Log.d("播放结束");
    // 遍历线路，如果全部链接都断开就是直播结束了
    if (playUrls.length - 1 == currentLineIndex) {
      liveStatus.value = false;
    } else {
      await changePlayLine(currentLineIndex + 1);
    }
  }

  int mediaErrorRetryCount = 0;
  @override
  void mediaError(String error) async {
    if (_isDisposing) {
      return;
    }
    if (mediaErrorRetryCount < 2) {
      Log.d("播放失败，尝试第${mediaErrorRetryCount + 1}次刷新");
      mediaErrorRetryCount += 1;
      if (mediaErrorRetryCount == 1) {
        //第一次：使用当前直链重连
        await setPlayer();
      } else {
        //第二次：直链大概率已经失效，重新拉取
        await Future.delayed(const Duration(seconds: 1));
        await refreshPlayUrl();
      }
      return;
    }

    if (playUrls.length - 1 == currentLineIndex) {
      errorMsg.value = "播放失败";
      reconnecting.value = false;
      SmartDialog.showToast("播放失败:$error");
    } else {
      await changePlayLine(currentLineIndex + 1);
    }
  }

  // ---------------------------------------------------------------------------
  // 播放看门狗
  // ---------------------------------------------------------------------------

  /// 启动播放看门狗
  void startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      checkPlaybackHealth();
    });
  }

  /// 检查播放是否健康
  ///
  /// 1. 有声音但没有画面：media_kit_video 在没有解出视频轨时不会渲染画面，
  ///    表现就是黑屏但是有声音。
  /// 2. 播放卡死：直播流断流时 mpv 会停在最后一帧并且不会触发 error /
  ///    completed 事件，如果不主动检测就会一直卡住，只能退出重进。
  void checkPlaybackHealth() {
    if (_isDisposing || !liveStatus.value || isBackground) {
      return;
    }
    if (playUrls.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final state = player.state;

    // ----- 画面检测 -----
    if (hasVideoTrack) {
      _videoCheckAt = now;
    } else {
      if (now.difference(_videoCheckAt) > _noVideoTimeout) {
        _videoCheckAt = now;
        handleNoVideo();
        return;
      }
    }

    // ----- 缓冲状态检测 -----
    // 直播流断掉时 mpv 会一直停在最后一帧并保持缓冲，既不会触发 error
    // 也不会触发 completed 事件，只能靠这里主动发现。
    if (state.buffering && !_buffering) {
      _bufferingSince = now;
    } else if (!state.buffering && _buffering) {
      // 缓冲结束，说明已经恢复
      _recoverFailedCount = 0;
    }
    _buffering = state.buffering;

    // ----- 卡死检测 -----
    if (!state.playing) {
      _lastPositionAt = now;
      _lastPosition = state.position;
      return;
    }

    if (state.position != _lastPosition) {
      // 播放位置还在推进，说明是正常的
      _lastPosition = state.position;
      _lastPositionAt = now;
      _positionAdvanced = true;
      if (now.difference(_lastStallAt) > const Duration(seconds: 60)) {
        _stallRetryCount = 0;
        _recoverFailedCount = 0;
      }
      if (reconnecting.value) {
        reconnecting.value = false;
      }
      return;
    }

    // 刚打开媒体时给一段宽限时间
    if (now.difference(_mediaOpenedAt) < _openGrace) {
      return;
    }

    // 长时间缓冲：数据流已经断了
    final bufferingStalled =
        state.buffering && now.difference(_bufferingSince) > _stallTimeout;

    // 位置长时间不推进（只在位置确实推进过之后才算数，
    // 避免把没有时间戳的直播源误判成卡死）
    final positionStalled =
        _positionAdvanced && now.difference(_lastPositionAt) > _stallTimeout;

    if (!bufferingStalled && !positionStalled) {
      return;
    }

    _lastPositionAt = now;
    _lastStallAt = now;
    handleStall();
  }

  /// 处理播放卡死
  Future<void> handleStall() async {
    if (_handlingStall || _isDisposing) {
      return;
    }
    _handlingStall = true;
    reconnecting.value = true;
    try {
      _stallRetryCount += 1;
      _recoverFailedCount += 1;
      Log.d("检测到播放卡死，第$_stallRetryCount次恢复");

      // 恢复次数过多就不再自动重试了，交给用户手动重试
      if (_recoverFailedCount > 8) {
        reconnecting.value = false;
        errorMsg.value = "播放连接已断开，请按 OK 键重试";
        return;
      }

      if (_stallRetryCount <= 2) {
        SmartDialog.showToast("播放卡住了，正在重连($_stallRetryCount/3)");
        await setPlayer();
      } else {
        // 反复重连还是卡，说明直链大概率已经失效，换一条新直链
        SmartDialog.showToast("正在刷新播放地址");
        _stallRetryCount = 0;
        await refreshPlayUrl();
      }
    } catch (e) {
      Log.logPrint(e);
    } finally {
      _handlingStall = false;
    }
  }

  /// 处理「有声音没画面」
  ///
  /// 依次尝试：降低清晰度 -> 切换线路 -> 关闭硬解 -> 报错提示
  Future<void> handleNoVideo() async {
    if (_handlingNoVideo || _isDisposing) {
      return;
    }
    _handlingNoVideo = true;
    reconnecting.value = true;
    try {
      // 1. 降一档清晰度，HEVC 等编码在弱设备上常常解不出来
      if (currentQuality + 1 < qualites.length) {
        currentQuality += 1;
        currentQualityInfo.value = qualites[currentQuality].quality;
        Log.d("无画面，切换清晰度到 ${qualites[currentQuality].quality}");
        SmartDialog.showToast(
            "没有画面，正在切换到${qualites[currentQuality].quality}画质");
        mediaErrorRetryCount = 0;
        await getPlayUrl();
        _resetVideoWatch();
        return;
      }

      // 2. 换一条线路（FLV / HLS）
      if (currentLineIndex + 1 < playUrls.length) {
        Log.d("无画面，切换线路");
        SmartDialog.showToast("没有画面，正在切换线路");
        await changePlayLine(currentLineIndex + 1);
        _resetVideoWatch();
        return;
      }

      // 3. 关闭硬解，改为软解
      if (!_useSoftwareDecode) {
        _useSoftwareDecode = true;
        Log.d("无画面，尝试关闭硬件解码");
        SmartDialog.showToast("没有画面，正在尝试软件解码");
        await setSoftwareDecode();
        await setPlayer();
        _resetVideoWatch();
        return;
      }

      // 4. 都试过了，只能提示用户
      reconnecting.value = false;
      errorMsg.value = "该直播源无法显示画面（可能是纯音频直播或设备不支持该编码）";
      Log.d(errorMsg.value);
      SmartDialog.showToast(errorMsg.value);
    } catch (e) {
      Log.logPrint(e);
    } finally {
      _handlingNoVideo = false;
    }
  }

  /// 重置画面检测
  void _resetVideoWatch() {
    _videoCheckAt = DateTime.now();
    _mediaOpenedAt = DateTime.now();
    _lastPositionAt = DateTime.now();
    _lastPosition = Duration.zero;
  }

  // ---------------------------------------------------------------------------
  // 观看记录
  // ---------------------------------------------------------------------------

  /// 开始一次观看
  void startWatchSession() {
    var id = "${site.id}_$roomId";
    if (_watchRoomId == id && _watchStartAt != null) {
      // 同一直播间还在观看中，不用重新计数
      return;
    }
    _watchStartAt = DateTime.now();
    _watchRoomId = id;
    _watchCounted = false;
  }

  /// 保存本次观看的时长与次数
  Future<void> saveWatchSession() async {
    var start = _watchStartAt;
    var id = _watchRoomId;
    if (start == null || id == null) {
      return;
    }
    var duration = DateTime.now().difference(start);
    _watchStartAt = DateTime.now();
    if (duration.inSeconds < 5) {
      return;
    }
    if (!_watchCounted) {
      _watchCounted = true;
      await DBService.instance.increaseWatchCount(id);
    }
    await DBService.instance.addWatchDuration(id, duration.inMilliseconds);
    EventBus.instance.emit(Constant.kUpdateHistory, id);
  }

  /// 添加历史记录
  void addHistory() {
    if (detail.value == null) {
      return;
    }
    var id = "${site.id}_$roomId";
    var history = DBService.instance.getHistory(id);
    if (history != null) {
      history.updateTime = DateTime.now();
    }
    history ??= History(
      id: id,
      roomId: roomId,
      siteId: site.id,
      userName: detail.value?.userName ?? "",
      face: detail.value?.userAvatar ?? "",
      updateTime: DateTime.now(),
    );

    DBService.instance.addOrUpdateHistory(history);
  }

  /// 关注用户
  void followUser() {
    if (detail.value == null) {
      return;
    }
    var id = "${site.id}_$roomId";
    DBService.instance.addFollow(
      FollowUser(
        id: id,
        roomId: roomId,
        siteId: site.id,
        userName: detail.value?.userName ?? "",
        face: detail.value?.userAvatar ?? "",
        addTime: DateTime.now(),
      ),
    );
    followed.value = true;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
    SmartDialog.showToast("已关注");
  }

  /// 取消关注用户
  void removeFollowUser() async {
    if (detail.value == null) {
      return;
    }
    // if (!await Utils.showAlertDialog("确定要取消关注该用户吗？", title: "取消关注")) {
    //   return;
    // }

    var id = "${site.id}_$roomId";
    DBService.instance.deleteFollow(id);
    followed.value = false;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
    SmartDialog.showToast("已取消关注");
  }

  void resetRoom(Site site, String roomId) async {
    if (this.site == site && this.roomId == roomId) {
      return;
    }

    // 先把上一个直播间的观看记录存下来
    await saveWatchSession();

    rxSite.value = site;
    rxRoomId.value = roomId;

    // 清除全部消息
    liveDanmaku.stop();

    danmakuController?.clear();

    // 重新设置LiveDanmaku
    liveDanmaku = site.liveSite.getDanmaku();

    // 停止播放
    await player.stop();

    // 刷新信息
    loadData();
  }

  void nextChannel() {
    //读取正在直播的频道
    var liveChannels = FollowUserService.instance.livingList;
    if (liveChannels.isEmpty) {
      SmartDialog.showToast("没有正在直播的频道");
      return;
    }
    var index = liveChannels
        .indexWhere((element) => element.id == "${site.id}_$roomId");
    // if (index == -1) {
    //   //当前频道不在列表中

    //   return;
    // }
    index += 1;
    if (index >= liveChannels.length) {
      index = 0;
    }
    var nextChannel = liveChannels[index];

    resetRoom(Sites.allSites[nextChannel.siteId]!, nextChannel.roomId);
  }

  void prevChannel() {
    //读取正在直播的频道
    var liveChannels = FollowUserService.instance.livingList;
    if (liveChannels.isEmpty) {
      SmartDialog.showToast("没有正在直播的频道");
      return;
    }
    var index = liveChannels
        .indexWhere((element) => element.id == "${site.id}_$roomId");
    // if (index == -1) {
    //   //当前频道不在列表中

    //   return;
    // }
    index -= 1;
    if (index < 0) {
      index = liveChannels.length - 1;
    }
    var nextChannel = liveChannels[index];

    resetRoom(Sites.allSites[nextChannel.siteId]!, nextChannel.roomId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      Log.d("进入后台");
      //进入后台，关闭弹幕
      danmakuController?.clear();
      isBackground = true;
      saveWatchSession();
    } else
    //返回前台
    if (state == AppLifecycleState.resumed) {
      Log.d("返回前台");
      isBackground = false;
      //回到前台后重新检查一次播放状态
      _resetVideoWatch();
    }
  }

  @override
  void onClose() {
    _isDisposing = true;
    _clockTimer?.cancel();
    _watchdogTimer?.cancel();
    doubleClickTimer?.cancel();
    saveWatchSession();
    liveDanmaku.stop();

    danmakuController = null;
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
