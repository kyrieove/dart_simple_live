import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/models/db/history.dart';
import 'package:simple_live_tv_app/services/db_service.dart';

class HistoryController extends BasePageController<History> {
  /// 卡片的焦点节点, 按观看记录 id 复用
  ///
  /// 放在 build 里 new 的话, 列表每重建一次就换一个节点, 遥控器焦点会丢, OK 键按下去没反应。
  final Map<String, AppFocusNode> _cardFocusNodes = {};

  AppFocusNode focusNodeFor(String id) =>
      _cardFocusNodes.putIfAbsent(id, () => AppFocusNode());

  @override
  void onInit() {
    refreshData();
    super.onInit();
  }

  @override
  Future<List<History>> getData(int page, int pageSize) {
    if (page > 1) {
      return Future.value([]);
    }
    return Future.value(DBService.instance.getHistores());
  }

  void clean() async {
    var result = await Utils.showAlertDialog("确定要清空观看记录吗?", title: "清空观看记录");
    if (!result) {
      return;
    }
    await DBService.instance.historyBox.clear();
    refreshData();
  }

  void removeItem(History item) async {
    var result = await Utils.showAlertDialog("确定要删除此记录吗?", title: "删除记录");
    if (!result) {
      return;
    }
    await DBService.instance.historyBox.delete(item.id);
    refreshData();
  }

  @override
  void onClose() {
    for (var node in _cardFocusNodes.values) {
      node.dispose();
    }
    _cardFocusNodes.clear();
    super.onClose();
  }
}
