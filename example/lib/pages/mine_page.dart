import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

import '../router/router.dart';

@RoutePage()
class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mine'),
      ),
      body: Center(
        child: Column(
          children: [
            CircleAvatar(
              child: Image.asset('assets/images/logo.png'),
            ),
            ListTile(
              leading: CircleAvatar(
                child: Image.asset('assets/images/logo.png'),
              ),
              title: Text('User Name'),
              subtitle: Text('User Email'),
            ),
            const ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),
            const ListTile(
              leading: Icon(Icons.account_box),
              title: Text('Account'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),
            ElevatedButton(
              onPressed: () {
                debugPrint('Logout, go to login page');
                context.router.replaceAll([const LoginRoute()]);
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
