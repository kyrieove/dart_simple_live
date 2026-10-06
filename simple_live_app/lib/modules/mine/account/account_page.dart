import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/modules/mine/account/account_controller.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/douyu_account_service.dart';
import 'package:simple_live_app/services/huya_account_service.dart';

class AccountPage extends GetView<AccountController> {
  const AccountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("账号管理"),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: AppStyle.edgeInsetsA12,
            child: Text(
              "登录各平台账号后，可一键将平台关注的主播同步到关注列表。",
              textAlign: TextAlign.center,
            ),
          ),
          Obx(
            () => ListTile(
              leading: const Icon(Icons.sync),
              title: const Text("导入平台关注"),
              subtitle: Text(_importSubtitle()),
              onTap: controller.importPlatformFollows,
            ),
          ),
          const Divider(),
          Obx(
            () => ListTile(
              leading: Image.asset(
                'assets/images/bilibili_2.png',
                width: 36,
                height: 36,
              ),
              title: const Text("哔哩哔哩"),
              subtitle: Text(BiliBiliAccountService.instance.name.value),
              trailing: BiliBiliAccountService.instance.logined.value
                  ? const Icon(Icons.logout)
                  : const Icon(Icons.chevron_right),
              onTap: controller.bilibiliTap,
            ),
          ),
          ListTile(
            leading: Image.asset(
              'assets/images/douyu.png',
              width: 36,
              height: 36,
            ),
            title: const Text("斗鱼直播"),
            subtitle: Obx(
              () => Text(DouyuAccountService.instance.hasCookie.value
                  ? "已登录"
                  : "点击登录，登录后可同步关注"),
            ),
            trailing: Obx(
              () => DouyuAccountService.instance.hasCookie.value
                  ? const Icon(Icons.delete_outline)
                  : const Icon(Icons.chevron_right),
            ),
            onTap: () => controller.cookieLoginTap(Constant.kDouyu),
          ),
          ListTile(
            leading: Image.asset(
              'assets/images/huya.png',
              width: 36,
              height: 36,
            ),
            title: const Text("虎牙直播"),
            subtitle: Obx(
              () => Text(HuyaAccountService.instance.hasCookie.value
                  ? "已登录"
                  : "点击登录，登录后可同步关注"),
            ),
            trailing: Obx(
              () => HuyaAccountService.instance.hasCookie.value
                  ? const Icon(Icons.delete_outline)
                  : const Icon(Icons.chevron_right),
            ),
            onTap: () => controller.cookieLoginTap(Constant.kHuya),
          ),
          Obx(
            () => ListTile(
              leading: Image.asset(
                'assets/images/douyin.png',
                width: 36,
                height: 36,
              ),
              title: const Text("抖音直播"),
              subtitle: Text(DouyinAccountService.instance.hasCookie.value
                  ? (DouyinAccountService.instance.cookie.contains("sessionid")
                      ? "已登录"
                      : "未登录（点击登录）")
                  : "点击登录，登录后可同步关注"),
              trailing: DouyinAccountService.instance.hasCookie.value
                  ? const Icon(Icons.settings_outlined)
                  : const Icon(Icons.chevron_right),
              onTap: controller.douyinTap,
            ),
          ),
        ],
      ),
    );
  }

  String _importSubtitle() {
    var logged = <String>[];
    if (BiliBiliAccountService.instance.logined.value) {
      logged.add("B站");
    }
    if (DouyuAccountService.instance.hasCookie.value) {
      logged.add("斗鱼");
    }
    if (HuyaAccountService.instance.hasCookie.value) {
      logged.add("虎牙");
    }
    if (DouyinAccountService.instance.hasCookie.value) {
      logged.add("抖音");
    }
    return logged.isEmpty ? "需要先登录平台账号" : "已登录：${logged.join("、")}";
  }
}
