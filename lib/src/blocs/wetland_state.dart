part of 'wetland_bloc.dart';

@freezed
sealed class WetlandState with _$WetlandState {
  const factory WetlandState.pageState({
    @Default(0) int index, // 当前选中的标签
    @Default(WetlandMode.dual) WetlandMode mode, // 当前模式
  }) = _WetlandStatePageState;
}
