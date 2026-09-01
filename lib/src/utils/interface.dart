import 'package:flutter/material.dart';
import 'package:wetland/src/utils/destination.dart';

abstract class IWetlandTabPage {
  TabDestination getDestination(BuildContext context);
}
