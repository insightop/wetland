import 'package:flutter/material.dart';

import 'package:wetland/wetland.dart';
import 'package:wetland_example/pages/detail_page.dart';

import 'pages/placeholder_page.dart';
import 'pages/list_page.dart';

void main() {
  runApp(WetlandExample());
}

class WetlandExample extends StatelessWidget {
  WetlandExample({super.key});
  final destinations = [
    TabDestination(
      'Message',
      const Icon(Icons.chat_bubble_outline_rounded),
      const Icon(Icons.chat_bubble_rounded),
      const ListPage(title: 'Message'),
    ),
    TabDestination(
      'Contact',
      const Icon(Icons.group_outlined),
      const Icon(Icons.group_rounded),
      const ListPage(title: 'Contact'),
    ),
    TabDestination(
      'Discover',
      const Icon(Icons.explore_outlined),
      const Icon(Icons.explore),
      const ListPage(title: 'Discover'),
    ),
    TabDestination(
      'Profile',
      const Icon(Icons.person_outlined),
      const Icon(Icons.person),
      const DetailPage(title: 'Profile'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wetland Example',
      home: Wetland(
        destinations: destinations,
        placeholderPage: PlaceholderPage(),
      ),
    );
  }
}
