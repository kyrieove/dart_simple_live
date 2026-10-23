import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/sites.dart';

class SearchAnchorController extends BasePageController<LiveAnchorItemExt> {
  final String keyword;
  SearchAnchorController(this.keyword);
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
  Future<List<LiveAnchorItemExt>> getData(int page, int pageSize) async {
    var result = await site.liveSite.searchAnchors(keyword, page: page);

    return result.items
        .map((e) => LiveAnchorItemExt(
              roomId: e.roomId,
              avatar: e.avatar,
              liveStatus: e.liveStatus,
              userName: e.userName,
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

class LiveAnchorItemExt extends LiveAnchorItem {
  LiveAnchorItemExt({
    required super.roomId,
    required super.avatar,
    required super.liveStatus,
    required super.userName,
  });

  AppFocusNode focusNode = AppFocusNode();
}
