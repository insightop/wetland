part of 'wetland_bloc.dart';

@freezed
sealed class WetlandEvent with _$WetlandEvent {
  const factory WetlandEvent.setIndex(int index) = _WetlandEventSetIndex;
  const factory WetlandEvent.setMode(WetlandMode mode) = _WetlandEventSetMode;
}
