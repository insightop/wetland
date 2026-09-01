import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:wetland/wetland.dart';
import '../router/router.gr.dart';

@RoutePage()
class ContactsPage extends StatelessWidget {
  final String title;
  const ContactsPage({
    @PathParam() this.title = 'Contacts',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ListView.builder(
          itemBuilder: (context, index) {
            return
                // Card(
                // child:
                ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.accents[index % Colors.accents.length],
              ),
              trailing: Icon(Icons.arrow_forward_ios),
              title: Skeletonizer(
                effect: SolidColorEffect(),
                child: Text('$title $index'),
              ),
              subtitle: Skeletonizer(
                effect: SolidColorEffect(),
                child: Text('click to show detail'),
              ),
              onTap: () => context.wetland.push(DetailRoute(title: title)),
              // ),
            );
          },
        ),
      ),
    );
  }
}
