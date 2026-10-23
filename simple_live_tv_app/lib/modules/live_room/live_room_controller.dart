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

/// 播放阶段
///
/// 界面只认这一个状态, 不再由各个地方分别去写"正在恢复"和"错误文案",
/// 避免出现"黑屏 + 没有任何提示"这种状态。
enum PlaybackPhase {
  /// 还没开始
  idle,

  /// 正在连接第一路流
  connecting,

  /// 正常播放
  playing,

  /// 自动恢复中(卡死重连 / 无画面自愈 / 换直链)
  recovering,

  /// 恢复失败, 等用户按 OK 重试
  failed,
}

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

  /// 播放阶段, 界面只读这一个
  final phase = PlaybackPhase.idle.obs;

  /// 失败原因, 只有 phase == failed 时有意义
  final failReason = "".obs;

  /// 这次失败按 OK 键重试还有没有意义
  ///
  /// 有些失败重试也没用, 比如这个直播源本身就放不出画面。
  /// 这时候还提示"按 OK 键重试"是在骗用户。
  bool _canRetry = true;

  bool get canRetry => _canRetry;

  // ---------------------------------------------------------------------------
  // 恢复流程: 单一入口 + 世代号
  //
  // 多个地方(看门狗 / 播放器错误 / 手动重试)都可能触发恢复, 用世代号保证
  // 后触发的恢复能作废先触发的恢复, 避免两条流程交叉改状态。
  // ---------------------------------------------------------------------------

  /// 恢复世代号, 每次开始恢复 +1
  int _recoveryEpoch = 0;

  /// 世代号是否仍然有效
  bool _isCurrentEpoch(int epoch) => epoch == _recoveryEpoch;

  /// 计时器
  Timer? _clockTimer;

  /// 播放看门狗
  Timer? _watchdogTimer;

  /// 上一次播放位置发生变化的时间
  DateTime _lastPositionAt = DateTime.now();

  /// 上一次记录的播放位置
  Duration _lastPosition = Duration.zero;

  /// 本次打开媒体的时间, 刚打开时留宽限时间
  DateTime _mediaOpenedAt = DateTime.now();

  /// 开始检测画面的时间
  DateTime _videoCheckAt = DateTime.now();

  /// 播放器进入缓冲状态的时间
  DateTime _bufferingSince = DateTime.now();

  /// 上一次的缓冲状态
  bool _buffering = false;

  /// 本次打开媒体后播放位置是否推进过
  ///
  /// 部分直播源没有时间戳, position 会一直是 0, 这种情况不能当成卡死。
  bool _positionAdvanced = false;

  /// 连续卡死次数
  int _stallRetryCount = 0;

  /// 连续恢复失败次数
  ///
  /// 断流重连的升级计数。刷新播放地址时**不能**重置它,
  /// 否则"一打开就 EOF"的流会永远重连下去, 停在"正在恢复播放"。
  ///
  /// 只在"这条流连续健康够一段时间"时才清零。解出视频轨不算健康:
  /// 断掉的流一样有视频轨, 拿它当恢复成功的信号, 上限永远触发不了。
  int _failCount = 0;

  /// 本次播放连续健康的起点
  ///
  /// 位置持续推进才叫健康。刚开始推进时记下时间,
  /// 连续健康满 [_healthyWindow] 才把 [_failCount] 清零。
  DateTime? _healthySince;

  /// 判定为"真的好了"需要连续健康多久
  static const Duration _healthyWindow = Duration(seconds: 10);

  /// 上一次累计观看时长时的播放位置
  Duration _lastWatchedPosition = Duration.zero;

  /// 是否已经退回软件解码
  bool _useSoftwareDecode = false;

  /// 是否正在销毁
  bool _isDisposing = false;

  /// 是否正在换房间
  ///
  /// 换房间的时候看门狗要停一下: 旧房间的直链还在手上,
  /// 看门狗一不留神就把刚退掉的房间又打开了。
  bool _isSwitchingRoom = false;

  /// 本次观看的开始时间
  DateTime? _watchStartAt;

  /// 本次观看对应的直播间 id
  String? _watchRoomId;

  /// 本次观看是否已经计入观看次数
  bool _watchCounted = false;

  /// 本次观看真正在播放的时长（毫秒）
  ///
  /// 只在播放器正常推进时累加。卡住、缓冲、切后台的时间都不算,
  /// 否则后台挂机几小时会把平台的观看时长榜单带偏。
  int _watchedMs = 0;

  /// 卡死判定阈值: 播放位置多久没有推进就认为卡死
  static const Duration _stallTimeout = Duration(seconds: 20);

  /// 连续恢复失败多少次就停下来, 交给用户按 OK 重试
  static const int _maxRecoverCount = 3;

  /// 刚打开媒体后的宽限时间, 给解码器留出首帧时间
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
    // 必须注册, 否则 didChangeAppLifecycleState 根本不会被调用
    WidgetsBinding.instance.addObserver(this);
    initTimer();
    startWatchdog();
    showDanmakuState.value = AppSettingsController.instance.danmuEnable.value;
    followed.value = DBService.instance.getFollowExist("${site.id}_$roomId");
    // 播放期间别去刷关注状态, 免得跟解码器抢网络和 CPU
    FollowUserService.instance.pauseTimer();

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
  Future<void> loadData() async {
    try {
      SmartDialog.showLoading(msg: "");
      pageLoadding.value = true;
      detail.value = await site.liveSite.getRoomDetail(roomId: roomId);

      addHistory();
      startWatchSession();
      online.value = detail.value!.online;
      liveStatus.value = detail.value!.status || detail.value!.isRecord;
      if (liveStatus.value) {
        _setPhase(PlaybackPhase.connecting);
        _failCount = 0;
        var ok = await getPlayQualites();
        if (!ok && phase.value == PlaybackPhase.connecting) {
          // 取不到播放地址就一直停在"连接中", 界面又没有任何提示,
          // 等于又回到"只能退出重进"的老问题
          _setPhase(PlaybackPhase.failed, reason: "无法读取播放地址");
        }
      } else {
        _setPhase(PlaybackPhase.idle);
      }
      if (detail.value!.isRecord) {
        SmartDialog.showToast("当前主播未开播，正在轮播录像");
      }

      initDanmau();
      liveDanmaku.start(detail.value?.danmakuData);
    } catch (e) {
      SmartDialog.showToast(e.toString());
      _setPhase(PlaybackPhase.failed, reason: e.toString());
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
      pageLoadding.value = false;
    }
  }

  /// 设置播放阶段
  void _setPhase(PlaybackPhase value, {String reason = ""}) {
    phase.value = value;
    failReason.value = value == PlaybackPhase.failed ? reason : "";
  }

  /// 开始一次恢复, 返回世代号
  int _startRecovery() {
    _recoveryEpoch++;
    // 新的恢复流程从头算健康度
    _healthySince = null;
    _setPhase(PlaybackPhase.recovering);
    return _recoveryEpoch;
  }

  /// 恢复结束
  void _finishRecovery(int epoch, {String reason = ""}) {
    if (!_isCurrentEpoch(epoch)) {
      return;
    }
    if (reason.isEmpty) {
      _setPhase(PlaybackPhase.playing);
    } else {
      _setPhase(PlaybackPhase.failed, reason: reason);
    }
  }

  /// 初始化播放器
  ///
  /// - [keepCurrentQuality] 刷新播放地址时保留用户选择的清晰度
  /// - [silent] 静默模式, 失败时不弹提示(自动恢复流程中使用)
  Future<bool> getPlayQualites({
    bool keepCurrentQuality = false,
    bool silent = false,
    int? epoch,
  }) async {
    // 先记下原来的清晰度, 刷新播放地址时尽量保持不变
    String? keepQualityName;
    if (keepCurrentQuality &&
        currentQuality >= 0 &&
        currentQuality < qualites.length) {
      keepQualityName = qualites[currentQuality].quality;
    }

    try {
      var playQualites =
          await site.liveSite.getPlayQualites(detail: detail.value!);

      if (playQualites.isEmpty) {
        if (!silent) {
          SmartDialog.showToast("无法读取播放清晰度");
        }
        return false;
      }
      qualites.value = playQualites;

      // 刷新播放地址时尽量保持原来的清晰度
      if (keepQualityName != null) {
        var index =
            playQualites.indexWhere((e) => e.quality == keepQualityName);
        if (index >= 0) {
          currentQuality = index;
          return await getPlayUrl(epoch: epoch);
        }
      }

      currentQuality = _defaultQualityIndex(playQualites.length);
      return await getPlayUrl(epoch: epoch);
    } catch (e) {
      Log.logPrint(e);
      if (!silent) {
        SmartDialog.showToast("无法读取播放清晰度");
      }
      return false;
    }
  }

  /// 按设置选默认清晰度
  int _defaultQualityIndex(int count) {
    if (count <= 0) {
      return -1;
    }
    var qualityLevel = AppSettingsController.instance.qualityLevel.value;
    if (qualityLevel == 2) {
      //最高
      return 0;
    }
    if (qualityLevel == 0) {
      //最低
      return count - 1;
    }
    //中间值
    return (count / 2).floor();
  }

  /// 取播放地址并打开
  ///
  /// 返回 false 表示没拿到可用地址。传入 [epoch] 时, 期间如果被更新的恢复
  /// 取代了, 这里直接放弃, 不会把旧地址写回去。
  Future<bool> getPlayUrl({int? epoch, bool silent = false}) async {
    if (currentQuality < 0 || currentQuality >= qualites.length) {
      return false;
    }
    var quality = qualites[currentQuality];
    var playUrl = await site.liveSite
        .getPlayUrls(detail: detail.value!, quality: quality);
    if (epoch != null && !_isCurrentEpoch(epoch)) {
      return false;
    }
    if (playUrl.urls.isEmpty) {
      if (!silent) {
        SmartDialog.showToast("无法读取播放地址");
      }
      return false;
    }
    // 拿到新直链之前不动旧的, 避免中途把播放器架空
    playUrls.value = List<String>.from(playUrl.urls);
    playHeaders = playUrl.headers;
    currentLineIndex = 0;
    currentQualityInfo.value = quality.quality;
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    await setPlayer(epoch: epoch);
    return true;
  }

  Future<void> changePlayLine(int index, {int? epoch}) async {
    if (index < 0 || index >= playUrls.length) {
      return;
    }
    currentLineIndex = index;
    await setPlayer(epoch: epoch);
  }

  /// 打开当前线路的直链
  Future<void> setPlayer({int? epoch}) async {
    if (_isDisposing) {
      return;
    }
    if (currentLineIndex < 0 || currentLineIndex >= playUrls.length) {
      return;
    }
    // 先把地址取出来, await 之后不再读 playUrls, 避免并发时越界
    final url = playUrls[currentLineIndex];
    final headers = playHeaders;
    _mediaOpenedAt = DateTime.now();
    _lastPositionAt = DateTime.now();
    _lastPosition = Duration.zero;
    _positionAdvanced = false;
    _buffering = false;
    _bufferingSince = DateTime.now();
    // 重新给画面检测留出时间, 避免刚打开就误判没有画面
    _videoCheckAt = DateTime.now();
    // 初始化播放器并设置 ao 参数
    await initializePlayer();
    if (_isDisposing) {
      return;
    }
    // 打开前再确认一次: 免得被作废的恢复流程把旧地址又打开一遍
    if (epoch != null && !_isCurrentEpoch(epoch)) {
      return;
    }
    try {
      await player.open(Media(url, httpHeaders: headers));
    } catch (e) {
      Log.logPrint(e);
    }

    Log.d("播放链接\r\n：$url");
  }

  /// 手动切换清晰度
  ///
  /// 走一遍恢复流程, 免得手动切换和在飞的刷新流程互相覆盖:
  /// 老流程会把用户选的清晰度又改回自己那份。
  Future<void> switchQuality(int index) async {
    if (index < 0 || index >= qualites.length) {
      return;
    }
    final epoch = _startRecovery();
    currentQuality = index;
    var ok = await getPlayUrl(epoch: epoch);
    if (!_isCurrentEpoch(epoch)) {
      return;
    }
    if (!ok) {
      _finishRecovery(epoch, reason: "无法读取播放地址");
    }
  }

  /// 手动切换线路
  Future<void> switchLine(int index) async {
    if (index < 0 || index >= playUrls.length) {
      return;
    }
    final epoch = _startRecovery();
    await changePlayLine(index, epoch: epoch);
  }

  /// 重新拉取直播间信息与播放地址
  ///
  /// 直播直链(尤其是抖音、B站)都带有签名与过期时间, 播放一段时间后
  /// 直链会失效, 必须重新拉取才能继续播放, 这正是「看着看着卡住不动」
  /// 的根本原因。
  Future<void> refreshPlayUrl() async {
    final epoch = _startRecovery();
    await _refreshPlayUrlInner(epoch);
  }

  /// 刷新播放地址的具体流程, 每一次 await 之后都检查世代号
  Future<void> _refreshPlayUrlInner(int epoch) async {
    try {
      Log.d("正在刷新播放地址");
      var newDetail = await site.liveSite.getRoomDetail(roomId: roomId);
      if (!_isCurrentEpoch(epoch)) {
        return;
      }
      detail.value = newDetail;
      var isLive = newDetail.status || newDetail.isRecord;
      liveStatus.value = isLive;
      if (!isLive) {
        // 主播确实下播了, 不是直链过期
        _finishRecovery(epoch);
        _setPhase(PlaybackPhase.idle);
        return;
      }

      var qualities = await site.liveSite.getPlayQualites(detail: newDetail);
      if (!_isCurrentEpoch(epoch)) {
        return;
      }
      if (qualities.isEmpty) {
        _finishRecovery(epoch, reason: "无法读取播放清晰度");
        return;
      }
      qualites.value = qualities;

      // 尽量保持当前清晰度
      var index = -1;
      if (currentQuality >= 0 && currentQuality < qualities.length) {
        index = currentQuality;
      } else {
        index = _defaultQualityIndex(qualities.length);
      }
      currentQuality = index;

      var url = await site.liveSite.getPlayUrls(
        detail: newDetail,
        quality: qualities[index],
      );
      if (!_isCurrentEpoch(epoch)) {
        return;
      }
      if (url.urls.isEmpty) {
        _finishRecovery(epoch, reason: "无法读取播放地址");
        return;
      }

      // 新直链到手了才替换, 旧的还能继续播
      playUrls.value = List<String>.from(url.urls);
      playHeaders = url.headers;
      currentLineIndex = 0;
      currentQualityInfo.value = qualities[index].quality;
      currentLineInfo.value = "线路${currentLineIndex + 1}";
      await setPlayer(epoch: epoch);
      if (!_isCurrentEpoch(epoch)) {
        return;
      }
      // 这里不判成 playing: 新直链刚交给播放器, 画面还没出来。
      // 判了就只剩一片黑屏, 让看门狗在真的播起来的时候再切回正常。
    } catch (e) {
      Log.logPrint(e);
      if (_isCurrentEpoch(epoch)) {
        _finishRecovery(epoch, reason: "播放地址刷新失败");
      }
    }
  }

  /// 手动重试(界面上的重试按钮 / 按 OK 键)
  Future<void> retryPlay() async {
    _stallRetryCount = 0;
    _failCount = 0;
    _canRetry = true;
    _videoCheckAt = DateTime.now();
    await refreshPlayUrl();
  }

  /// 断流后的恢复: 先用现有直链重连, 再换一条新直链
  Future<void> _recoverStream() async {
    final epoch = _startRecovery();
    try {
      _failCount += 1;
      if (_failCount > _maxRecoverCount) {
        // 一直连不上就别自己跟自己较劲, 让用户按 OK 重试。
        // 一打开就 EOF 的流如果没这个上限, 会永远重连下去。
        // 但先确认主播是不是下播了, 别把"下播"说成"连接断开"。
        if (!await _isHostStillLive()) {
          liveStatus.value = false;
          _finishRecovery(epoch);
          _setPhase(PlaybackPhase.idle);
          return;
        }
        _finishRecovery(epoch, reason: "播放连接已断开");
        return;
      }
      if (_failCount <= 2) {
        // 先用当前直链重连
        await setPlayer(epoch: epoch);
        return;
      }
      // 直链大概率已经过期, 换一条新的
      await Future.delayed(const Duration(seconds: 1));
      if (!_isCurrentEpoch(epoch)) {
        return;
      }
      await _refreshPlayUrlInner(epoch);
    } catch (e) {
      Log.logPrint(e);
      _finishRecovery(epoch, reason: "播放失败");
    }
  }

  /// 主播是不是还在播
  ///
  /// 用来区分"流断了"和"主播下播了"。下播应该回到"未开播",
  /// 而不是让用户按 OK 去重试一个永远不会成功的地址。
  Future<bool> _isHostStillLive() async {
    try {
      var detail = await site.liveSite.getRoomDetail(roomId: roomId);
      return detail.status || detail.isRecord;
    } catch (e) {
      Log.logPrint(e);
      // 查不到就当还在播, 让用户自己决定要不要重试
      return true;
    }
  }

  @override
  void mediaEnd() async {
    if (_isDisposing) {
      return;
    }
    Log.d("播放结束");
    // 直播直链到期也会走到这里, 不能当成"主播下播"。
    // 先换线路, 都不行就拉一条新直链, 由房间信息决定是不是真的下播。
    if (currentLineIndex + 1 < playUrls.length) {
      // 换线路也要走世代号, 不然在飞的恢复流程会把旧直链又打开一遍
      final epoch = _startRecovery();
      await changePlayLine(currentLineIndex + 1, epoch: epoch);
      // 不在这里判成 playing: 新线路还没播起来, 判了就只剩一片黑屏,
      // 让看门狗在真的播起来的时候再切回正常
      return;
    }
    await _recoverStream();
  }

  @override
  void mediaError(String error) async {
    if (_isDisposing) {
      return;
    }
    Log.d("播放失败：$error");
    await _recoverStream();
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
  /// 1. 有声音但没有画面: media_kit_video 在没有解出视频轨时不会渲染画面,
  ///    表现就是黑屏但是有声音。
  /// 2. 播放卡死: 直播流断流时 mpv 会停在最后一帧并且不会触发 error /
  ///    completed 事件, 如果不主动检测就会一直卡住, 只能退出重进。
  void checkPlaybackHealth() {
    if (_isDisposing ||
        !liveStatus.value ||
        isBackground ||
        _isSwitchingRoom) {
      return;
    }
    if (playUrls.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final state = player.state;
    final sinceOpen = now.difference(_mediaOpenedAt);
    final isPlaying = state.playing && !state.buffering;

    // 观看时长按播放器真正推进的毫秒算, 不按墙钟算。
    // 放在宽限期前面, 否则每次打开媒体的头 25 秒都不计入,
    // 恢复越频繁漏得越多。
    if (isPlaying) {
      final delta = state.position - _lastWatchedPosition;
      // 一次看门狗只走一秒, 位移明显更大说明是拖动进度之类的跳变, 不计入
      if (delta > Duration.zero && delta < const Duration(seconds: 5)) {
        _watchedMs += delta.inMilliseconds;
      }
      _lastWatchedPosition = state.position;
    }

    // ----- 健康判定 -----
    // 只有位置持续推进才叫健康。解出视频轨不算: 断掉的流一样有视频轨,
    // 拿它当"恢复成功"的信号, 失败计数每次都会被清零, 上限形同虚设。
    var positionAdvanced = false;
    if (state.playing) {
      if (state.position != _lastPosition) {
        positionAdvanced = true;
        _lastPosition = state.position;
        _lastPositionAt = now;
        _positionAdvanced = true;
        _healthySince ??= now;
        // 连续健康够一段时间才算真的好了, 位置动一下不算
        if (now.difference(_healthySince!) >= _healthyWindow) {
          _failCount = 0;
          _stallRetryCount = 0;
          _healthySince = now;
        }
      }
    } else {
      _lastPositionAt = now;
      _lastPosition = state.position;
      _healthySince = null;
    }

    // 界面从"正在恢复"切回正常, 只能凭"真的在播"。
    // 之前拿"解出视频轨"当信号, 一打开就 EOF 的流也会被判成已恢复,
    // 界面看着正常其实黑屏, 用户只能退出重进。
    if (isPlaying &&
        (phase.value == PlaybackPhase.recovering ||
            phase.value == PlaybackPhase.connecting)) {
      _setPhase(PlaybackPhase.playing);
    }

    // 刚打开媒体时给一段宽限时间, 慢设备上首帧可能要十几秒
    if (sinceOpen < _openGrace) {
      return;
    }

    // ----- 画面检测 -----
    if (hasVideoTrack) {
      _videoCheckAt = now;
    } else if (now.difference(_videoCheckAt) > _noVideoTimeout) {
      _videoCheckAt = now;
      handleNoVideo();
      return;
    }

    // ----- 缓冲状态检测 -----
    // 直播流断掉时 mpv 会一直停在最后一帧并保持缓冲, 既不触发 error
    // 也不会触发 completed 事件, 只能靠这里主动发现。
    if (state.buffering && !_buffering) {
      _bufferingSince = now;
    }
    _buffering = state.buffering;

    // ----- 卡死检测 -----
    if (!state.playing || positionAdvanced) {
      return;
    }

    // 长时间缓冲: 数据流已经断了
    final bufferingStalled =
        state.buffering && now.difference(_bufferingSince) > _stallTimeout;

    // 位置长时间不推进(只在位置确实推进过之后才算数,
    // 避免把没有时间戳的直播源误判成卡死)
    final positionStalled =
        _positionAdvanced && now.difference(_lastPositionAt) > _stallTimeout;

    if (!bufferingStalled && !positionStalled) {
      return;
    }

    _lastPositionAt = now;
    handleStall();
  }

  /// 处理播放卡死
  Future<void> handleStall() async {
    if (_isDisposing) {
      return;
    }
    _stallRetryCount += 1;
    Log.d("检测到播放卡死，第$_stallRetryCount次恢复");

    if (_stallRetryCount <= 2) {
      SmartDialog.showToast("播放卡住了，正在重连($_stallRetryCount/3)");
      await _recoverStream();
    } else {
      // 反复重连还是卡, 说明直链大概率已经失效, 换一条新直链
      SmartDialog.showToast("正在刷新播放地址");
      _stallRetryCount = 0;
      await refreshPlayUrl();
    }
  }

  /// 处理「有声音没画面」
  ///
  /// 依次尝试: 降低清晰度 -> 切换线路 -> 关闭硬解 -> 明确报错
  ///
  /// 每一步之后**不**把阶段判成 playing。判成 playing 之后界面就不再提示,
  /// 可这时画面还是黑的, 用户只看到一片黑屏, 只能退出重进。
  /// 保持"正在恢复", 让看门狗在真的播起来的时候再切回正常。
  Future<void> handleNoVideo() async {
    if (_isDisposing) {
      return;
    }
    final epoch = _startRecovery();
    try {
      // 1. 降一档清晰度, HEVC 等编码在弱设备上常常解不出来
      if (currentQuality + 1 < qualites.length) {
        currentQuality += 1;
        currentQualityInfo.value = qualites[currentQuality].quality;
        Log.d("无画面，切换清晰度到 ${qualites[currentQuality].quality}");
        SmartDialog.showToast(
            "没有画面，正在切换到${qualites[currentQuality].quality}画质");
        var ok = await getPlayUrl(epoch: epoch, silent: true);
        if (!_isCurrentEpoch(epoch)) {
          return;
        }
        if (!ok) {
          _finishRecovery(epoch, reason: "无法读取播放地址");
          return;
        }
        return;
      }

      // 2. 换一条线路(FLV / HLS)
      if (currentLineIndex + 1 < playUrls.length) {
        Log.d("无画面，切换线路");
        SmartDialog.showToast("没有画面，正在切换线路");
        await changePlayLine(currentLineIndex + 1, epoch: epoch);
        if (!_isCurrentEpoch(epoch)) {
          return;
        }
        return;
      }

      // 3. 关闭硬解, 改为软解
      if (!_useSoftwareDecode) {
        _useSoftwareDecode = true;
        Log.d("无画面，尝试关闭硬件解码");
        SmartDialog.showToast("没有画面，正在尝试软件解码");
        await setSoftwareDecode();
        await setPlayer(epoch: epoch);
        if (!_isCurrentEpoch(epoch)) {
          return;
        }
        return;
      }

      // 4. 都试过了, 只能提示用户
      _finishRecovery(
        epoch,
        reason: "该直播源无法显示画面（可能是纯音频直播或设备不支持该编码）",
      );
      // 这个源再怎么试都放不出画面, 别再让用户白按 OK
      _canRetry = false;
    } catch (e) {
      Log.logPrint(e);
      _finishRecovery(epoch, reason: "画面恢复失败");
    }
  }

  // ---------------------------------------------------------------------------
  // 观看记录
  // ---------------------------------------------------------------------------

  /// 开始一次观看
  void startWatchSession() {
    var id = "${site.id}_$roomId";
    if (_watchRoomId == id && _watchStartAt != null) {
      // 同一直播间还在观看中, 不用重新计数
      return;
    }
    _watchStartAt = DateTime.now();
    _watchRoomId = id;
    _watchCounted = false;
    _watchedMs = 0;
  }

  /// 保存本次观看的时长与次数
  ///
  /// [force] 为 true 时不足 5 秒也记, 换房间时用:
  /// 不然那几秒会被下一段计时直接冲掉。
  Future<void> saveWatchSession({bool force = false}) async {
    var id = _watchRoomId;
    if (id == null) {
      return;
    }
    var durationMs = _watchedMs;
    if (durationMs <= 0) {
      return;
    }
    if (durationMs < 5000 && !force) {
      // 不够 5 秒就不记, 已经累计的时间先留着
      return;
    }
    _watchedMs = 0;
    if (!_watchCounted) {
      _watchCounted = true;
      await DBService.instance.increaseWatchCount(id);
    }
    await DBService.instance.addWatchDuration(id, durationMs);
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
      history.cover = detail.value?.cover ?? history.cover;
    }
    history ??= History(
      id: id,
      roomId: roomId,
      siteId: site.id,
      userName: detail.value?.userName ?? "",
      face: detail.value?.userAvatar ?? "",
      cover: detail.value?.cover ?? "",
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

    // 让在飞的恢复流程全部作废, 不然它会把上一个房间的数据写回来,
    // 顶掉刚切过去的房间
    _recoveryEpoch++;
    // 换房间期间看门狗要停一下: 旧直链还在手上,
    // 看门狗一不留神就把刚退掉的房间又打开了
    _isSwitchingRoom = true;

    try {
      // 先把上一个直播间的观看记录存下来, 不足 5 秒也存,
      // 不然那几秒会被下一段计时直接冲掉
      await saveWatchSession(force: true);

      rxSite.value = site;
      rxRoomId.value = roomId;
      // 立刻开始新房间的观看计时, 别把上一个房间的时间算到新房间头上
      startWatchSession();

      // 清除全部消息
      liveDanmaku.stop();

      danmakuController?.clear();

      // 重新设置LiveDanmaku
      liveDanmaku = site.liveSite.getDanmaku();

      // 软解是上一个房间为了救画面临时降下来的, 换房间要恢复回去,
      // 不然弱机上会一直软解, 卡顿反而更厉害
      if (_useSoftwareDecode) {
        _useSoftwareDecode = false;
        await resetDecodeMode();
      }

      // 旧房间的直链不能留, 看门狗可能拿着它把旧房间又打开一遍
      playUrls.clear();

      // 停止播放
      await player.stop();

      // 刷新信息
      await loadData();
    } finally {
      _isSwitchingRoom = false;
    }
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
      _videoCheckAt = DateTime.now();
      _mediaOpenedAt = DateTime.now();
    }
  }

  @override
  void onClose() {
    _isDisposing = true;
    _clockTimer?.cancel();
    _watchdogTimer?.cancel();
    doubleClickTimer?.cancel();
    saveWatchSession();
    // 退出直播间后把关注状态的自动更新恢复回来
    FollowUserService.instance.initTimer();
    liveDanmaku.stop();

    // 先把没画完的弹幕清掉再断开, 顺序反了这条弹幕就永远留在画布上
    danmakuController?.clear();
    danmakuController = null;
    focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
