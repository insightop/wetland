import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wetland_event.dart';
part 'wetland_state.dart';

part 'wetland_bloc.freezed.dart';

class WetlandBloc extends Bloc<WetlandEvent, WetlandState> {
  WetlandBloc() : super(const WetlandState.pageState()) {
    on<WetlandEvent>((event, emit) => _handleEvent(event, emit));
  }

  void _handleEvent(WetlandEvent event, Emitter<WetlandState> emit) {
    event.when(
      changeDestination: (index) =>
          emit(WetlandState.pageState(selectedDestination: index)),
    );
  }
}


// class RootController extends GetxController {
//   // 次要页面
//   static final secondaryBodyKey = Get.nestedKey(1);
//   static var _secondaryBodyCurrentRoute = '';
//   static updateSecondaryBodyCurrentRoute(String route) {
//     _secondaryBodyCurrentRoute = route;
//   }

//   // 次级页面是否激活
//   static get isSecondaryBodyActive =>
//       secondaryBodyKey?.currentState?.mounted != null;
//   // 基础页面的路由必须通过此方法跳转，其他页面可以使用flutter或者get自带的即可
//   static Future<dynamic> primaryToNamed(String routeName,
//       {dynamic arguments, Map<String, String>? parameters}) async {
//     debugPrint('primaryToNamed: $routeName, $arguments, $parameters');
//     return await isSecondaryBodyActive
//         ? Get.offAllNamed(routeName,
//             id: 1, arguments: arguments, parameters: parameters)
//         : Get.toNamed(routeName,
//             id: 0, arguments: arguments, parameters: parameters);
//   }

//   /// 检查次级页面是否为默认页面，如果不是则跳转到默认页面
//   static secondaryToPreset() {
//     if (isSecondaryBodyActive &&
//         _secondaryBodyCurrentRoute != RouteNames.preset &&
//         _secondaryBodyCurrentRoute != '/') {
//       Get.offNamed(RouteNames.preset, id: 1);
//       // Get.until((route) => route.isFirst);
//     }
//   }
// }
// // 已解决
// // 竖屏模式下，进入次级页面后不显示bottombar，通过导航到最外层navigator的方式实现

// // TODO： 目前只剩下一个问题：
// //  当单导航切换到双导航时，如果primarybody的页面栈不止一个页面，那么应该把primarybody的页面栈的页面全部移动到secondarybody的页面栈中
// // 当双导航切换到单导航时，如果secondarybody的页面栈不止一个页面，那么应该把secondarybody的页面栈的页面全部移动到primarybody的页面栈中
// // 但是需要解决的是，导航切换的时候如何获得通知
