import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/modules/hot_live/hot_live_controller.dart';

class SearchRoomController extends BasePageController<LiveRoomItemExt> {
  final String keyword;
  SearchRoomController(this.keyword);
  var siteId = Constant.kBiliBili.obs;
  var site = Sites.allSites[Constant.kBiliBili]!;

  /// 平台切换按钮的焦点节点, 按平台 id 复用
  ///
  /// 放在 build 里 new 的话, 一切换平台按钮就重建, 遥控器的焦点当场丢掉。
  final Map<String, AppFocusNode> siteFocusNodes = {};

  AppFocusNode siteFocusNode(String id) =>
      siteFocusNodes.putIfAbsent(id, () => AppFocusNode());

  /// 顶栏"返回"按钮的焦点节点
  final backFocusNode = AppFocusNode();

  @override
  void onInit() {
    scrollController.addListener(scrollListener);
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

  @override
  Future<List<LiveRoomItemExt>> getData(int page, int pageSize) async {
    var result = await site.liveSite.searchRooms(keyword, page: page);

    return result.items
        .map((e) => LiveRoomItemExt(
              roomId: e.roomId,
              title: e.title,
              cover: e.cover,
              userName: e.userName,
              online: e.online,
            ))
        .toList();
  }

  @override
  void onClose() {
    scrollController.removeListener(scrollListener);
    for (var node in siteFocusNodes.values) {
      node.dispose();
    }
    siteFocusNodes.clear();
    backFocusNode.dispose();
    super.onClose();
  }
}
