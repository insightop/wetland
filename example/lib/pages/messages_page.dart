import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

import 'entity_list_page.dart';

@RoutePage()
class MessagesPage extends StatelessWidget {
  final String title;
  const MessagesPage({
    @PathParam() this.title = 'Messages',
    super.key,
  });

  @override
  Widget build(BuildContext context) => EntityListPage(title: title);
}
