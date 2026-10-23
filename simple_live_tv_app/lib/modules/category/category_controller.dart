import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/sites.dart';

class CategoryController extends BasePageController<AppLiveCategory> {
  var siteId = Constant.kBiliBili.obs;
  var site = Sites.allSites[Constant.kBiliBili]!;

  /// 平台切换按钮的焦点节点, 按平台 id 复用
  ///
  /// 放在 build 里 new 的话, 一切换平台按钮就重建, 遥控器的焦点当场丢掉,
  /// 用户按完 OK 看着像没反应。
  final Map<String, AppFocusNode> siteFocusNodes = {};

  AppFocusNode siteFocusNode(String id) =>
      siteFocusNodes.putIfAbsent(id, () => AppFocusNode());

  /// 顶栏"返回"按钮的焦点节点
  final backFocusNode = AppFocusNode();

  @override
  void onInit() {
    refreshData();
    super.onInit();
  }

  void setSite(String id) {
    siteId.value = id;
    site = Sites.allSites[id]!;
    refreshData();
  }

  @override
  Future<List<AppLiveCategory>> getData(int page, int pageSize) async {
    var result = await site.liveSite.getCategores();

    return result.map((e) => AppLiveCategory.fromLiveCategory(e)).toList();
  }

  @override
  void onClose() {
    for (var node in siteFocusNodes.values) {
      node.dispose();
    }
    siteFocusNodes.clear();
    backFocusNode.dispose();
    super.onClose();
  }
}

class AppLiveCategory extends LiveCategory {
  var showAll = false.obs;
  final List<LiveSubCategoryExt> childrenExt;
  AppLiveCategory({
    required super.id,
    required super.name,
    required super.children,
  }) : childrenExt = children
            .map((e) => LiveSubCategoryExt(
                  id: e.id,
                  name: e.name,
                  parentId: e.parentId,
                  pic: e.pic,
                ))
            .toList() {
    showAll.value = children.length < 19;
  }

  List<LiveSubCategoryExt> get take15 => childrenExt.take(15).toList();

  AppFocusNode moreFocusNode = AppFocusNode();

  factory AppLiveCategory.fromLiveCategory(LiveCategory item) {
    return AppLiveCategory(
      children: item.children,
      id: item.id,
      name: item.name,
    );
  }
}

class LiveSubCategoryExt extends LiveSubCategory {
  LiveSubCategoryExt({
    required super.id,
    required super.name,
    required super.parentId,
    super.pic,
  });

  AppFocusNode focusNode = AppFocusNode();
}
