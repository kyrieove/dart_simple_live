import 'package:hive/hive.dart';

part 'history.g.dart';

@HiveType(typeId: 2)
class History {
  History({
    required this.id,
    required this.roomId,
    required this.siteId,
    required this.userName,
    required this.face,
    required this.updateTime,
    this.watchCount,
    this.watchDuration,
    this.cover,
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
  DateTime updateTime;

  /// 观看次数
  ///
  /// 故意声明成可空: 生成器产出的适配器会写 `fields[6] as int?`,
  /// 老记录(只有 0~5 字段)读出来是 null, 由使用方兜底成 0。
  /// 写成非空的话适配器里就得手写 `as int? ?? 0`, 哪天重新生成代码就崩了。
  @HiveField(6)
  int? watchCount;

  /// 累计观看时长（毫秒）
  @HiveField(7)
  int? watchDuration;

  /// 直播封面
  @HiveField(8)
  String? cover;

  factory History.fromJson(Map<String, dynamic> json) => History(
        id: json["id"],
        roomId: json["roomId"],
        siteId: json["siteId"],
        userName: json["userName"],
        face: json["face"],
        updateTime: DateTime.parse(json["updateTime"]),
        watchCount: json["watchCount"],
        watchDuration: json["watchDuration"],
        cover: json["cover"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "roomId": roomId,
        "siteId": siteId,
        "userName": userName,
        "face": face,
        "updateTime": updateTime.toString(),
        "watchCount": watchCount ?? 0,
        "watchDuration": watchDuration ?? 0,
        "cover": cover ?? "",
      };
}
