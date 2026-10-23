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
        updateTime: _parseUpdateTime(json["updateTime"]),
        watchCount: _parseCount(json["watchCount"]),
        watchDuration: _parseCount(json["watchDuration"]),
        cover: _parseCover(json["cover"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "roomId": roomId,
        "siteId": siteId,
        "userName": userName,
        "face": face,
        "updateTime": updateTime.toUtc().toIso8601String(),
        "watchCount": watchCount ?? 0,
        "watchDuration": watchDuration ?? 0,
        "cover": cover ?? "",
      };

  /// 把远端记录合并进本地记录
  ///
  /// 手机端同步过来的记录里根本没有观看次数和时长, 整行覆盖会把电视端统计清零,
  /// 房间就变成"没看过"了。远端没带的字段用本地的值, 带了的字段取两边较大的那个,
  /// 这样同步永远不会丢本地的观看进度。
  History mergeWith(History local) => History(
        id: id,
        roomId: roomId,
        siteId: siteId,
        userName: userName.isEmpty ? local.userName : userName,
        face: face.isEmpty ? local.face : face,
        updateTime:
            updateTime.isAfter(local.updateTime) ? updateTime : local.updateTime,
        watchCount: _maxCount(watchCount, local.watchCount),
        watchDuration: _maxCount(watchDuration, local.watchDuration),
        cover: cover ?? local.cover,
      );

  /// 取两个计数里大的那个
  ///
  /// 两边都没有就返回 null, 表示这条记录没有这个数据。
  static int? _maxCount(int? a, int? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return a > b ? a : b;
  }

  /// 解析观看次数和时长
  ///
  /// 手机端不带这两个字段, 老数据里也可能存的是字符串, 统一转成 int。
  /// 拿不到就返回 null, 表示这条记录没有这个数据, 合并时用本地的值。
  static int? _parseCount(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      var text = value.trim();
      if (text.isEmpty) {
        return null;
      }
      return int.tryParse(text) ?? double.tryParse(text)?.toInt();
    }
    return null;
  }

  /// 解析封面
  ///
  /// 空串当作没有封面, 合并的时候才分得清"远端没带封面"和"远端封面是空的"。
  static String? _parseCover(dynamic value) {
    if (value is! String) {
      return null;
    }
    var text = value.trim();
    return text.isEmpty ? null : text;
  }

  /// 解析更新时间
  ///
  /// 新版本写的是带时区的 ISO8601, 老版本写的是不带时区的本地时间。
  /// 不带时区的按 UTC 解读, 不然两台设备各按本地时区读同一个时间, 谁新谁旧就判断错了。
  /// 解析不出来就当成最早的时间, 不会盖掉本地的时间。
  static DateTime _parseUpdateTime(dynamic value) {
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is! String) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    var text = value.trim();
    if (text.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    DateTime parsed;
    try {
      parsed = DateTime.parse(text);
    } catch (e) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    if (parsed.isUtc) {
      return parsed;
    }

    // 字符串里没有时区信息, 按 UTC 解读
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }
}
