import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';

import 'package:simple_live_tv_app/models/db/history.dart';

class DBService extends GetxService {
  static DBService get instance => Get.find<DBService>();
  late Box<History> historyBox;
  late Box<FollowUser> followBox;

  Future init() async {
    historyBox = await Hive.openBox("TVHostiry");
    followBox = await Hive.openBox("TVFollowUser");
  }

  bool getFollowExist(String id) {
    return followBox.containsKey(id);
  }

  List<FollowUser> getFollowList() {
    return followBox.values.toList();
  }

  Future addFollow(FollowUser follow) async {
    await followBox.put(follow.id, follow);
  }

  Future deleteFollow(String id) async {
    await followBox.delete(id);
  }

  History? getHistory(String id) {
    if (historyBox.containsKey(id)) {
      return historyBox.get(id);
    }
    return null;
  }

  Future addOrUpdateHistory(History history) async {
    await historyBox.put(history.id, history);
  }

  List<History> getHistores() {
    var his = historyBox.values.toList();
    his.sort((a, b) => b.updateTime.compareTo(a.updateTime));
    return his;
  }

  /// 每个直播间的观看次数
  Map<String, int> getWatchCountMap() {
    var map = <String, int>{};
    for (var item in historyBox.values) {
      map[item.id] = item.watchCount ?? 0;
    }
    return map;
  }

  /// 每个平台的累计观看时长（毫秒）
  Map<String, int> getSiteWatchDurationMap() {
    var map = <String, int>{};
    for (var item in historyBox.values) {
      map[item.siteId] = (map[item.siteId] ?? 0) + (item.watchDuration ?? 0);
    }
    return map;
  }

  /// 增加观看次数
  Future<void> increaseWatchCount(String id) async {
    var history = getHistory(id);
    if (history == null) {
      return;
    }
    history.watchCount = (history.watchCount ?? 0) + 1;
    await historyBox.put(history.id, history);
  }

  /// 累加观看时长
  Future<void> addWatchDuration(String id, int duration) async {
    if (duration <= 0) {
      return;
    }
    var history = getHistory(id);
    if (history == null) {
      return;
    }
    history.watchDuration = (history.watchDuration ?? 0) + duration;
    await historyBox.put(history.id, history);
  }
}
