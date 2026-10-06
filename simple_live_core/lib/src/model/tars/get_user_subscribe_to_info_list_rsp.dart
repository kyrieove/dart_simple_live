// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

import 'user_subscribe_to_info.dart';

/// commui.getUserSubscribeToInfoList 响应
/// tag0: sMessage, tag1: vItems, tag2: iTotal, tag3: iPageSize, tag4: iPageIndex
class GetUserSubscribeToInfoListRsp extends TarsStruct {
  String sMessage = "";
  List<UserSubscribeToInfo> vItems = <UserSubscribeToInfo>[];
  int iTotal = 0;
  int iPageSize = 0;
  int iPageIndex = 0;

  @override
  void readFrom(TarsInputStream _is) {
    sMessage = _is.read(sMessage, 0, false);
    vItems = _is.read(<UserSubscribeToInfo>[UserSubscribeToInfo()], 1, false);
    iTotal = _is.read(iTotal, 2, false);
    iPageSize = _is.read(iPageSize, 3, false);
    iPageIndex = _is.read(iPageIndex, 4, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(sMessage, 0);
    _os.write(vItems, 1);
    _os.write(iTotal, 2);
    _os.write(iPageSize, 3);
    _os.write(iPageIndex, 4);
  }

  @override
  Object deepCopy() {
    return GetUserSubscribeToInfoListRsp()
      ..sMessage = sMessage
      ..vItems = vItems
      ..iTotal = iTotal
      ..iPageSize = iPageSize
      ..iPageIndex = iPageIndex;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}
