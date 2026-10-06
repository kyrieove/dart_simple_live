import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/services/cookie_account_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class HuyaAccountService extends GetxService implements ICookieAccountService {
  static HuyaAccountService get instance => Get.find<HuyaAccountService>();

  var cookie = "";
  var hasCookie = false.obs;

  @override
  void onInit() {
    cookie = LocalStorageService.instance
        .getValue(LocalStorageService.kHuyaCookie, "");
    hasCookie.value = cookie.isNotEmpty;
    setSite();
    super.onInit();
  }

  void setSite() {
    var site = (Sites.allSites[Constant.kHuya]!.liveSite as HuyaSite);
    site.cookie = cookie;
  }

  void setCookie(String cookie) {
    this.cookie = cookie;
    LocalStorageService.instance
        .setValue(LocalStorageService.kHuyaCookie, cookie);
    hasCookie.value = cookie.isNotEmpty;
    setSite();
  }

  void clearCookie() {
    cookie = "";
    LocalStorageService.instance
        .setValue(LocalStorageService.kHuyaCookie, "");
    hasCookie.value = false;
    setSite();
  }
}
