import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/app_theme.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/models/db/history.dart';
import 'package:simple_live_tv_app/modules/home/home_controller.dart';
import 'package:simple_live_tv_app/routes/app_navigation.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_list_tile.dart';
import 'package:simple_live_tv_app/widgets/card/anchor_card.dart';
import 'package:simple_live_tv_app/widgets/card/live_room_card.dart';
import 'package:simple_live_tv_app/widgets/highlight_widget.dart';
import 'package:simple_live_tv_app/widgets/net_image.dart';
import 'package:simple_live_tv_app/widgets/status/app_empty_widget.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppStyle.vGap32,
          _buildTopBar(),
          AppStyle.vGap24,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNavRail(),
                AppStyle.hGap32,
                Expanded(
                  child: ListView(
                    // 左边留出和导航栏的距离, 右边留出页边距。
                    // 内容区贴着导航栏的时候, "我的关注"这个标题
                    // 看着就像导航栏里的第六个入口。
                    padding: EdgeInsets.only(
                      left: 48.w,
                      right: 48.w,
                      top: 24.w,
                      bottom: 24.w,
                    ),
                    children: [
                      _buildHero(),
                      AppStyle.vGap24,
                      _buildHotRooms(),
                      AppStyle.vGap24,
                      _buildRecent(),
                      AppStyle.vGap24,
                      _buildFollow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部标题栏
  Widget _buildTopBar() {
    return Padding(
      padding: AppStyle.edgeInsetsH48,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppStyle.radius12,
            child: Image.asset(
              "assets/images/app_logo.png",
              width: 52.w,
              height: 52.w,
              fit: BoxFit.contain,
            ),
          ),
          AppStyle.hGap16,
          Text("Simple Live TV", style: AppStyle.titleStyleWhite),
          const Spacer(),
          Obx(
            () => Text(
              controller.datetime.value,
              style: AppStyle.subTextStyleWhite.copyWith(fontSize: 28.w),
            ),
          ),
          AppStyle.hGap24,
          HighlightButton(
            focusNode: controller.settingsFocusNode,
            iconData: Icons.settings,
            text: "设置",
            onTap: () {
              controller.toSettings();
            },
          ),
        ],
      ),
    );
  }

  /// 左侧导航
  Widget _buildNavRail() {
    var items = [
      ("热门直播", Icons.local_fire_department_rounded, controller.toHotLive),
      ("直播类目", Icons.grid_view_rounded, controller.toCategory),
      ("搜索直播", Icons.search_rounded, () => showSearchDialog()),
      ("观看记录", Icons.history_rounded, controller.toHistory),
      ("数据同步", Icons.devices_rounded, controller.toSync),
    ];

    return SizedBox(
      width: 300.w,
      child: ListView.separated(
        // 左边跟内容区对齐, 右边只留一点间距
        padding: EdgeInsets.only(left: 48.w, right: 8.w),
        itemCount: items.length,
        separatorBuilder: (_, __) => AppStyle.vGap12,
        itemBuilder: (_, i) {
          var item = items[i];
          var focusNode = controller.navFocusNodes[i];
          return HighlightWidget(
            focusNode: focusNode,
            borderRadius: AppStyle.radius12,
            color: Colors.white.withAlpha(14),
            onTap: item.$3,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 20.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(
                    () => Icon(
                      item.$2,
                      color: focusNode.isFoucsed.value
                          ? Colors.black
                          : Colors.white,
                      size: 30.w,
                    ),
                  ),
                  AppStyle.hGap16,
                  _label(focusNode, item.$1),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 英雄卡: 接着看刚才看的
  Widget _buildHero() {
    return Obx(() {
      var history = controller.recentHistory;
      if (history.isEmpty) {
        return const SizedBox.shrink();
      }
      var item = history.first;
      var site = Sites.allSites[item.siteId];
      if (site == null) {
        return const SizedBox.shrink();
      }
      var focusNode = controller.heroFocusNode;
      return HighlightWidget(
        focusNode: focusNode,
        borderRadius: AppStyle.radius16,
        color: Colors.white.withAlpha(14),
        onTap: () {
          AppNavigator.toLiveRoomDetail(site: site, roomId: item.roomId);
        },
        child: SizedBox(
          height: 300.w,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                  child: (item.cover ?? "").isEmpty
                      // 老记录没有封面, 拿头像顶上, 免得英雄卡空一大块
                      ? NetImage(
                          item.face,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : NetImage(
                          item.cover ?? "",
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 36.w, vertical: 28.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 5.w),
                            decoration: BoxDecoration(
                              color: AppTheme.liveBadge,
                              borderRadius: AppStyle.radius8,
                            ),
                            child: Text(
                              "直播中",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20.w,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          AppStyle.hGap16,
                          Image.asset(site.logo, width: 30.w),
                          AppStyle.hGap8,
                          _label(
                            focusNode,
                            site.name,
                            style: AppStyle.subTextStyleWhite,
                            focusedStyle: AppStyle.subTextStyleBlack,
                          ),
                        ],
                      ),
                      AppStyle.vGap16,
                      _label(
                        focusNode,
                        item.userName,
                        style: AppStyle.titleStyleWhite,
                      ),
                      AppStyle.vGap24,
                      _label(
                        focusNode,
                        "继续观看",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26.w,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// 热门直播预览
  ///
  /// 主页原来只有"继续观看"那一张卡。没有关注也没有历史的时候,
  /// 整屏只剩一个房间, 看着像没内容。这里放一批热门直播,
  /// 一打开主页就有得看。
  Widget _buildHotRooms() {
    return Obx(() {
      var list = controller.hotRooms;
      if (list.isEmpty) {
        return const SizedBox.shrink();
      }
      var site = controller.hotSite.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            Icons.local_fire_department_rounded,
            "热门直播",
            trailing: site.name,
          ),
          AppStyle.vGap16,
          MasonryGridView.count(
            // 左右各留一点: 焦点卡片会放大 6%, 不留的话边缘会被网格切掉
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: list.length,
            crossAxisCount: 5,
            crossAxisSpacing: 24.w,
            mainAxisSpacing: 24.w,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, i) {
              var item = list[i];
              return LiveRoomCard(
                key: ValueKey("${site.id}_${item.roomId}"),
                cover: item.cover,
                anchor: item.userName,
                title: item.title,
                focusNode: item.focusNode,
                roomId: item.roomId,
                online: item.online,
                onTap: () {
                  AppNavigator.toLiveRoomDetail(
                    site: site,
                    roomId: item.roomId,
                  );
                },
              );
            },
          ),
        ],
      );
    });
  }

  /// 最近观看
  Widget _buildRecent() {
    return Obx(() {
      var list = controller.recentHistory;
      if (list.length <= 1) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(Icons.history_rounded, "最近观看"),
          AppStyle.vGap16,
          SizedBox(
            height: 120.w,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: list.length - 1,
              itemBuilder: (_, i) {
                var item = list[i + 1];
                return Padding(
                  // 列表刷新后顺序会变, 带上 key 才能让同一张卡片的焦点跟着它走
                  key: ValueKey(item.id),
                  padding: EdgeInsets.only(right: 16.w),
                  child: _buildRecentCard(item),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildRecentCard(History item) {
    var site = Sites.allSites[item.siteId];
    if (site == null) {
      return const SizedBox.shrink();
    }
    var focusNode = controller.focusNodeFor(item.id);
    return HighlightWidget(
      focusNode: focusNode,
      borderRadius: AppStyle.radius12,
      color: Colors.white.withAlpha(14),
      onTap: () {
        AppNavigator.toLiveRoomDetail(site: site, roomId: item.roomId);
      },
      child: Padding(
        padding: AppStyle.edgeInsetsA16,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NetImage(
              item.face,
              width: 72.w,
              height: 72.w,
              borderRadius: 72.w,
              cacheWidth: 100,
            ),
            AppStyle.hGap16,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _label(focusNode, item.userName),
                _label(
                  focusNode,
                  site.name,
                  style: AppStyle.subTextStyleWhite,
                  focusedStyle: AppStyle.subTextStyleBlack,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 我的关注
  Widget _buildFollow() {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(Icons.favorite_border, "我的关注"),
          AppStyle.vGap16,
          if (FollowUserService.instance.list.isEmpty)
            // 空状态做成一个有边界的小面板, 居中摆在内容区里。
            // 散落在左上角会像页面没做完, 右边一大片空地更没有交代。
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.w),
              child: Center(
                child: Container(
                  width: 720.w,
                  padding: EdgeInsets.symmetric(
                    vertical: 40.w,
                    horizontal: 48.w,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: AppStyle.radius16,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LottieBuilder.asset(
                        'assets/lotties/empty.json',
                        width: 120.w,
                        height: 120.w,
                        repeat: false,
                      ),
                      AppStyle.vGap16,
                      Text(
                        "暂无任何关注",
                        style: AppStyle.textStyleWhite,
                      ),
                      AppStyle.vGap8,
                      Text(
                        "您可以从其他端同步数据到此处",
                        textAlign: TextAlign.center,
                        style: AppStyle.subTextStyleWhite,
                      ),
                      AppStyle.vGap24,
                      HighlightButton(
                        focusNode: controller.syncFocusNode,
                        iconData: Icons.devices,
                        text: "同步数据",
                        onTap: () {
                          controller.toSync();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            MasonryGridView.count(
              padding: EdgeInsets.zero,
              itemCount: FollowUserService.instance.list.length,
              crossAxisCount: 3,
              crossAxisSpacing: 16.w,
              mainAxisSpacing: 16.w,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (_, i) {
                var item = FollowUserService.instance.list[i];
                return Obx(
                  () => AnchorCard(
                    // 关注列表会按观看习惯重排, 带上 key 焦点才不会跟着位置乱跑
                    key: ValueKey(item.id),
                    face: item.face,
                    name: item.userName,
                    siteId: item.siteId,
                    liveStatus: item.liveStatus.value,
                    roomId: item.roomId,
                    focusNode: item.focusNode,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, {String? trailing}) {
    // 内容区的标题要比导航栏里的条目大一号, 两边才分得清谁是导航谁是正文
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 36.w),
        AppStyle.hGap12,
        Text(title, style: AppStyle.titleStyleWhite),
        if (trailing != null) ...[
          AppStyle.hGap16,
          Text(trailing, style: AppStyle.subTextStyleWhite),
        ],
      ],
    );
  }

  /// 焦点态下卡片背景会变白, 文字跟着翻色, 否则白底白字看不见
  Widget _label(
    AppFocusNode focusNode,
    String text, {
    TextStyle? style,
    TextStyle? focusedStyle,
  }) {
    return Obx(
      () => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: focusNode.isFoucsed.value
            ? (focusedStyle ?? AppStyle.textStyleBlack)
            : (style ?? AppStyle.textStyleWhite),
      ),
    );
  }

  void showManageDialog() {
    Utils.showSystemRightDialog(
      //useSystem: true,
      width: 700.w,
      child: Column(
        children: [
          AppStyle.vGap24,
          Row(
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: controller.manageBackFocusNode,
                iconData: Icons.arrow_back,
                text: "返回",
                onTap: () {
                  //Utils.hideRightDialog();
                  Get.back();
                },
              ),
              AppStyle.hGap32,
              Text(
                "关注管理",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppStyle.hGap24,
              const Spacer(),
            ],
          ),
          Expanded(
            child: Stack(
              children: [
                Obx(
                  () => ListView.separated(
                    itemCount: FollowUserService.instance.list.length,
                    separatorBuilder: (_, __) => AppStyle.vGap24,
                    padding: AppStyle.edgeInsetsA40,
                    itemBuilder: (_, i) {
                      var item = FollowUserService.instance.list[i];
                      var foucsNode = item.focusNode;
                      return HighlightListTile(
                        autofocus: i == 0,
                        leading: NetImage(
                          item.face,
                          width: 64.w,
                          height: 64.w,
                          borderRadius: 64.w,
                        ),
                        title: item.userName,
                        focusNode: foucsNode,
                        trailing: Obx(
                          () => Icon(
                            Icons.delete_outline_outlined,
                            size: 40.w,
                            color: foucsNode.isFoucsed.value
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                        onTap: () {
                          FollowUserService.instance
                              .removeItem(item, refresh: false);
                        },
                      );
                    },
                  ),
                ),
                Obx(
                  () => Visibility(
                    visible: FollowUserService.instance.list.isEmpty,
                    child: const AppEmptyWidget(
                      text: "关注列表为空，快去关注一些主播吧",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showSearchDialog() {
    var mode = 0.obs;
    var roomFocusNode = controller.searchRoomFocusNode..isFoucsed.value = true;
    var anchorFocusNode = controller.searchAnchorFocusNode..isFoucsed.value = false;
    controller.searchTextController.clear();
    showDialog(
      context: Get.context!,
      builder: (_) => AlertDialog(
        backgroundColor: Get.theme.cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppStyle.radius16,
        ),
        contentPadding: AppStyle.edgeInsetsA48,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Obx(
                  () => HighlightButton(
                    text: "直播间",
                    iconData: Icons.live_tv,
                    selected: mode.value == 0,
                    focusNode: roomFocusNode,
                    autofocus: roomFocusNode.isFoucsed.value,
                    onTap: () {
                      mode.value = 0;
                    },
                  ),
                ),
                AppStyle.hGap40,
                Obx(
                  () => HighlightButton(
                    text: "主播",
                    iconData: Icons.person,
                    selected: mode.value == 1,
                    focusNode: anchorFocusNode,
                    autofocus: anchorFocusNode.isFoucsed.value,
                    onTap: () {
                      mode.value = 1;
                    },
                  ),
                ),
              ],
            ),
            AppStyle.vGap48,
            SizedBox(
              width: 700.w,
              child: TextField(
                controller: controller.searchTextController,
                style: AppStyle.textStyleWhite,
                textInputAction: TextInputAction.search,
                onSubmitted: (e) {
                  Get.back();
                  if (e.isEmpty) {
                    return;
                  }
                  if (mode.value == 0) {
                    controller.toSearchRoom(controller.searchTextController.text);
                  } else {
                    controller.toSearchAnchor(controller.searchTextController.text);
                  }
                },
                decoration: InputDecoration(
                  hintText: mode.value == 0 ? "点击输入关键字搜索" : "点击主播昵称搜索",
                  hintStyle: AppStyle.subTextStyleWhite,
                  border: OutlineInputBorder(
                    borderRadius: AppStyle.radius16,
                    borderSide: BorderSide(width: 4.w),
                  ),
                  filled: true,
                  isDense: true,
                  fillColor: Get.theme.primaryColor,
                  contentPadding: AppStyle.edgeInsetsA32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
