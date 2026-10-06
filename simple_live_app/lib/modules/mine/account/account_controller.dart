import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/cookie_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/douyu_account_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/huya_account_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class AccountController extends GetxController {
  void bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      var result = await Utils.showAlertDialog("确定要退出哔哩哔哩账号吗？", title: "退出登录");
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      //AppNavigator.toBiliBiliLogin();
      bilibiliLogin();
    }
  }

  void bilibiliLogin() {
    Utils.showBottomSheet(
      title: "登录哔哩哔哩",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: Platform.isAndroid || Platform.isIOS,
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text("Web登录"),
              subtitle: const Text("填写用户名密码登录"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                Get.toNamed(RoutePath.kBiliBiliWebLogin);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text("扫码登录"),
            subtitle: const Text("使用哔哩哔哩APP扫描二维码登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              Get.toNamed(RoutePath.kBiliBiliQRLogin);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动输入Cookie登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              doBiliBiliCookieLogin();
            },
          ),
        ],
      ),
    );
  }

  void doBiliBiliCookieLogin() async {
    var cookie = await Utils.showEditTextDialog(
      "",
      title: "请输入Cookie",
      hintText: "请输入Cookie",
    );
    if (cookie == null || cookie.isEmpty) {
      return;
    }
    BiliBiliAccountService.instance.setCookie(cookie);
    await BiliBiliAccountService.instance.loadUserInfo();
  }

  /// 通用Cookie登录（斗鱼/虎牙）
  Future<void> cookieLoginTap(String siteId) async {
    var service = _cookieServiceForSite(siteId);
    if (service == null) {
      return;
    }
    if (service.hasCookie.value) {
      var result = await Utils.showAlertDialog("确定要清除已登录的Cookie吗？", title: "清除配置");
      if (result) {
        service.clearCookie();
      }
      return;
    }
    var cookie = await Utils.showEditTextDialog(
      "",
      title: "粘贴${_siteName(siteId)}网页版Cookie",
      hintText: "电脑浏览器登录后，F12 → Network → 复制请求头中的Cookie",
    );
    if (cookie == null || cookie.isEmpty) {
      return;
    }
    service.setCookie(cookie);
    SmartDialog.showToast("已保存Cookie");
  }

  ICookieAccountService? _cookieServiceForSite(String siteId) {
    switch (siteId) {
      case Constant.kDouyu:
        return DouyuAccountService.instance;
      case Constant.kHuya:
        return HuyaAccountService.instance;
      case Constant.kDouyin:
        return DouyinAccountService.instance;
      default:
        return null;
    }
  }

  String _siteName(String siteId) {
    switch (siteId) {
      case Constant.kDouyu:
        return "斗鱼";
      case Constant.kHuya:
        return "虎牙";
      case Constant.kDouyin:
        return "抖音";
      case Constant.kBiliBili:
        return "哔哩哔哩";
      default:
        return siteId;
    }
  }

  void douyinTap() async {
    if (DouyinAccountService.instance.hasCookie.value) {
      Utils.showBottomSheet(
        title: "抖音直播",
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text("重新配置Cookie"),
              subtitle: const Text("用于关注同步，包含sessionid的网页版Cookie"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Get.back();
                var cookie = await Utils.showEditTextDialog(
                  DouyinAccountService.instance.cookie,
                  title: "粘贴抖音网页版Cookie",
                  hintText: "电脑浏览器登录后，F12 → Network → 复制请求头中的Cookie",
                );
                if (cookie != null && cookie.isNotEmpty) {
                  DouyinAccountService.instance.setCookie(cookie);
                  SmartDialog.showToast("已保存Cookie");
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text("配置ttwid"),
              subtitle: const Text("观看直播用的访客令牌"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                doDouyinCookieConfig();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("清除Cookie"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Get.back();
                DouyinAccountService.instance.clearCookie();
                SmartDialog.showToast("已清除Cookie");
              },
            ),
          ],
        ),
      );
    } else {
      doDouyinCookieConfig();
    }
  }

  void doDouyinCookieConfig() {
    // 初始化文本框时，只显示 ttwid 的值部分
    var savedCookie = DouyinAccountService.instance.cookie;
    var displayText = savedCookie;
    if (savedCookie.startsWith('ttwid=')) {
      displayText = savedCookie.substring(6); // 去掉 "ttwid="
    }
    var controller = TextEditingController(text: displayText);

    Get.dialog(
      AlertDialog(
        title: const Text("配置抖音 ttwid"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "默认已内置有效的 ttwid，可观看所有画质（包括蓝光）。\n如需同步关注，请改为粘贴登录后的网页版Cookie。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "请粘贴Cookie（留空则使用默认值）",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  // 提取 ttwid 的值部分（去掉 "ttwid=" 前缀）
                  var defaultValue = DouyinSite.kDefaultCookie;
                  if (defaultValue.startsWith('ttwid=')) {
                    defaultValue = defaultValue.substring(6); // 去掉 "ttwid="
                  }
                  controller.text = defaultValue;
                },
                icon: const Icon(Icons.restore),
                label: const Text("恢复默认 ttwid"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              var input = controller.text.trim();
              Get.back();
              if (input.isEmpty) {
                DouyinAccountService.instance.clearCookie();
                SmartDialog.showToast("已清除自定义 Cookie，将使用默认 ttwid");
              } else {
                // 如果用户只输入了 ttwid 值，自动添加 "ttwid=" 前缀
                var cookie = input;
                if (!input.startsWith('ttwid=')) {
                  cookie = 'ttwid=$input';
                }
                DouyinAccountService.instance.setCookie(cookie);
                SmartDialog.showToast("Cookie 已保存");
              }
            },
            child: const Text("确定"),
          ),
        ],
      ),
    );
  }

  /// 导入所有已登录平台的关注到本地关注列表
  Future<void> importPlatformFollows() async {
    var loggedSites = <String>[];
    if (BiliBiliAccountService.instance.logined.value) {
      loggedSites.add(Constant.kBiliBili);
    }
    if (DouyuAccountService.instance.hasCookie.value) {
      loggedSites.add(Constant.kDouyu);
    }
    if (HuyaAccountService.instance.hasCookie.value) {
      loggedSites.add(Constant.kHuya);
    }
    if (DouyinAccountService.instance.hasCookie.value) {
      loggedSites.add(Constant.kDouyin);
    }
    if (loggedSites.isEmpty) {
      SmartDialog.showToast("请先登录至少一个平台账号");
      return;
    }
    SmartDialog.showLoading(msg: "正在获取关注列表...");
    var summary = <String>[];
    var anySuccess = false;
    try {
      for (var siteId in loggedSites) {
        try {
          var result = await _importFromSite(siteId);
          if (result.added > 0 || result.skipped > 0) {
            anySuccess = true;
          }
          summary.add("${_siteName(siteId)}：新增${result.added}，已有${result.skipped}");
        } catch (e) {
          summary.add("${_siteName(siteId)}：导入失败");
        }
      }
      await FollowService.instance.loadData(updateStatus: false);
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
    if (anySuccess && summary.isNotEmpty) {
      Get.dialog(
        AlertDialog(
          title: const Text("导入完成"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: summary
                .map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(e),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text("确定"),
            ),
          ],
        ),
      );
    } else {
      SmartDialog.showToast("没有导入到新的关注");
    }
  }

  Future<_ImportResult> _importFromSite(String siteId) async {
    var site = Sites.allSites[siteId]!.liveSite;
    var added = 0;
    var skipped = 0;
    var page = 1;
    // 单平台最多拉250页，防止接口异常导致死循环
    while (page <= 250) {
      LiveSearchAnchorResult result;
      if (site is BiliBiliSite) {
        result = await site.getFollowedAnchors(page: page);
      } else if (site is DouyuSite) {
        result = await site.getFollowedAnchors(page: page);
      } else if (site is HuyaSite) {
        result = await site.getFollowedAnchors(page: page);
      } else if (site is DouyinSite) {
        result = await site.getFollowedAnchors(page: page);
      } else {
        break;
      }
      for (var anchor in result.items) {
        var id = "${site.id}_${anchor.roomId}";
        //已关注的跳过，避免覆盖用户设置的标签
        if (DBService.instance.followBox.containsKey(id)) {
          skipped++;
          continue;
        }
        await DBService.instance.addFollow(
          FollowUser(
            id: id,
            roomId: anchor.roomId,
            siteId: site.id,
            userName: anchor.userName,
            face: anchor.avatar,
            addTime: DateTime.now(),
          ),
        );
        added++;
      }
      if (!result.hasMore) {
        break;
      }
      page++;
    }
    return _ImportResult(added: added, skipped: skipped);
  }
}

class _ImportResult {
  final int added;
  final int skipped;
  _ImportResult({required this.added, required this.skipped});
}