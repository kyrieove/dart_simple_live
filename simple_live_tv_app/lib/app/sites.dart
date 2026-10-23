import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';

class Sites {
  static final Map<String, Site> allSites = {
    "bilibili": Site(
      id: "bilibili",
      logo: "assets/images/bilibili_2.png",
      name: "哔哩哔哩",
      liveSite: BiliBiliSite(),
      index: 0,
    ),
    "douyu": Site(
      id: "douyu",
      logo: "assets/images/douyu.png",
      name: "斗鱼直播",
      liveSite: DouyuSite(),
      index: 1,
    ),
    "huya": Site(
      id: "huya",
      logo: "assets/images/huya.png",
      name: "虎牙直播",
      liveSite: HuyaSite(),
      index: 2,
    ),
    "douyin": Site(
      id: "douyin",
      logo: "assets/images/douyin.png",
      name: "抖音直播",
      liveSite: DouyinSite(),
      index: 3,
    ),
  };

  static List<Site> get supportSites {
    return allSites.values.toList();
  }

  /// 按累计观看时长排好的平台列表
  ///
  /// 看得越久的平台排得越靠前, 看量相同时保持默认顺序。
  /// 主页预览和热门直播页用的是同一套规则, 两边显示的平台才对得上。
  static List<Site> orderedByWatchDuration(Map<String, int> durationMap) {
    var sites = supportSites;
    sites.sort((a, b) {
      var compare = (durationMap[b.id] ?? 0).compareTo(durationMap[a.id] ?? 0);
      if (compare != 0) {
        return compare;
      }
      return a.index.compareTo(b.index);
    });
    return sites;
  }
}

class Site {
  final String id;
  final String name;
  final String logo;
  final LiveSite liveSite;
  final int index;
  AppFocusNode appFocusNode = AppFocusNode();
  Site({
    required this.id,
    required this.liveSite,
    required this.logo,
    required this.name,
    required this.index,
  });
}
