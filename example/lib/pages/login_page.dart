import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

import '../router/router.dart';

@RoutePage()
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: ListView(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 100,
            height: 100,
          ),
          const TextField(
            decoration: InputDecoration(labelText: 'Email'),
          ),
          const TextField(
            decoration: InputDecoration(labelText: 'Password'),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('Login success');
              context.router.replaceAll([
                const HomeRoute(),
              ]);
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}
