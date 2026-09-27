import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

import 'entity_list_page.dart';

@RoutePage()
class ContactsPage extends StatelessWidget {
  final String title;
  const ContactsPage({
    @PathParam() this.title = 'Contacts',
    super.key,
  });

  @override
  Widget build(BuildContext context) => EntityListPage(title: title);
}
