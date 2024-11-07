import 'package:flutter/material.dart';

class TabDestination {
  final String label;
  final Icon icon;
  final Icon selectedIcon;
  final Widget page;

  TabDestination(this.label, this.icon, this.selectedIcon, this.page);
}
