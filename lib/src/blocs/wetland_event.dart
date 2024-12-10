part of 'wetland_bloc.dart';

@freezed
class WetlandEvent with _$WetlandEvent {
  const factory WetlandEvent.changeDestination(int index) =
      _WetlandEventChangeDestination;
}
