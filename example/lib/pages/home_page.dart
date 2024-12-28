import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

import '../router/router.dart';
import 'list_page.dart';
import 'messages_page.dart';
import 'contacts_page.dart';
import 'detail_page.dart';
import 'login_page.dart';
import 'mine_page.dart';
import 'placeholder_page.dart';
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
      'Message',
      const Icon(Icons.chat_bubble_outline_rounded),
      const Icon(Icons.chat_bubble_rounded),
      const MessagesPage(title: 'Messages'),
    ),
    TabDestination(
      'Contact',
      const Icon(Icons.group_outlined),
      const Icon(Icons.group_rounded),
      const ContactsPage(title: 'Contacts'),
    ),
    TabDestination(
      'Discover',
      const Icon(Icons.explore_outlined),
      const Icon(Icons.explore),
      const ListPage(title: 'Discover'),
    ),
    TabDestination(
      'Mine',
      const Icon(Icons.person_outlined),
      const Icon(Icons.person),
      const MinePage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Wetland(
      destinations: destinations,
    );
  }
}
