import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/event_bus.dart';
import 'package:simple_live_tv_app/models/db/history.dart';
import 'package:simple_live_tv_app/routes/route_path.dart';
import 'package:simple_live_tv_app/services/db_service.dart';

class HomeController extends BaseController {
  var datetime = "00:00".obs;

  /// 最近观看的直播间
  var recentHistory = <History>[].obs;

  StreamSubscription<dynamic>? _historySubscription;

  /// 卡片的焦点节点, 按房间 id 复用
  ///
  /// 放在 build 里 new 的话, 列表每重建一次就漏一个焦点节点。
  final Map<String, AppFocusNode> _cardFocusNodes = {};

  AppFocusNode focusNodeFor(String id) =>
      _cardFocusNodes.putIfAbsent(id, () => AppFocusNode());

  /// 左侧导航的焦点节点
  ///
  /// 预先建好, 首帧后主动把焦点交给第一个入口。
  /// 靠 Focus 的 autofocus 不稳: 桌面一行里还有别的可聚焦控件时,
  /// 遥控器一按 OK 可能落到"设置"上, 而不是最常用的"热门直播"。
  final List<AppFocusNode> navFocusNodes =
      List.generate(5, (_) => AppFocusNode());

  /// 顶栏"设置"按钮的焦点节点
  ///
  /// 放在 build 里新建的话, 每次重建都会换一个新的节点,
  /// 焦点刚落到按钮上就丢了。
  final settingsFocusNode = AppFocusNode();

  /// 英雄卡的焦点节点
  ///
  /// 英雄卡显示的是最近看的那个房间, 列表一刷新换的人就变了。
  /// 节点跟着房间走的话, 用户从直播间退回来焦点就丢了。
  final heroFocusNode = AppFocusNode();

  /// 空状态里"同步数据"按钮的焦点节点
  final syncFocusNode = AppFocusNode();

  /// 关注管理弹窗里"返回"按钮的焦点节点
  final manageBackFocusNode = AppFocusNode();

  /// 搜索弹窗的输入框
  ///
  /// 放在控制器里而不是弹窗里: 每次开弹窗都 new 一个 TextEditingController
  /// 和两个焦点节点, 用完没人释放。
  final searchTextController = TextEditingController();
  final searchRoomFocusNode = AppFocusNode();
  final searchAnchorFocusNode = AppFocusNode();

  Timer? _clockTimer;

  @override
  void onInit() {
    initTimer();
    loadRecentHistory();
    _historySubscription = EventBus.instance.listen(
      Constant.kUpdateHistory,
      (_) {
        loadRecentHistory();
      },
    );
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    // 首帧之后焦点才挂上, 这时候再要
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navFocusNodes.isNotEmpty) {
        navFocusNodes.first.requestFocus();
      }
    });
  }

  void initTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      var now = DateTime.now();
      datetime.value =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  /// 读取最近的观看记录
  void loadRecentHistory() {
    var list = DBService.instance.getHistores();
    recentHistory.value = list.take(6).toList();
  }

  void toSync() {
    Get.toNamed(RoutePath.kSync);
  }

  void toFollow() {
    Get.toNamed(RoutePath.kFollow);
  }

  void toSettings() {
    Get.toNamed(RoutePath.kSettings);
  }

  void toHistory() {
    Get.toNamed(RoutePath.kHistory);
  }

  void toHotLive() {
    Get.toNamed(RoutePath.kHotLive);
  }

  void toSearchRoom(String keyword) {
    Get.toNamed(RoutePath.kSearchRoom, arguments: keyword);
  }

  void toSearchAnchor(String keyword) {
    Get.toNamed(RoutePath.kSearchAnchor, arguments: keyword);
  }

  void toCategory() {
    Get.toNamed(RoutePath.kCategory);
  }

  @override
  void onClose() {
    _clockTimer?.cancel();
    _historySubscription?.cancel();
    for (var node in _cardFocusNodes.values) {
      node.dispose();
    }
    _cardFocusNodes.clear();
    for (var node in navFocusNodes) {
      node.dispose();
    }
    settingsFocusNode.dispose();
    heroFocusNode.dispose();
    syncFocusNode.dispose();
    manageBackFocusNode.dispose();
    searchTextController.dispose();
    searchRoomFocusNode.dispose();
    searchAnchorFocusNode.dispose();
    super.onClose();
  }
}
