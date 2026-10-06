// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

/// 关注的主播信息（web端协议字段，tag与官方实现一致）
class UserSubscribeToInfo extends TarsStruct {
  int lUid = 0;
  int lYYId = 0;
  String sNick = "";
  String sPrivateHost = "";
  String sAvatar = "";
  int iRoomId = 0;
  int iCertified = 0;
  int iSubscribeCount = 0;
  int iSubscribeTime = 0;
  int iIsLive = 0;
  int iGameId = 0;
  String sGameName = "";
  String sLiveDesc = "";
  String sVideoCaptureUrl = "";
  int iAttendeeCount = 0;
  int iStartTime = 0;
  String sScheduleTime = "";
  String sDescription = "";
  int iRelation = 0;

  @override
  void readFrom(TarsInputStream _is) {
    lUid = _is.read(lUid, 0, false);
    lYYId = _is.read(lYYId, 1, false);
    sNick = _is.read(sNick, 2, false);
    sPrivateHost = _is.read(sPrivateHost, 3, false);
    sAvatar = _is.read(sAvatar, 4, false);
    iRoomId = _is.read(iRoomId, 5, false);
    iCertified = _is.read(iCertified, 6, false);
    iSubscribeCount = _is.read(iSubscribeCount, 7, false);
    iSubscribeTime = _is.read(iSubscribeTime, 8, false);
    iIsLive = _is.read(iIsLive, 9, false);
    iGameId = _is.read(iGameId, 10, false);
    sGameName = _is.read(sGameName, 11, false);
    sLiveDesc = _is.read(sLiveDesc, 12, false);
    sVideoCaptureUrl = _is.read(sVideoCaptureUrl, 13, false);
    iAttendeeCount = _is.read(iAttendeeCount, 14, false);
    iStartTime = _is.read(iStartTime, 15, false);
    sScheduleTime = _is.read(sScheduleTime, 16, false);
    sDescription = _is.read(sDescription, 17, false);
    iRelation = _is.read(iRelation, 18, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(lUid, 0);
    _os.write(lYYId, 1);
    _os.write(sNick, 2);
    _os.write(sPrivateHost, 3);
    _os.write(sAvatar, 4);
    _os.write(iRoomId, 5);
    _os.write(iCertified, 6);
    _os.write(iSubscribeCount, 7);
    _os.write(iSubscribeTime, 8);
    _os.write(iIsLive, 9);
    _os.write(iGameId, 10);
    _os.write(sGameName, 11);
    _os.write(sLiveDesc, 12);
    _os.write(sVideoCaptureUrl, 13);
    _os.write(iAttendeeCount, 14);
    _os.write(iStartTime, 15);
    _os.write(sScheduleTime, 16);
    _os.write(sDescription, 17);
    _os.write(iRelation, 18);
  }

  @override
  Object deepCopy() {
    return UserSubscribeToInfo()
      ..lUid = lUid
      ..lYYId = lYYId
      ..sNick = sNick
      ..sPrivateHost = sPrivateHost
      ..sAvatar = sAvatar
      ..iRoomId = iRoomId
      ..iCertified = iCertified
      ..iSubscribeCount = iSubscribeCount
      ..iSubscribeTime = iSubscribeTime
      ..iIsLive = iIsLive
      ..iGameId = iGameId
      ..sGameName = sGameName
      ..sLiveDesc = sLiveDesc
      ..sVideoCaptureUrl = sVideoCaptureUrl
      ..iAttendeeCount = iAttendeeCount
      ..iStartTime = iStartTime
      ..sScheduleTime = sScheduleTime
      ..sDescription = sDescription
      ..iRelation = iRelation;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}
