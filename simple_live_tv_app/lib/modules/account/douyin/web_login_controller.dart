import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/services/douyin_account_service.dart';

class DouyinWebLoginController extends GetxController {
  InAppWebViewController? webViewController;
  final CookieManager cookieManager = CookieManager.instance();
  Timer? pollTimer;
  var saving = false;

  /// 登录页地址：抖音官方扫码登录页
  static const loginUrl =
      "https://www.douyin.com/login_page?service=https%3A%2F%2Fwww.douyin.com";

  @override
  void onInit() {
    // 定期检查登录态，检测到sessionid即登录成功
    pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      checkLogin();
    });
    super.onInit();
  }

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    webViewController!.loadUrl(
      urlRequest: URLRequest(url: WebUri(loginUrl)),
    );
  }

  Future<void> checkLogin() async {
    if (saving) {
      return;
    }
    try {
      var cookies =
          await cookieManager.getCookies(url: WebUri("https://live.douyin.com"));
      var hasSession = cookies.any((c) => c.name == "sessionid");
      if (!hasSession) {
        return;
      }
      saving = true;
      var cookieStr = cookies.map((e) => "${e.name}=${e.value}").join(";");
      Log.i("douyin web login success");
      DouyinAccountService.instance.setCookie(cookieStr);
      SmartDialog.showToast("登录成功");
      Get.back();
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
