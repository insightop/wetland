import "package:get_it/get_it.dart";

import "../blocs/wetland_cubit.dart";

final sl = GetIt.instance;

void initInjection() {
  sl.registerLazySingleton(() => WetlandCubit());
}
