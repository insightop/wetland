import 'package:material_ui/material_ui.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset('assets/images/logo.png', width: 200, height: 200),
      ),
    );
  }
}
