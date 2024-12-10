part of 'wetland_bloc.dart';

@freezed
class WetlandState with _$WetlandState {
  const factory WetlandState.pageState({
    @Default(0) int selectedDestination, // 当前选中的标签
    @Default(false) bool isSecondaryActive, //  次级页面是否活跃
  }) = _WetlandStatePageState;
}
