import 'package:flutter/material.dart';
import 'package:wetland/src/utils/destination.dart';

/// 页面实现此接口以声明它对应的主 tab 配置。
///
/// 让页面自身决定它作为主 tab 时的 [TabDestination]（标签、图标、内容页），
/// 便于在 [Wetland] 中按需组装 destinations。
abstract class IWetlandTabPage {
  /// 返回该页面作为主 tab 时的 [TabDestination]。
  TabDestination getDestination(BuildContext context);
}
