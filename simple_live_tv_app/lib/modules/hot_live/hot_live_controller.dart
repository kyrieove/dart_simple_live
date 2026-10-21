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

  @override
  void onInit() {
    scrollController.addListener(scrollListener);
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
    var siteDurationMap = DBService.instance.getSiteWatchDurationMap();
    sites.sort((a, b) {
      var countCompare = (siteDurationMap[b.id] ?? 0)
          .compareTo(siteDurationMap[a.id] ?? 0);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.index.compareTo(b.index);
    });
    return sites;
  }

  @override
  Future<List<LiveRoomItemExt>> getData(int page, int pageSize) async {
    var result = await site.liveSite.getRecommendRooms(page: page);

    var items = result.items
        .map((e) => LiveRoomItemExt(
              roomId: e.roomId,
              title: e.title,
              cover: e.cover,
              userName: e.userName,
              online: e.online,
            ))
        .toList();

    if (!AppSettingsController.instance.sortByWatchHabit.value) {
      return items;
    }

    // 看过的主播往前排，看量相同时保持平台原有的推荐顺序
    var watchCountMap = DBService.instance.getWatchCountMap();
    var indexed = items.asMap().entries.toList();
    indexed.sort((a, b) {
      var countA = watchCountMap["${site.id}_${a.value.roomId}"] ?? 0;
      var countB = watchCountMap["${site.id}_${b.value.roomId}"] ?? 0;
      if (countA != countB) {
        return countB.compareTo(countA);
      }
      return a.key.compareTo(b.key);
    });

    return indexed.map((e) => e.value).toList();
  }

  @override
  void onClose() {
    scrollController.removeListener(scrollListener);
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
