import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

import "pages/default_placeholder_page.dart";

import "blocs/wetland_cubit.dart";

import "utils/destination.dart";
import "utils/injection.dart";

import "widgets/bottom_navigation.dart";
import "widgets/primary_navigation.dart";
import "widgets/wetland_body.dart";

class Wetland extends StatelessWidget {
  final List<TabDestination> destinations;
  final Widget placeholderPage;
  const Wetland({
    super.key,
    required this.destinations,
    this.placeholderPage = const DefaultPlaceholderPage(),
  });

  // static init() => initInjection();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WetlandCubit>(
      create: (context) => WetlandCubit(),
      child: WetlandBody(
        destinations: destinations,
        primaryNavigationRailBuilder: WetlandPrimaryNavigation(
          destinations: destinations,
        ),
        bottomNavigationBarBuilder: WetlandBottomNavigation(
          destinations: destinations,
        ),
        placeholderPage: placeholderPage,
      ),
    );
  }
}
