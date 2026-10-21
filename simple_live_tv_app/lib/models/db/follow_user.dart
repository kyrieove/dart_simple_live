import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';

part 'follow_user.g.dart';

@HiveType(typeId: 1)
class FollowUser {
  FollowUser({
    required this.id,
    required this.roomId,
    required this.siteId,
    required this.userName,
    required this.face,
    required this.addTime,
  });

  ///id=siteId_roomId
  @HiveField(0)
  String id;

  @HiveField(1)
  String roomId;

  @HiveField(2)
  String siteId;

  @HiveField(3)
  String userName;

  @HiveField(4)
  String face;

  @HiveField(5)
  DateTime addTime;

  /// 直播状态
  /// 0=未知(加载中) 1=未开播 2=直播中
  Rx<int> liveStatus = 0.obs;

  /// 列表焦点节点
  ///
  /// 挂在数据对象上复用, 列表每次重建都 new 一个焦点节点的话,
  /// 关注列表一刷新就会攒下一堆没人释放的节点。
  final AppFocusNode focusNode = AppFocusNode();

  factory FollowUser.fromJson(Map<String, dynamic> json) => FollowUser(
        id: json['id'],
        roomId: json['roomId'],
        siteId: json['siteId'],
        userName: json['userName'],
        face: json['face'],
        addTime: DateTime.parse(json['addTime']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'siteId': siteId,
        'userName': userName,
        'face': face,
        'addTime': addTime.toString(),
      };
}
