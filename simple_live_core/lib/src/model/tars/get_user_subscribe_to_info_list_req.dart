// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

import 'huya_user_id.dart';

/// commui.getUserSubscribeToInfoList 请求
/// tag0: tId 用户信息, tag1: iPageIndex 页码(0基)
class GetUserSubscribeToInfoListReq extends TarsStruct {
  HuyaUserId tId = HuyaUserId();
  int iPageIndex = 0;

  @override
  void readFrom(TarsInputStream _is) {
    tId = _is.read(tId, 0, false);
    iPageIndex = _is.read(iPageIndex, 1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(tId, 0);
    _os.write(iPageIndex, 1);
  }

  @override
  Object deepCopy() {
    return GetUserSubscribeToInfoListReq()
      ..tId = tId.deepCopy() as HuyaUserId
      ..iPageIndex = iPageIndex;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}
