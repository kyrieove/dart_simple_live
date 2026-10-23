import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/hot_live/hot_live_controller.dart';
import 'package:simple_live_tv_app/routes/app_navigation.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/card/live_room_card.dart';

class HotLivePage extends StatefulWidget {
  const HotLivePage({super.key});

  @override
  State<HotLivePage> createState() => _HotLivePageState();
}

class _HotLivePageState extends State<HotLivePage> {
  final controller = Get.find<HotliveController>();

  /// 顶栏"返回"按钮的焦点节点
  final backFocusNode = AppFocusNode();

  /// 平台切换按钮的焦点节点, 按平台 id 复用
  ///
  /// 放在 build 里 new 的话, 一切换平台按钮就重建, 遥控器的焦点当场丢掉,
  /// 用户按完 OK 看着像没反应。
  final Map<String, AppFocusNode> _siteFocusNodes = {};

  AppFocusNode _siteFocusNode(String id) =>
      _siteFocusNodes.putIfAbsent(id, () => AppFocusNode());

  @override
  void dispose() {
    backFocusNode.dispose();
    for (var node in _siteFocusNodes.values) {
      node.dispose();
    }
    _siteFocusNodes.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppStyle.vGap32,
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: backFocusNode,
                iconData: Icons.arrow_back,
                text: "返回",
                //autofocus: true,
                onTap: () {
                  Get.back();
                },
              ),
              AppStyle.hGap32,
              Text(
                "热门直播",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppStyle.hGap24,
              const Spacer(),
              Obx(
                () => Visibility(
                  visible: controller.loadding.value,
                  child: SizedBox(
                    width: 48.w,
                    height: 48.w,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 4.w,
                    ),
                  ),
                ),
              ),
              AppStyle.hGap24,
              // HighlightButton(
              //   focusNode: AppFocusNode(),
              //   iconData: Icons.refresh,
              //   text: "刷新",
              //   onTap: () {
              //     controller.refreshData();
              //   },
              // ),
              AppStyle.hGap48,
            ],
          ),
          AppStyle.vGap24,
          Obx(
            () => Wrap(
              alignment: WrapAlignment.center,
              spacing: 36.w,
              children: controller.orderedSites
                  .map(
                    (e) => Obx(
                      () => HighlightButton(
                        icon: Image.asset(
                          e.logo,
                          width: 48.w,
                          height: 48.w,
                        ),
                        text: e.name,
                        selected: controller.siteId.value == e.id,
                        focusNode: _siteFocusNode(e.id),
                        onTap: () {
                          controller.setSite(e.id);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          AppStyle.vGap24,
          Expanded(
            child: Obx(
              () {
                if (controller.list.isEmpty) {
                  // 列表空的时候没有卡片可以聚焦, 焦点得落在返回按钮上,
                  // 不然遥控器按哪儿都没反应
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !backFocusNode.hasFocus) {
                      backFocusNode.requestFocus();
                    }
                  });
                  return const SizedBox.shrink();
                }
                return MasonryGridView.count(
                  padding: AppStyle.edgeInsetsA48,
                  itemCount: controller.list.length,
                  crossAxisCount: 5,
                  crossAxisSpacing: 48.w,
                  mainAxisSpacing: 40.w,
                  controller: controller.scrollController,
                  itemBuilder: (_, i) {
                    var item = controller.list[i];

                    if (i == 0) {
                      Future.delayed(Duration.zero, () {
                        if (controller.currentPage == 2) {
                          item.focusNode.requestFocus();
                        }
                      });
                    }
                    return LiveRoomCard(
                      // 列表会按观看习惯重排, 带上 key 焦点才不会跟着位置乱跑
                      key: ValueKey("${controller.site.id}_${item.roomId}"),
                      cover: item.cover,
                      anchor: item.userName,
                      title: item.title,
                      focusNode: item.focusNode,
                      roomId: item.roomId,
                      online: item.online,
                      onTap: () {
                        AppNavigator.toLiveRoomDetail(
                          site: controller.site,
                          roomId: item.roomId,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
