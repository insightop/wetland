import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

import 'list_page.dart';
import 'messages_page.dart';
import 'contacts_page.dart';
import 'mine_page.dart';
import 'package:wetland/wetland.dart';

@RoutePage()
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  final destinations = [
    TabDestination(
      label: 'Message',
      icon: const Icon(Icons.chat_bubble_outline_rounded),
      selectedIcon: const Icon(Icons.chat_bubble_rounded),
      page: const MessagesPage(title: 'Messages'),
    ),
    TabDestination(
      label: 'Contact',
      icon: const Icon(Icons.group_outlined),
      selectedIcon: const Icon(Icons.group_rounded),
      page: const ContactsPage(title: 'Contacts'),
    ),
    TabDestination(
      label: 'Discover',
      icon: const Icon(Icons.explore_outlined),
      selectedIcon: const Icon(Icons.explore),
      page: const ListPage(title: 'Discover'),
    ),
    TabDestination(
      label: 'Mine',
      icon: const Icon(Icons.person_outlined),
      selectedIcon: const Icon(Icons.person),
      page: const MinePage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Wetland(
      destinations: destinations,
      secondaryPlaceholder: (context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined, size: 48),
              SizedBox(height: 12),
              Text(
                'Select an item to see details',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
