import 'package:get/get.dart';

/// 支持Cookie登录的账号服务接口（用于通用登录逻辑）
abstract class ICookieAccountService {
  Rx<bool> get hasCookie;
  void setCookie(String cookie);
  void clearCookie();
}
