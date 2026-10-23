import 'dart:async';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/services/db_service.dart';

class HotliveController extends BasePageController<LiveRoomItemExt> {
  var siteId = Constant.kBiliBili.obs;
  var site = Sites.allSites[Constant.kBiliBili]!;

  /// 平台给的原始顺序
  ///
  /// 排序会把顺序打乱, 关掉"按观看习惯排序"时要靠它还原, 所以单独留一份。
  final List<LiveRoomItemExt> _platformOrder = [];

  /// 数据代次
  ///
  /// 重新拉数据时自增。在途的请求回来时代次已经变了, 结果直接丢掉,
  /// 不然上一个平台的房间会串进新平台的列表。
  int _loadGeneration = 0;

  /// 正在跑的加载
  Future<dynamic>? _pendingLoad;

  /// 平台累计观看时长
  ///
  /// orderedSites 会被页面里的 Obx 反复调用, 每次都扫一遍历史记录太浪费。
  /// 算一次存着, 历史记录变了再重新算。
  Map<String, int>? _siteDurationCache;

  StreamSubscription<dynamic>? _historySubscription;

  @override
  void onInit() {
    scrollController.addListener(scrollListener);
    // 观看记录变了, 平台的顺序和房间的顺序都要重算。
    // 直接听 hive 的变化, 观看记录不管从哪儿改的都能收到。
    _historySubscription = DBService.instance.historyBox.watch().listen((_) {
      _siteDurationCache = null;
      applySortOrder();
    });
    // 默认打开看得最多的平台
    var sites = orderedSites;
    siteId.value = sites.first.id;
    site = sites.first;
    refreshData();
    super.onInit();
  }

  void scrollListener() {
    if (scrollController.position.pixels >=
        (scrollController.position.maxScrollExtent - 100.w)) {
      loadData();
    }
  }

  void setSite(String id) {
    siteId.value = id;
    site = Sites.allSites[id]!;
    refreshData();
  }

  /// 按观看习惯排序后的平台列表
  ///
  /// 看得越多的平台排得越靠前，看量相同时保持默认顺序。
  List<Site> get orderedSites {
    var sites = Sites.supportSites;
    if (!AppSettingsController.instance.sortByWatchHabit.value) {
      return sites;
    }
    var siteDurationMap = _siteWatchDuration;
    sites.sort((a, b) {
      var countCompare =
          (siteDurationMap[b.id] ?? 0).compareTo(siteDurationMap[a.id] ?? 0);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.index.compareTo(b.index);
    });
    return sites;
  }

  /// 平台累计观看时长, 算一次就够
  Map<String, int> get _siteWatchDuration =>
      _siteDurationCache ??= DBService.instance.getSiteWatchDurationMap();

  @override
  Future refreshData() async {
    // 重新拉数据, 在途的旧请求作废
    _loadGeneration++;
    var previous = _pendingLoad;
    if (previous != null) {
      // 旧请求还在飞, 等它落地再拉新的, 两个请求交叉写列表会串数据
      await previous;
    }
    _platformOrder.clear();
    await super.refreshData();
  }

  @override
  Future<List<LiveRoomItemExt>> getData(int page, int pageSize) async {
    var generation = _loadGeneration;
    var result = await site.liveSite.getRecommendRooms(page: page);

    if (generation != _loadGeneration) {
      // 平台已经切走了, 这批数据是旧的, 丢掉
      return [];
    }

    var items = result.items
        .map((e) => LiveRoomItemExt(
              roomId: e.roomId,
              title: e.title,
              cover: e.cover,
              userName: e.userName,
              online: e.online,
            ))
        .toList();

    _platformOrder.addAll(items);
    return items;
  }

  @override
  Future loadData() async {
    var load = super.loadData();
    _pendingLoad = load;
    try {
      await load;
    } finally {
      if (identical(_pendingLoad, load)) {
        _pendingLoad = null;
      }
    }
    // 整份列表一起排, 只排单页的话翻页以后顺序就乱了
    applySortOrder();
  }

  /// 按当前设置重新排已加载的列表
  ///
  /// 开着"按观看习惯排序"就按观看习惯排, 关掉就恢复平台给的原始顺序。
  void applySortOrder() {
    if (!AppSettingsController.instance.sortByWatchHabit.value) {
      list.assignAll(_platformOrder);
      return;
    }
    sortByWatchHabit();
  }

  /// 看过的主播往前排
  ///
  /// 观看次数多的排前面, 次数一样时累计时长长的排前面,
  /// 都一样时保持平台原有的推荐顺序, 免得顺序每次刷新都在跳。
  void sortByWatchHabit() {
    if (!AppSettingsController.instance.sortByWatchHabit.value) {
      return;
    }
    var watchCountMap = DBService.instance.getWatchCountMap();
    var watchDurationMap = DBService.instance.getWatchDurationMap();
    var indexed = _platformOrder.asMap().entries.toList();
    indexed.sort((a, b) {
      var habitCompare = DBService.compareWatchHabit(
        _historyId(a.value),
        _historyId(b.value),
        watchCountMap,
        watchDurationMap,
      );
      if (habitCompare != 0) {
        return habitCompare;
      }
      return a.key.compareTo(b.key);
    });
    list.assignAll(indexed.map((e) => e.value).toList());
  }

  /// 历史记录里的 id, 格式是 siteId_roomId
  String _historyId(LiveRoomItemExt item) => "${site.id}_${item.roomId}";

  @override
  void onClose() {
    scrollController.removeListener(scrollListener);
    _historySubscription?.cancel();
    super.onClose();
  }
}

class LiveRoomItemExt extends LiveRoomItem {
  LiveRoomItemExt({
    required super.roomId,
    required super.title,
    required super.cover,
    required super.userName,
    super.online = 0,
  });

  AppFocusNode focusNode = AppFocusNode();
}
