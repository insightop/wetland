import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

import 'entity_list_page.dart';

@RoutePage()
class ListPage extends StatelessWidget {
  final String title;
  const ListPage({
    @PathParam() this.title = 'List',
    super.key,
  });

  @override
  Widget build(BuildContext context) => EntityListPage(title: title);
}
