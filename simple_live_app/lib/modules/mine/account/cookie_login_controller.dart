import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/douyu_account_service.dart';
import 'package:simple_live_app/services/huya_account_service.dart';

/// 各平台内置网页登录配置
class CookieLoginSiteConfig {
  final String siteId;
  final String title;
  final String startUrl;
  final String cookieUrl;

  /// 登录态标记Cookie（存在即认为登录成功）
  final String marker;
  const CookieLoginSiteConfig({
    required this.siteId,
    required this.title,
    required this.startUrl,
    required this.cookieUrl,
    required this.marker,
  });

  static const douyu = CookieLoginSiteConfig(
    siteId: Constant.kDouyu,
    title: "斗鱼登录",
    startUrl: "https://www.douyu.com/",
    cookieUrl: "https://www.douyu.com",
    marker: "acf_auth",
  );
  static const huya = CookieLoginSiteConfig(
    siteId: Constant.kHuya,
    title: "虎牙登录",
    startUrl: "https://www.huya.com/",
    cookieUrl: "https://www.huya.com",
    marker: "udb_passport",
  );
  static const douyin = CookieLoginSiteConfig(
    siteId: Constant.kDouyin,
    title: "抖音登录",
    startUrl: "https://live.douyin.com/",
    cookieUrl: "https://live.douyin.com",
    marker: "sessionid",
  );
}

class CookieLoginController extends BaseController {
  late final CookieLoginSiteConfig config;
  InAppWebViewController? webViewController;
  final CookieManager cookieManager = CookieManager.instance();
  Timer? pollTimer;
  var saving = false;

  @override
  void onInit() {
    var args = Get.arguments;
    if (args is CookieLoginSiteConfig) {
      config = args;
    } else {
      config = CookieLoginSiteConfig.douyu;
    }
    // 定期检查登录态，登录成功自动保存并返回
    pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      checkLogin();
    });
    super.onInit();
  }

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    webViewController!.loadUrl(
      urlRequest: URLRequest(url: WebUri(config.startUrl)),
    );
  }

  Future<void> checkLogin() async {
    if (saving) {
      return;
    }
    try {
      var cookies =
          await cookieManager.getCookies(url: WebUri(config.cookieUrl));
      var hasMarker = cookies.any((c) => c.name == config.marker);
      if (!hasMarker) {
        return;
      }
      saving = true;
      var cookieStr = cookies.map((e) => "${e.name}=${e.value}").join(";");
      Log.i("cookie login success: ${config.siteId}");
      switch (config.siteId) {
        case Constant.kDouyu:
          DouyuAccountService.instance.setCookie(cookieStr);
          break;
        case Constant.kHuya:
          HuyaAccountService.instance.setCookie(cookieStr);
          break;
        case Constant.kDouyin:
          DouyinAccountService.instance.setCookie(cookieStr);
          break;
      }
      SmartDialog.showToast("登录成功");
      if (Get.currentRoute == RoutePath.kCookieWebviewLogin) {
        Get.back();
      }
    } catch (e) {
      Log.logPrint(e);
    }
  }

  @override
  void onClose() {
    pollTimer?.cancel();
    super.onClose();
  }
}
