import 'package:flutter/material.dart';

class TabDestination {
  final String label;
  final Widget icon;
  final Widget? selectedIcon;
  final Widget page;

  TabDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
    required this.page,
  });
}
