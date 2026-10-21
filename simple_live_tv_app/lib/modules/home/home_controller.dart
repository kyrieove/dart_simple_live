import 'dart:async';

import 'package:get/get.dart';

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
    super.onClose();
  }
}
